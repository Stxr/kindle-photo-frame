#!/bin/sh

APP_BIN=/mnt/us/photo-frame/bin
LOG=/mnt/us/photo-frame/kual.log
mkdir -p /mnt/us/photo-frame

case "${1:-}" in
    install) script=install.sh ;;
    import) script=import.sh ;;
    pick) script=pick.sh ;;
    minute) script=set-mode.sh; args=minute ;;
    hourly) script=set-mode.sh; args=hourly ;;
    daily) script=set-mode.sh; args=daily ;;
    status) script=status.sh ;;
    uninstall) script=uninstall.sh ;;
    *) exit 2 ;;
esac

{
    printf '\n=== %s %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
    "$APP_BIN/$script" ${args:-}
} >> "$LOG" 2>&1 &
