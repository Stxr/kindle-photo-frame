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
cleanup() {
    owner=""
    [ -f "$PID_FILE" ] && owner=$(cat "$PID_FILE" 2>/dev/null)
    [ "$owner" = "$$" ] && rm -f "$PID_FILE"
}
trap 'cleanup; exit 0' EXIT HUP INT TERM
log "watcher started pid=$$"

last_event=""
while :; do
    mode=$(read_mode)

    # rtcWakeup is only accepted during powerd's readyToSuspend window.
    case "$last_event" in
        *readyToSuspend*)
            if [ "$mode" = "rtc5" ] || [ "$mode" = "rtc" ]; then
                interval=$(read_interval)
                if [ "$mode" = "rtc5" ]; then interval=300; fi
                if lipc-set-prop -i com.lab126.powerd rtcWakeup "$interval" >/dev/null 2>&1; then
                    next_wakeup=$(($(date +%s) + interval))
                    printf '%s\n' "$next_wakeup" > "$STATE_DIR/next-wakeup"
                    log "scheduled RTC wake in $interval seconds epoch=$next_wakeup"
                else
                    log "failed to schedule RTC wake"
                fi
            fi
            ;;
    esac

    if [ "$mode" = "minute" ]; then
        # powerd accepts these delays in different phases: suspendGrace before
        # readyToSuspend, then deferSuspend once that transition has happened.
        # Reverting to hourly/daily or uninstalling restores normal suspend.
        power_state=$(lipc-get-prop com.lab126.powerd state 2>/dev/null || true)
        case "$power_state" in
            readyToSuspend)
                lipc-set-prop -i com.lab126.powerd deferSuspend 120 >/dev/null 2>&1 || true
                ;;
            active|screenSaver)
                lipc-set-prop -i com.lab126.powerd suspendGrace 120 >/dev/null 2>&1 || true
                ;;
        esac
    fi
    before_slot=""
    [ -f "$STATE_DIR/slot" ] && before_slot=$(cat "$STATE_DIR/slot")
    case "$last_event:$mode" in
        *wakeupFromSuspend*:rtc|*wakeupFromSuspend*:rtc5)
            # Advance from the actual current file instead of deriving the
            # image from wall-clock time. This guarantees A -> B -> C -> A
            # even when an RTC wake is delayed across more than one slot.
            "$SCRIPT_DIR/next.sh" >/dev/null 2>&1 || true
            ;;
        *:rtc|*:rtc5)
            # RTC modes advance only on a real resume event. Calling pick.sh
            # from the ordinary timeout path would re-apply wall-clock slot
            # selection and could overwrite the sequential choice.
            ;;
        *)
            "$SCRIPT_DIR/pick.sh" >/dev/null 2>&1 || true
            ;;
    esac
    after_slot=""
    [ -f "$STATE_DIR/slot" ] && after_slot=$(cat "$STATE_DIR/slot")

    # Minute mode is a visual test mode: linkss only reads a new file while
    # entering screensaver, so explicitly redraw if the selected minute changed
    # while the Kindle is still in its screenSaver state.
    if { [ "$mode" = "minute" ] || [ "$mode" = "rtc5" ] || [ "$mode" = "rtc" ]; } && \
        [ -n "$after_slot" ] && \
        [ "$after_slot" != "$before_slot" ]; then
        state=$(lipc-get-prop com.lab126.powerd state 2>/dev/null || true)
        case "$state" in
            screenSaver|readyToSuspend)
                if [ -f "$ACTIVE_IMAGE" ]; then
                    /usr/bin/fbink -q -c -i "$ACTIVE_IMAGE" -W GC16 -w >/dev/null 2>&1 || true
                    log "redrew locked screen mode=$mode slot=$after_slot state=$state"
                fi
                ;;
        esac
    fi
    # A timeout keeps the selected time slot current while the device is awake.
    # During deep sleep this process is frozen and consumes no CPU.
    last_event=$(lipc-wait-event -s 15 com.lab126.powerd \
        goingToScreenSaver,outOfScreenSaver,readyToSuspend,wakeupFromSuspend \
        2>/dev/null || true)
    [ -n "$last_event" ] && log "power event: $last_event"
done
