#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

mode=$(read_mode)
current="none"
[ -f "$STATE_DIR/current" ] && current=$(cat "$STATE_DIR/current")
prepared=0
for item in "$PREPARED_DIR"/*.png; do
    [ -f "$item" ] && prepared=$((prepared + 1))
done

printf 'Kindle Photo Frame\nMode: %s\nPrepared photos: %s\nCurrent: %s\n' \
    "$mode" "$prepared" "$current"

