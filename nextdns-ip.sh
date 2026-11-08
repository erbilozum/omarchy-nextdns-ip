#!/usr/bin/env bash
# Usage: nextdns-ip.sh tick|check|force|ip|seturl <url>|clearurl|setinterval <hours>|status
# Prints one line of JSON.
set -u

STATE_VER=2      # bump when the state format changes (forces a re-verify)
MIN_GAP=600      # min seconds between update attempts (debounce / retry backoff)
RESUME_GAP=180   # a gap this long between ticks means suspend/resume
IP_CHECK=900     # seconds between external IP checks (0 = never check on its own)

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/nextdns-ip"
CONF="$CFG/url"
IVF="$CFG/interval"
DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nextdns-ip"
STATE="$DIR/state.json"
RESULT=""
DETAIL=""
PROBE_CODE=000
PROBE_BODY=""
mkdir -p "$DIR"

now=$(date +%s)
boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)

# Refresh interval in hours (1-24, default 6)
read_hours() {
  local h=6
  [[ -s $IVF ]] && h=$(tr -d '[:space:]' < "$IVF")
  [[ $h =~ ^[0-9]+$ ]] && (( h >= 1 && h <= 24 )) || h=6
  echo "$h"
}
INTERVAL=$(( $(read_hours) * 3600 ))

# Load persisted state
ts=0 ok_ts=0 status=none s_boot="" last_tick=0 online=0 pending=0
ext_ip="" linked_ip="" ip_ts=0 notified=0 ver=0 err=""
if [[ -f $STATE ]]; then
  eval "$(jq -r '@sh "ts=\(.ts // 0) ok_ts=\(.ok_ts // 0) status=\(.status // "none") s_boot=\(.boot_id // "") last_tick=\(.last_tick // 0) online=\(.online // 0) pending=\(.pending // 0) ext_ip=\(.ext_ip // "") linked_ip=\(.linked_ip // "") ip_ts=\(.ip_ts // 0) notified=\(.notified // 0) ver=\(.ver // 0) err=\(.err // "")"' "$STATE" 2>/dev/null)"
fi

# State written by an older version: forget its "ok" and verify again
if (( ver != STATE_VER )); then
  pending=1; ts=0; ok_ts=0; status=none; err=""
fi

# Print the saved state plus config info and the result of the last action
emit() {
  local base='{"ts":0,"ok_ts":0,"status":"none","online":0}' conf=0 hint=""
  [[ -f $STATE ]] && base=$(cat "$STATE")
  if [[ -s $CONF ]]; then
    conf=1
    hint=$(tr -d '[:space:]' < "$CONF" | awk -F/ '{print $4 "/…" substr($5, (length($5) > 4 ? length($5) - 3 : 1))}')
  fi
  jq -c --argjson c "$conf" --arg r "${RESULT:-}" --arg d "${DETAIL:-}" \
    --argjson h "$(read_hours)" --arg u "$hint" \
    '. + {configured:$c, result:$r, detail:$d, interval_h:$h, url_hint:$u}' <<< "$base"
}

# "Online" = a default route exists. A failed request is handled by retry.
check_online() { if ip route show default 2>/dev/null | grep -q .; then online=1; else online=0; fi; }

# Refresh connectivity and flag events that mean the public IP may have changed
observe() {
  local was_online=$online
  check_online
  [[ $s_boot != "$boot_id" ]] && pending=1                          # new boot
  (( last_tick > 0 && now - last_tick > RESUME_GAP )) && pending=1  # resumed from suspend
  (( was_online == 0 && online == 1 )) && pending=1                 # connection (re)established
}

save() {
  jq -nc --argjson ts "$ts" --argjson ok "$ok_ts" --arg s "$status" --arg b "$boot_id" \
    --argjson lt "$now" --argjson on "$online" --argjson p "$pending" \
    --arg ip "$ext_ip" --arg lip "$linked_ip" --argjson ipt "$ip_ts" --argjson nf "$notified" \
    --argjson v "$STATE_VER" --arg e "$err" \
    '{ts:$ts, ok_ts:$ok, status:$s, boot_id:$b, last_tick:$lt, online:$on, pending:$p,
      ext_ip:$ip, linked_ip:$lip, ip_ts:$ipt, notified:$nf, ver:$v, err:$e}' \
    > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

is_ip() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ $1 == *:* && $1 =~ ^[0-9a-fA-F:]+$ ]]
}

# Look up our public IP (tries a few plain-text services)
fetch_ip() {
  local u ip
  for u in https://api.ipify.org https://icanhazip.com https://ifconfig.me/ip; do
    ip=$(curl -fsS --max-time 5 "$u" 2>/dev/null | tr -d '[:space:]')
    if is_ip "$ip"; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

# Compare the current public IP with the one we last told NextDNS about
check_ip_change() {
  local ip
  ip_ts=$now
  if ip=$(fetch_ip); then
    ext_ip=$ip
    [[ -n $linked_ip && $linked_ip != "$ip" ]] && pending=1
  fi
}

# Call a linked-IP URL. Sets PROBE_CODE (000 = no response) and PROBE_BODY.
probe() {
  local out
  PROBE_CODE=000
  PROBE_BODY=""
  out=$(curl -sS --max-time 15 -H 'Accept: text/html' -w $'\n%{http_code}' "$1" 2>/dev/null) || return 0
  PROBE_CODE=${out##*$'\n'}
  PROBE_BODY=$(printf '%s' "${out%$'\n'*}" | tr -d '[:space:]')
}

# A real linked-IP URL answers 2xx and returns our IP address as the body
probe_ok() { [[ $PROBE_CODE == 2?? ]] && is_ip "$PROBE_BODY"; }

# After a successful call: remember the IP we just registered
remember_ip() {
  local ip
  if ip=$(fetch_ip); then
    ext_ip=$ip; linked_ip=$ip
  else
    ext_ip=$PROBE_BODY; linked_ip=""
  fi
  ip_ts=$now
}

update() {
  local url
  ts=$now
  if [[ ! -s $CONF ]]; then
    status=nourl; err=""
    return
  fi
  url=$(tr -d '[:space:]' < "$CONF")
  probe "$url"
  if probe_ok; then
    status=ok; err=""; ok_ts=$now; pending=0
    remember_ip
  else
    status=error
    if [[ $PROBE_CODE == 000 ]]; then err="no response"
    elif [[ $PROBE_CODE == 2?? ]]; then err="unexpected reply"
    else err="HTTP $PROBE_CODE"; fi
  fi
}

# Prevent concurrent runs (multi-monitor / multiple bar instances)
exec 9>"$DIR/lock"
flock -n 9 || { emit; exit 0; }

case "${1:-status}" in
  check)
    observe
    save
    ;;
  ip)
    observe
    if (( online == 1 && now - ip_ts >= 30 )); then check_ip_change; fi
    save
    ;;
  force)
    observe
    (( online == 1 )) && update
    save
    ;;
  tick)
    observe
    # One-time desktop notification asking for the URL
    if [[ ! -s $CONF && $notified != 1 ]]; then
      command -v notify-send > /dev/null && notify-send -a "NextDNS IP" "NextDNS IP: setup needed" \
        "Click the shield icon in the bar and enter your Linked IP URL (my.nextdns.io > Setup > Linked IP)."
      notified=1
    fi
    if (( online == 1 )); then
      if [[ -s $CONF ]] && (( IP_CHECK > 0 && now - ip_ts >= IP_CHECK )); then check_ip_change; fi
      if (( pending == 1 || ok_ts == 0 || now - ok_ts >= INTERVAL )) && (( now - ts >= MIN_GAP )); then
        update
      fi
    fi
    save
    ;;
  seturl)
    new=$(printf '%s' "${2:-}" | tr -d '[:space:]')
    if [[ ! $new =~ ^https://link-ip\.nextdns\.io/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$ ]]; then
      RESULT=invalid
    else
      observe
      if (( online == 0 )); then
        RESULT=offline
      else
        probe "$new"
        if probe_ok; then
          mkdir -p "$CFG"
          ( umask 077; printf '%s\n' "$new" > "$CONF" )
          chmod 600 "$CONF"
          RESULT=saved
          status=ok; err=""; ok_ts=$now; ts=$now; pending=0
          remember_ip
        elif [[ $PROBE_CODE == 000 ]]; then
          RESULT=unreachable
        else
          RESULT=rejected
          DETAIL="HTTP $PROBE_CODE"
          [[ $PROBE_CODE == 2?? ]] && DETAIL="HTTP $PROBE_CODE, unexpected reply: ${PROBE_BODY:0:40}"
        fi
      fi
      save
    fi
    ;;
  clearurl)
    rm -f "$CONF"
    status=nourl; err=""; ok_ts=0; linked_ip=""; pending=0; notified=1
    RESULT=cleared
    save
    ;;
  setinterval)
    h="${2:-}"
    if [[ $h =~ ^[0-9]+$ ]] && (( h >= 1 && h <= 24 )); then
      mkdir -p "$CFG"
      printf '%s\n' "$h" > "$IVF"
      RESULT=interval_saved
    else
      RESULT=interval_invalid
    fi
    ;;
esac
emit