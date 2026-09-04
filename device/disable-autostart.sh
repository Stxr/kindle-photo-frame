#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

LINKSS_SCRIPT="${PHOTO_FRAME_LINKSS_SCRIPT:-/mnt/us/linkss/bin/linkss}"
if [ -f "$LINKSS_SCRIPT" ] && grep -qF '# PHOTO_FRAME_AUTOSTART_BEGIN' "$LINKSS_SCRIPT"; then
    tmp="${LINKSS_SCRIPT}.tmp.$$"
    sed '/# PHOTO_FRAME_AUTOSTART_BEGIN/,/# PHOTO_FRAME_AUTOSTART_END/d' \
        "$LINKSS_SCRIPT" > "$tmp"
    chmod --reference="$LINKSS_SCRIPT" "$tmp" 2>/dev/null || chmod 0755 "$tmp"
    mv -f "$tmp" "$LINKSS_SCRIPT"
fi

if [ -f "$STATE_DIR/watch.pid" ]; then
    pid=$(cat "$STATE_DIR/watch.pid" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    rm -f "$STATE_DIR/watch.pid"
fi

