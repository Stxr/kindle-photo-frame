# Kindle Photo Frame

[English](README.md) | [简体中文](README.zh-CN.md)

Turn a jailbroken Kindle into a low-power lock-screen photo frame. Photos are
prepared on the device, displayed through Kindle's native screensaver flow, and
rotated on wake, by time slot, or by an RTC alarm that can wake from suspend.

The project is intentionally small: POSIX shell runs on the Kindle, a
dependency-free Python CLI handles SSH/SFTP, and existing Kindle components
(`linkss`, powerd, and FBInk) do the platform-specific work.

> [!WARNING]
> This is an unofficial modification for devices you own. Jailbreaking and
> changing system behavior may void support, break after firmware updates, or
> require recovery. Keep backups and test on a non-critical device first.

## Why this project

- **Actually uses the lock screen.** No foreground reader app needs to remain
  open just to resemble a photo frame.
- **Power-aware rotation.** Normal modes preserve Kindle sleep; RTC mode wakes
  from suspend only when a refresh is due.
- **E Ink friendly.** Images match the panel and use PNG8 plus full GC16 refresh.
- **Batch workflow.** Upload files or directories; orientation, crop, grayscale,
  resizing, and metadata removal are automatic.
- **Remote delivery.** Add photos with SSH/SFTP instead of USB storage mode.
- **Recoverable.** Existing `linkss` screensavers are backed up and restored on
  uninstall without deleting the photo library.
- **Private by default.** Processing is local, and `photos/` is ignored by Git.

## Tested hardware

The reference device is a Kindle Paperwhite 3 with:

- 1072×1448, 300 DPI display;
- ARMv7 Kindle firmware 5.x;
- NiLuJe `linkss` 0.25.N;
- FBInk 1.24;
- Dropbear with SFTP v3.

Other Kindle 5.x devices may work if `linkss`, FBInk, LIPC power events, and the
powerd properties used here are available. They are not yet verified, and other
screen sizes require adjusting `device/import.sh`.

## How it works

```text
computer photos
      │  SSH/SFTP
      ▼
/mnt/us/photo-frame/inbox
      │  auto-orient → crop → grayscale → PNG8
      ▼
/mnt/us/photo-frame/prepared
      │  time-slot selection / sequential RTC rotation
      ▼
/mnt/us/linkss/screensavers/bg_ss00.png
      │
      ├─ native linkss lock screen
      └─ FBInk GC16 redraw after RTC wake

powerd: readyToSuspend → schedule rtcWakeup
        deep suspend   → no application CPU activity
        RTC wake       → select, redraw, schedule again
```

`linkss` reads the active image when Kindle enters its screensaver. The watcher
also listens for `readyToSuspend` and `wakeupFromSuspend`. In RTC mode it sets an
alarm only inside the short state window accepted by powerd. When the alarm
fires, the process resumes, advances exactly one photo (wrapping at the end),
redraws, and suspends again.

## Prerequisites

### Kindle

1. A jailbroken Kindle you own.
2. [KUAL](https://www.mobileread.com/forums/showthread.php?t=203326) and the
   MobileRead Package Installer, recommended for menus.
3. NiLuJe's [`linkss` screensaver hack](https://www.mobileread.com/forums/showthread.php?t=195474),
   installed and enabled (`/mnt/us/linkss/auto` exists).
4. FBInk at `/usr/bin/fbink`.
5. The `linkss` ImageMagick binary at `/mnt/us/linkss/bin/convert`.
6. Root SSH access with public-key authentication, commonly via USBNetwork and
   Dropbear. Use it only on a trusted network.

### Computer

- Python 3.10 or newer;
- OpenSSH `ssh` and `sftp`;
- network access to the awake Kindle;
- Git.

No third-party Python packages are required.

## Installation

```sh
git clone https://github.com/Stxr/kindle-photo-frame.git
cd kindle-photo-frame

KINDLE_HOST=root@KINDLE_IP
ssh -o BatchMode=yes "$KINDLE_HOST" 'hostname && uname -m'

python3 host/photo_frame.py deploy --host "$KINDLE_HOST"
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/install.sh
```

The root install backs up current screensavers, creates the managed screen, adds
a marked autostart stanza to the user-storage `linkss` script, and starts the
watcher. Root SSH is recommended because KUAL permissions vary by jailbreak.

Upload photos, then lock Kindle normally:

```sh
python3 host/photo_frame.py push --host "$KINDLE_HOST" photo1.jpg photo2.png
python3 host/photo_frame.py push --host "$KINDLE_HOST" /path/to/photo-folder
```

## Batch photo preparation

`push` accepts any number of JPEG/PNG files and directories. Directories are
searched recursively. Every new source is:

1. auto-oriented from EXIF metadata;
2. scaled to cover 1072×1448 without stretching;
3. center-cropped to the panel ratio;
4. converted to grayscale and at most 256 colors;
5. stripped of metadata and written as PNG8.

Prepared filenames include a checksum, so unchanged photos are reused.

```sh
python3 host/photo_frame.py push --host "$KINDLE_HOST" ~/Pictures/a.jpg ~/Pictures/b.png
python3 host/photo_frame.py push --host "$KINDLE_HOST" ~/Pictures/KindleAlbum
```

Runtime photos stay under `/mnt/us/photo-frame/`; the repository does not track
them.

## Rotation modes

### Hourly or daily

These choose a photo from the current wall-clock slot and preserve normal sleep,
making them the lowest-power choices. If the device is deeply suspended at a
boundary, the new photo appears on the next wake/lock cycle.

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-mode.sh hourly
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-mode.sh daily
```

### Minute test mode

Minute mode is for fast visual testing. It prevents deep suspend with
`suspendGrace`/`deferSuspend` and redraws every minute while locked. It uses
materially more battery and should not be left enabled.

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-mode.sh minute
```

Switching to hourly/daily or uninstalling restores normal suspend behavior.

### RTC deep-sleep mode

RTC mode lets the CPU suspend. Powerd wakes Kindle after the chosen interval,
the watcher redraws the next photo, and another alarm is scheduled before the
next suspend.

KUAL → **Photo Frame → RTC deep-sleep rotation** offers:

- 5 minutes (test);
- 15 minutes;
- 30 minutes;
- 1 hour;
- 1 day.

Set any interval from 60 to 86400 seconds over SSH:

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-rtc.sh 300
```

The five-minute cycle was verified on the reference PW3: the device entered
deep suspend, woke without Wi-Fi, changed its lock-screen image, and suspended
again. Accuracy and power behavior remain firmware-specific. Short intervals
spend proportionally more time in pre-suspend states; hourly/daily intervals
are better for normal use.

## KUAL menu and status

The **Photo Frame** menu contains install/repair, import, refresh, minute/hourly/
daily modes, RTC presets, status, and uninstall/restore.

```sh
python3 host/photo_frame.py status --host "$KINDLE_HOST"
# or
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/status.sh
```

Status reports the mode, RTC interval, next wake epoch, photo count, and current
image.

## Uninstall and recovery

Uninstall restores the screensavers backed up during initial installation and
removes only this project's marked autostart stanza. It keeps the photo library.

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/uninstall.sh
```

To also remove the KUAL entry:

```sh
ssh "$KINDLE_HOST" 'rm -rf /mnt/us/extensions/photo-frame'
```

That command targets only this extension. Do not remove `/mnt/us/photo-frame/`
unless you also want to delete photos, state, and logs.

## Troubleshooting

### The old `linkss` image still appears

- Confirm `/mnt/us/linkss/auto` exists.
- Run `device/import.sh`, then `device/pick.sh`.
- Confirm `/mnt/us/linkss/screensavers/bg_ss00.png` exists.
- Wake and lock once; `linkss` reads the image while entering sleep.

### The file changes, but the screen does not

`linkss` does not redraw after a background file replacement. Minute and RTC
modes use FBInk for this. Confirm `/usr/bin/fbink` exists and the watcher is root.

### RTC mode never wakes

- Verify `lipc-probe com.lab126.powerd` exposes `rtcWakeup`.
- Inspect `/mnt/us/photo-frame/photo-frame.log` for `readyToSuspend`,
  `scheduled RTC wake`, and `wakeupFromSuspend`.
- `rtcWakeup` can only be set during `readyToSuspend`; failure in another state
  is expected.
- Wi-Fi may remain off during a successful RTC wake, so an SSH timeout alone
  does not prove failure. Check the screen and inspect logs after manual wake.

### KUAL fails, but root SSH works

Some KUAL setups run as an unprivileged user without KMC/Gandalf. Install and
diagnose via root SSH. Do not make `/dev/fb0` permanently world-writable.

## Project layout

```text
device/                     Kindle-side POSIX shell scripts
extension/photo-frame/      KUAL extension
host/photo_frame.py         SSH/SFTP deployment and batch upload CLI
tests/                      standard-library unit tests
```

## Development

```sh
python3 -m unittest discover -s tests -v
```

Scripts target BusyBox/POSIX `sh` on older Kindle firmware. Keep Unix LF line
endings and avoid Bash-only syntax.

## Privacy and security

- Use SSH keys; never put passwords or private keys in scripts or Git.
- Expose Kindle SSH only on a trusted network.
- Photos, generated previews, logs, and runtime state are not tracked.
- Remote delivery is push-only; no public upload server is opened on Kindle.

## License

[MIT](LICENSE)

## Acknowledgements

- NiLuJe and MobileRead for Kindle jailbreak tooling and `linkss`.
- [FBInk](https://github.com/NiLuJe/FBInk) for E Ink rendering.
- [KOReader](https://github.com/koreader/koreader) for Kindle power-event work.
