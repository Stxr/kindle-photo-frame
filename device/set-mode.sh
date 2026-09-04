#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

case "${1:-}" in
    hourly|daily) mode="$1" ;;
    *) echo "Usage: $0 hourly|daily" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$CONFIG_FILE")"
tmp="${CONFIG_FILE}.tmp.$$"
printf 'mode=%s\n' "$mode" > "$tmp"
mv -f "$tmp" "$CONFIG_FILE"
log "mode changed to $mode"

set +e
"$SCRIPT_DIR/pick.sh"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 2 ] || exit "$rc"
fi
printf 'Mode: %s\n' "$mode"
