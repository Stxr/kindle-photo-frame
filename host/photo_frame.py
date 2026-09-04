#!/usr/bin/env python3
"""Deploy Kindle Photo Frame and push photos over SSH/SFTP."""

from __future__ import annotations

import argparse
import pathlib
import shlex
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
REMOTE_ROOT = "/mnt/us/photo-frame"


def run(command: list[str], *, input_text: str | None = None) -> None:
    subprocess.run(command, input=input_text, text=True, check=True)


def ssh(host: str, command: str) -> None:
    run(["ssh", "-o", "BatchMode=yes", host, command])


def sftp(host: str, commands: list[str]) -> None:
    run(["sftp", "-b", "-", host], input_text="\n".join(commands) + "\n")


def deploy(host: str) -> None:
    ssh(
        host,
        "mkdir -p /mnt/us/photo-frame/bin /mnt/us/photo-frame/inbox "
        "/mnt/us/extensions/photo-frame/bin",
    )
    uploads: list[tuple[pathlib.Path, str]] = []
    for source in sorted((ROOT / "device").glob("*.sh")):
        uploads.append((source, f"{REMOTE_ROOT}/bin/{source.name}"))
    for source in sorted((ROOT / "extension" / "photo-frame").glob("*")):
        if source.is_file():
            uploads.append((source, f"/mnt/us/extensions/photo-frame/{source.name}"))
    uploads.append(
        (
            ROOT / "extension" / "photo-frame" / "bin" / "run.sh",
            "/mnt/us/extensions/photo-frame/bin/run.sh",
        )
    )
    commands = [f"put {shlex.quote(str(src))} {shlex.quote(dst)}" for src, dst in uploads]
    sftp(host, commands)
    ssh(
        host,
        "chmod 0755 /mnt/us/photo-frame/bin/*.sh "
        "/mnt/us/extensions/photo-frame/bin/*.sh",
    )


SUPPORTED_SUFFIXES = {".jpg", ".jpeg", ".png"}


def collect_photos(inputs: list[pathlib.Path]) -> list[pathlib.Path]:
    photos: list[pathlib.Path] = []
    for item in inputs:
        if item.is_dir():
            photos.extend(
                child
                for child in sorted(item.rglob("*"))
                if child.is_file() and child.suffix.lower() in SUPPORTED_SUFFIXES
            )
        elif item.is_file() and item.suffix.lower() in SUPPORTED_SUFFIXES:
            photos.append(item)
    return photos


def push(host: str, inputs: list[pathlib.Path]) -> None:
    missing = [str(item) for item in inputs if not item.exists()]
    if missing:
        raise SystemExit("Missing photo(s): " + ", ".join(missing))
    photos = collect_photos(inputs)
    if not photos:
        raise SystemExit("No JPEG or PNG photos found")
    ssh(host, f"mkdir -p {REMOTE_ROOT}/inbox")
    commands = [
        f"put {shlex.quote(str(photo.resolve()))} "
        f"{shlex.quote(REMOTE_ROOT + '/inbox/' + photo.name)}"
        for photo in photos
    ]
    sftp(host, commands)
    ssh(host, f"{REMOTE_ROOT}/bin/import.sh")


def status(host: str) -> None:
    run(["ssh", "-o", "BatchMode=yes", host, f"{REMOTE_ROOT}/bin/status.sh"])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("deploy", "status"):
        child = subparsers.add_parser(name)
        child.add_argument("--host", required=True, help="SSH target, e.g. root@KINDLE_IP")
    child = subparsers.add_parser("push")
    child.add_argument("--host", required=True)
    child.add_argument("photos", nargs="+", type=pathlib.Path, help="photo files or directories")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "deploy":
        deploy(args.host)
    elif args.command == "push":
        push(args.host, args.photos)
    elif args.command == "status":
        status(args.host)
    return 0


if __name__ == "__main__":
    sys.exit(main())
