#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

ensure_dirs
mode=$(read_mode)

set -- "$PREPARED_DIR"/*.png
if [ ! -f "$1" ]; then
    log "pick skipped: no prepared photos"
    echo "No prepared photos. Import photos first."
    exit 2
fi

count=$#
epoch="${PHOTO_FRAME_EPOCH:-$(date +%s)}"
case "$mode" in
    hourly) slot=$((epoch / 3600)) ;;
    daily) slot=$((epoch / 86400)) ;;
    *) echo "Invalid mode: $mode" >&2; exit 3 ;;
esac
index=$((slot % count + 1))

selected=""
i=1
for candidate in "$@"; do
    if [ "$i" -eq "$index" ]; then
        selected="$candidate"
        break
    fi
    i=$((i + 1))
done

tmp="${ACTIVE_IMAGE}.photo-frame.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
cp "$selected" "$tmp"
chmod 0664 "$tmp"
mv -f "$tmp" "$ACTIVE_IMAGE"
trap - EXIT HUP INT TERM

basename "$selected" > "$STATE_DIR/current"
printf '%s\n' "$slot" > "$STATE_DIR/slot"
log "selected mode=$mode slot=$slot image=$(basename "$selected")"
printf '%s\n' "$selected"

