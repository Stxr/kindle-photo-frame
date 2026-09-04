#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

interval="${1:-}"
case "$interval" in
    ''|*[!0-9]*) echo "Usage: $0 SECONDS (60..86400)" >&2; exit 2 ;;
esac
if [ "$interval" -lt 60 ] || [ "$interval" -gt 86400 ]; then
    echo "RTC interval must be between 60 and 86400 seconds" >&2
    exit 2
fi

mkdir -p "$(dirname "$CONFIG_FILE")"
tmp="${CONFIG_FILE}.tmp.$$"
printf 'mode=rtc\ninterval=%s\n' "$interval" > "$tmp"
mv -f "$tmp" "$CONFIG_FILE"
lipc-set-prop -i com.lab126.powerd suspendGrace 0 >/dev/null 2>&1 || true
log "mode changed to rtc interval=$interval"
"$SCRIPT_DIR/pick.sh" || true
printf 'Mode: rtc\nInterval: %s seconds\n' "$interval"
