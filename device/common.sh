#!/bin/sh

APP_ROOT="${PHOTO_FRAME_ROOT:-/mnt/us/photo-frame}"
INBOX_DIR="${PHOTO_FRAME_INBOX:-${APP_ROOT}/inbox}"
PREPARED_DIR="${PHOTO_FRAME_PREPARED:-${APP_ROOT}/prepared}"
STATE_DIR="${PHOTO_FRAME_STATE:-${APP_ROOT}/state}"
CONFIG_FILE="${PHOTO_FRAME_CONFIG:-${APP_ROOT}/config}"
LINKSS_ROOT="${PHOTO_FRAME_LINKSS_ROOT:-/mnt/us/linkss}"
LINKSS_DIR="${PHOTO_FRAME_LINKSS:-${LINKSS_ROOT}/screensavers}"
ACTIVE_IMAGE="${PHOTO_FRAME_ACTIVE:-${LINKSS_DIR}/bg_ss00.png}"
LOG_FILE="${PHOTO_FRAME_LOG:-${APP_ROOT}/photo-frame.log}"
BACKUP_DIR="${PHOTO_FRAME_BACKUP:-${APP_ROOT}/backup/screensavers}"

log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

read_mode() {
    mode="daily"
    if [ -f "$CONFIG_FILE" ]; then
        configured=$(sed -n 's/^mode=//p' "$CONFIG_FILE" | head -n 1)
        case "$configured" in
        minute|rtc|rtc5|hourly|daily) mode="$configured" ;;
        esac
    fi
    printf '%s\n' "$mode"
}

read_interval() {
    interval="300"
    if [ -f "$CONFIG_FILE" ]; then
        configured=$(sed -n 's/^interval=//p' "$CONFIG_FILE" | head -n 1)
        case "$configured" in
            ''|*[!0-9]*) ;;
            *) [ "$configured" -ge 60 ] 2>/dev/null && interval="$configured" ;;
        esac
    fi
    printf '%s\n' "$interval"
}

ensure_dirs() {
    mkdir -p "$INBOX_DIR" "$PREPARED_DIR" "$STATE_DIR" "$LINKSS_DIR"
    chmod 0777 "$APP_ROOT" "$INBOX_DIR" "$PREPARED_DIR" "$STATE_DIR" 2>/dev/null || true
}
