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

interval="n/a"
next_wakeup="n/a"
case "$mode" in
    rtc) interval="$(read_interval) seconds" ;;
    rtc5) interval="300 seconds" ;;
esac
[ -f "$STATE_DIR/next-wakeup" ] && next_wakeup=$(cat "$STATE_DIR/next-wakeup")

printf 'Kindle Photo Frame\nMode: %s\nRTC interval: %s\nNext RTC epoch: %s\nPrepared photos: %s\nCurrent: %s\n' \
    "$mode" "$interval" "$next_wakeup" "$prepared" "$current"

