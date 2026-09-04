#!/bin/sh
set -eu

LINKSS_SCRIPT="${PHOTO_FRAME_LINKSS_SCRIPT:-/mnt/us/linkss/bin/linkss}"
BEGIN='# PHOTO_FRAME_AUTOSTART_BEGIN'

if [ ! -f "$LINKSS_SCRIPT" ]; then
    echo "linkss startup script not found: $LINKSS_SCRIPT" >&2
    exit 5
fi

if ! grep -qF "$BEGIN" "$LINKSS_SCRIPT"; then
    cp -p "$LINKSS_SCRIPT" "${LINKSS_SCRIPT}.photo-frame-original"
    {
        printf '\n%s\n' "$BEGIN"
        printf '[ -x /mnt/us/photo-frame/bin/watch.sh ] && /mnt/us/photo-frame/bin/watch.sh &\n'
        printf '%s\n' '# PHOTO_FRAME_AUTOSTART_END'
    } >> "$LINKSS_SCRIPT"
fi

/mnt/us/photo-frame/bin/watch.sh >/dev/null 2>&1 &

