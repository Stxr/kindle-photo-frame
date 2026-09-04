#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

case "${1:-}" in
    minute|rtc5|hourly|daily) mode="$1" ;;
    *) echo "Usage: $0 minute|rtc5|hourly|daily" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$CONFIG_FILE")"
tmp="${CONFIG_FILE}.tmp.$$"
printf 'mode=%s\n' "$mode" > "$tmp"
mv -f "$tmp" "$CONFIG_FILE"
log "mode changed to $mode"

if command -v lipc-set-prop >/dev/null 2>&1; then
    if [ "$mode" = "minute" ]; then
        # Test mode keeps powerd in the lock-screen grace period so the watcher
        # can redraw. The watcher renews this while minute mode remains active.
        lipc-set-prop -i com.lab126.powerd suspendGrace 120 >/dev/null 2>&1 || true
    else
        lipc-set-prop -i com.lab126.powerd suspendGrace 0 >/dev/null 2>&1 || true
    fi
fi

set +e
"$SCRIPT_DIR/pick.sh"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 2 ] || exit "$rc"
fi
printf 'Mode: %s\n' "$mode"
