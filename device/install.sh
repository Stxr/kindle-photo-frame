#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

if [ ! -d /mnt/us/linkss ] || [ ! -f /mnt/us/linkss/auto ]; then
    echo "The enabled linkss screensaver hack is required." >&2
    exit 5
fi

ensure_dirs
if [ ! -f "$STATE_DIR/installed" ]; then
    mkdir -p "$BACKUP_DIR"
    for image in "$LINKSS_DIR"/*; do
        [ -f "$image" ] || continue
        cp -p "$image" "$BACKUP_DIR/"
    done
    date +%s > "$STATE_DIR/installed"
    log "backed up existing linkss screensavers"
fi

for image in "$LINKSS_DIR"/*; do
    [ -f "$image" ] || continue
    rm -f "$image"
done

[ -f "$CONFIG_FILE" ] || printf 'mode=daily\n' > "$CONFIG_FILE"
set +e
"$SCRIPT_DIR/import.sh"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 2 ] || exit "$rc"
fi

touch /mnt/us/linkss/auto
"$SCRIPT_DIR/enable-autostart.sh"
log "installation complete"
echo "Photo Frame installed. Add photos to $INBOX_DIR"
