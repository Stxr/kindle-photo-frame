#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

ensure_dirs
CONVERT_BIN="${PHOTO_FRAME_CONVERT:-/mnt/us/linkss/bin/convert}"
if [ ! -x "$CONVERT_BIN" ]; then
    echo "ImageMagick convert not found: $CONVERT_BIN" >&2
    exit 4
fi

found=0
for source in "$INBOX_DIR"/*; do
    [ -f "$source" ] || continue
    case "$source" in
        *.jpg|*.JPG|*.jpeg|*.JPEG|*.png|*.PNG) ;;
        *) continue ;;
    esac
    found=1
    stem=$(basename "$source")
    stem=${stem%.*}
    safe=$(printf '%s' "$stem" | tr -c 'A-Za-z0-9._-' '_')
    digest=$(cksum "$source" | awk '{print $1}')
    target="$PREPARED_DIR/${safe}-${digest}.png"
    tmp="${target}.tmp.$$"
    if [ ! -f "$target" ]; then
        "$CONVERT_BIN" "$source" -auto-orient -colorspace Gray \
            -resize '1072x1448^' -gravity center -extent 1072x1448 \
            -colors 256 -strip "PNG8:$tmp"
        mv -f "$tmp" "$target"
        chmod 0664 "$target"
        log "prepared $(basename "$source") -> $(basename "$target")"
    fi
done

if [ "$found" -eq 0 ]; then
    log "import skipped: inbox empty"
    echo "No JPEG or PNG files in $INBOX_DIR"
    exit 2
fi

"$SCRIPT_DIR/pick.sh"

