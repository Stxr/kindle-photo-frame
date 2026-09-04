#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

ensure_dirs
set -- "$PREPARED_DIR"/*.png
if [ ! -f "$1" ]; then
    log "advance skipped: no prepared photos"
    echo "No prepared photos. Import photos first."
    exit 2
fi

current=""
[ -f "$STATE_DIR/current" ] && current=$(cat "$STATE_DIR/current")
selected="$1"
found=0
for candidate in "$@"; do
    if [ "$found" -eq 1 ]; then
        selected="$candidate"
        break
    fi
    if [ "$(basename "$candidate")" = "$current" ]; then
        found=1
    fi
done

# When current was the final item, selected intentionally remains the first.
sequence=0
[ -f "$STATE_DIR/sequence" ] && sequence=$(cat "$STATE_DIR/sequence")
case "$sequence" in ''|*[!0-9]*) sequence=0 ;; esac
sequence=$((sequence + 1))

tmp="${ACTIVE_IMAGE}.photo-frame.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
cp "$selected" "$tmp"
chmod 0664 "$tmp"
mv -f "$tmp" "$ACTIVE_IMAGE"
trap - EXIT HUP INT TERM

basename "$selected" > "$STATE_DIR/current"
printf '%s\n' "$sequence" > "$STATE_DIR/sequence"
printf 'rtc-sequence-%s\n' "$sequence" > "$STATE_DIR/slot"
printf '%s\n' "$(read_mode)" > "$STATE_DIR/mode"
log "advanced sequence=$sequence image=$(basename "$selected")"
printf '%s\n' "$selected"
