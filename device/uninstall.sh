#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

for image in "$LINKSS_DIR"/*; do
    [ -f "$image" ] || continue
    rm -f "$image"
done
if [ -d "$BACKUP_DIR" ]; then
    for image in "$BACKUP_DIR"/*; do
        [ -f "$image" ] || continue
        cp -p "$image" "$LINKSS_DIR/"
    done
fi
rm -f "$STATE_DIR/installed"
"$SCRIPT_DIR/disable-autostart.sh"
lipc-set-prop -i com.lab126.powerd suspendGrace 0 >/dev/null 2>&1 || true
log "restored screensaver backup"
echo "Original linkss screensavers restored. Photo library was kept."
