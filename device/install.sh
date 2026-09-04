#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

if [ ! -d "$LINKSS_ROOT" ] || [ ! -f "$LINKSS_ROOT/auto" ]; then
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

[ -f "$CONFIG_FILE" ] || printf 'mode=daily\n' > "$CONFIG_FILE"
set +e
"$SCRIPT_DIR/import.sh"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    if [ "$rc" -eq 2 ]; then
        # Existing prepared photos remain usable even if the inbox is empty.
        "$SCRIPT_DIR/pick.sh" >/dev/null 2>&1 || {
            echo "No photos available; existing screensavers were left unchanged." >&2
            exit 2
        }
    else
        exit "$rc"
    fi
fi

# pick.sh has atomically installed bg_ss00.png. Remove other files only now,
# after proving that a managed replacement exists.
for image in "$LINKSS_DIR"/*; do
    [ -f "$image" ] || continue
    [ "$image" = "$ACTIVE_IMAGE" ] || rm -f "$image"
done

touch "$LINKSS_ROOT/auto"
"$SCRIPT_DIR/enable-autostart.sh"
log "installation complete"
echo "Photo Frame installed. Add photos to $INBOX_DIR"
