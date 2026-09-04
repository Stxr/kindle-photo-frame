# Kindle Photo Frame

A low-power lock-screen photo album for jailbroken Kindle devices. The first
target is a Kindle Paperwhite 3 (1072×1448) with NiLuJe's `linkss` screensaver
hack installed.

The Kindle stays in its normal sleep mode. This project prepares one managed
screensaver and chooses its source from a local photo library by hour or day.
E Ink keeps the displayed image without a foreground app continuously running.

## Features

- local JPEG/PNG photo inbox;
- center-crop and grayscale conversion on the Kindle;
- deterministic minute (test), hourly, or daily rotation;
- atomic replacement of the `linkss` screensaver;
- SFTP deployment from a computer;
- backup and uninstall path for the pre-existing screensaver set;
- KUAL actions for import, refresh, mode selection, and status.
- a lightweight watcher that refreshes the selected slot while awake and reacts
  to Kindle sleep/wake events.

## Quick start

Deploy the extension and one or more photos while the Kindle is awake:

```sh
python3 host/photo_frame.py deploy --host root@KINDLE_IP
python3 host/photo_frame.py push --host root@KINDLE_IP photo1.jpg photo2.png
python3 host/photo_frame.py push --host root@KINDLE_IP /path/to/a/photo-folder
```

On the Kindle, open KUAL → **Photo Frame** → **Install / repair**, then choose
minute, hourly, or daily mode. The current image is selected immediately. Subsequent
photo imports refresh it automatically.

Installation adds a clearly marked autostart stanza to the existing user-storage
`linkss` startup script and keeps an original copy beside it. Uninstall removes
only that marked stanza and restores the prior screensaver images.

The device paths are:

- extension: `/mnt/us/extensions/photo-frame/`
- incoming originals: `/mnt/us/photo-frame/inbox/`
- prepared images: `/mnt/us/photo-frame/prepared/`
- active screen: `/mnt/us/linkss/screensavers/bg_ss00.png`

## Power behavior

Minute/hourly/daily means that the image selected at lock time corresponds to the
current time slot. Normal Kindle deep sleep does not promise execution of cron
jobs or networking while asleep. Strictly changing the already-visible image
at every wall-clock boundary would require a timed wake-up and costs more
battery; that is deliberately outside this first version.

The minute mode is intended for validation. While the Kindle is awake, the
watcher updates the prepared lock-screen file within roughly 15 seconds of a
minute boundary. While powerd remains in its `screenSaver` state, minute mode
also performs an explicit GC16 redraw so the change is visible without an
unlock. It uses `suspendGrace` in the lock-screen phase and renews
`deferSuspend` after powerd reaches `readyToSuspend`, preventing deep suspend so
the test can continue cycling. This uses materially more battery
and is not intended as the normal low-power mode. Switching to hourly/daily or
uninstalling resets the grace value to zero. A reliable long-interval refresh
from deep suspend requires a separate RTC timed-wake mechanism.

## Batch photo preparation

`host/photo_frame.py push` accepts any number of files and directories. It
recursively uploads JPEG/PNG files, then runs `device/import.sh` once on the
Kindle. Each new image is auto-oriented, center-cropped without stretching,
converted to grayscale, resized to 1072×1448, stripped of metadata, and saved
as PNG8. Previously converted files are reused by checksum.

## Development

Run the host-side and device-script tests:

```sh
python3 -m unittest discover -s tests -v
```
