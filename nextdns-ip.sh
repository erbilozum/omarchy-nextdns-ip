#!/usr/bin/env bash
# Usage: nextdns-ip.sh tick|check|force|status  -> prints one line of JSON
set -u

INTERVAL=21600   # max seconds between successful updates (6h = 4x/day)
MIN_GAP=600      # min seconds between attempts (debounce / retry backoff)
RESUME_GAP=180   # a gap this long between ticks means suspend/resume

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nextdns-ip/url"
DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nextdns-ip"
STATE="$DIR/state.json"
mkdir -p "$DIR"

now=$(date +%s)
boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)

# Load persisted state
ts=0 ok_ts=0 status=none s_boot="" last_tick=0 online=0 pending=0
if [[ -f $STATE ]]; then
  eval "$(jq -r '@sh "ts=\(.ts // 0) ok_ts=\(.ok_ts // 0) status=\(.status // "none") s_boot=\(.boot_id // "") last_tick=\(.last_tick // 0) online=\(.online // 0) pending=\(.pending // 0)"' "$STATE" 2>/dev/null)"
fi

emit() { [[ -f $STATE ]] && cat "$STATE" || echo '{"ts":0,"ok_ts":0,"status":"none","online":0}'; }

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
    '{ts:$ts, ok_ts:$ok, status:$s, boot_id:$b, last_tick:$lt, online:$on, pending:$p}' \
    > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

update() {
  local url
  ts=$now
  if [[ ! -s $CONF ]]; then
    status=nourl
  else
    url=$(tr -d '[:space:]' < "$CONF")
    if curl -fsS --max-time 15 -o /dev/null "$url" 2>/dev/null; then
      status=ok; ok_ts=$now; pending=0
    else
      status=error
    fi
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
  force)
    observe
    (( online == 1 )) && update
    save
    ;;
  tick)
    observe
    if (( online == 1 )); then
      if (( pending == 1 || ok_ts == 0 || now - ok_ts >= INTERVAL )) && (( now - ts >= MIN_GAP )); then
        update
      fi
    fi
    save
    ;;
esac
emit