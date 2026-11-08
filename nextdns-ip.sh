#!/usr/bin/env bash
# Usage: nextdns-ip.sh tick|check|force|ip|seturl <url>|setinterval <hours>|status
# Prints one line of JSON.
set -u

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
ext_ip="" linked_ip="" ip_ts=0 notified=0
if [[ -f $STATE ]]; then
  eval "$(jq -r '@sh "ts=\(.ts // 0) ok_ts=\(.ok_ts // 0) status=\(.status // "none") s_boot=\(.boot_id // "") last_tick=\(.last_tick // 0) online=\(.online // 0) pending=\(.pending // 0) ext_ip=\(.ext_ip // "") linked_ip=\(.linked_ip // "") ip_ts=\(.ip_ts // 0) notified=\(.notified // 0)"' "$STATE" 2>/dev/null)"
fi

# Print the saved state plus config info and the result of the last action
emit() {
  local base='{"ts":0,"ok_ts":0,"status":"none","online":0}' conf=0
  [[ -f $STATE ]] && base=$(cat "$STATE")
  [[ -s $CONF ]] && conf=1
  jq -c --argjson c "$conf" --arg r "${RESULT:-}" --arg d "${DETAIL:-}" --argjson h "$(read_hours)" \
    '. + {configured:$c, result:$r, detail:$d, interval_h:$h}' <<< "$base"
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
    '{ts:$ts, ok_ts:$ok, status:$s, boot_id:$b, last_tick:$lt, online:$on, pending:$p,
      ext_ip:$ip, linked_ip:$lip, ip_ts:$ipt, notified:$nf}' \
    > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

# Look up our public IP (tries a few plain-text services)
fetch_ip() {
  local u ip
  for u in https://api.ipify.org https://icanhazip.com https://ifconfig.me/ip; do
    ip=$(curl -fsS --max-time 5 "$u" 2>/dev/null | tr -d '[:space:]')
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ $ip == *:* && $ip =~ ^[0-9a-fA-F:]+$ ]]; then
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

# Send one request to a linked-IP URL and print the HTTP status (000 = no response)
probe() {
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$1" 2>/dev/null) || code=000
  echo "$code"
}

update() {
  local url code ip
  ts=$now
  if [[ ! -s $CONF ]]; then
    status=nourl
    return
  fi
  url=$(tr -d '[:space:]' < "$CONF")
  code=$(probe "$url")
  if [[ $code == 2?? ]]; then
    status=ok; ok_ts=$now; pending=0
    if ip=$(fetch_ip); then ext_ip=$ip; linked_ip=$ip; ip_ts=$now; fi
  else
    status=error
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
        code=$(probe "$new")
        if [[ $code == 2?? ]]; then
          mkdir -p "$CFG"
          ( umask 077; printf '%s\n' "$new" > "$CONF" )
          chmod 600 "$CONF"
          RESULT=saved
          status=ok; ok_ts=$now; ts=$now; pending=0
          if ip=$(fetch_ip); then ext_ip=$ip; linked_ip=$ip; ip_ts=$now; fi
        elif [[ $code == 000 ]]; then
          RESULT=unreachable
        else
          RESULT=rejected
          DETAIL=$code
        fi
      fi
      save
    fi
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