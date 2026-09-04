#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

ensure_dirs
PID_FILE="$STATE_DIR/watch.pid"
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        exit 0
    fi
fi

echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"; exit 0' EXIT HUP INT TERM
log "watcher started pid=$$"

while :; do
    "$SCRIPT_DIR/pick.sh" >/dev/null 2>&1 || true
    # A timeout keeps the selected time slot current while the device is awake.
    # During deep sleep this process is frozen and consumes no CPU.
    lipc-wait-event -s 60 com.lab126.powerd \
        goingToScreenSaver,outOfScreenSaver >/dev/null 2>&1 || true
done

