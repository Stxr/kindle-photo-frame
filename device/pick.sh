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
    minute) slot=$((epoch / 60)) ;;
    rtc5) slot=$((epoch / 300)) ;;
    rtc) slot=$((epoch / $(read_interval))) ;;
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

previous_mode=""
previous_slot=""
previous_image=""
[ -f "$STATE_DIR/mode" ] && previous_mode=$(cat "$STATE_DIR/mode")
[ -f "$STATE_DIR/slot" ] && previous_slot=$(cat "$STATE_DIR/slot")
[ -f "$STATE_DIR/current" ] && previous_image=$(cat "$STATE_DIR/current")
if [ "$previous_mode" = "$mode" ] && [ "$previous_slot" = "$slot" ] && \
    [ "$previous_image" = "$(basename "$selected")" ] && [ -f "$ACTIVE_IMAGE" ]; then
    printf '%s\n' "$selected"
    exit 0
fi

tmp="${ACTIVE_IMAGE}.photo-frame.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
cp "$selected" "$tmp"
chmod 0664 "$tmp"
mv -f "$tmp" "$ACTIVE_IMAGE"
trap - EXIT HUP INT TERM

basename "$selected" > "$STATE_DIR/current"
printf '%s\n' "$slot" > "$STATE_DIR/slot"
printf '%s\n' "$mode" > "$STATE_DIR/mode"
log "selected mode=$mode slot=$slot image=$(basename "$selected")"
printf '%s\n' "$selected"
