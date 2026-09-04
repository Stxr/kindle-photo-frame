#!/usr/bin/env python3
"""Render Kindle-ready photos with a caption area from a JSON manifest."""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from typing import Any


WIDTH = 1072
HEIGHT = 1448
TEXT_HEIGHT = 228
PADDING = 54


def load_manifest(path: pathlib.Path) -> list[dict[str, str]]:
    data: Any = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("manifest must be a JSON array")
    items: list[dict[str, str]] = []
    for number, raw in enumerate(data, start=1):
        if not isinstance(raw, dict) or not raw.get("image") or not raw.get("caption"):
            raise ValueError(f"item {number} requires image and caption")
        items.append(
            {
                "image": str(raw["image"]),
                "caption": str(raw["caption"]).strip(),
                "subtitle": str(raw.get("subtitle", "")).strip(),
            }
        )
    return items


def wrap_text(draw: Any, text: str, font: Any, max_width: int, max_lines: int = 2) -> list[str]:
    lines: list[str] = []
    current = ""
    for char in text:
        candidate = current + char
        if current and draw.textlength(candidate, font=font) > max_width:
            lines.append(current)
            current = char
            if len(lines) == max_lines:
                return lines
        else:
            current = candidate
    if current and len(lines) < max_lines:
        lines.append(current)
    return lines


def render(item: dict[str, str], source: pathlib.Path, output: pathlib.Path, font_path: pathlib.Path) -> None:
    try:
        from PIL import Image, ImageDraw, ImageFont, ImageOps
    except ImportError as exc:
        raise SystemExit(
            "Caption rendering needs Pillow: python3 -m pip install -r requirements-caption.txt"
        ) from exc

    with Image.open(source) as opened:
        image = ImageOps.exif_transpose(opened).convert("RGB")
        photo = ImageOps.fit(
            image,
            (WIDTH, HEIGHT - TEXT_HEIGHT),
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )
    canvas = Image.new("RGB", (WIDTH, HEIGHT), "white")
    canvas.paste(photo, (0, 0))
    draw = ImageDraw.Draw(canvas)
    caption_font = ImageFont.truetype(str(font_path), 42)
    subtitle_font = ImageFont.truetype(str(font_path), 27)
    top = HEIGHT - TEXT_HEIGHT + 34
    for line in wrap_text(draw, item["caption"], caption_font, WIDTH - 2 * PADDING):
        draw.text((PADDING, top), line, font=caption_font, fill="black")
        top += 54
    if item["subtitle"]:
        draw.text(
            (PADDING, HEIGHT - 50),
            item["subtitle"],
            font=subtitle_font,
            fill=(80, 80, 80),
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("L").quantize(colors=256).save(output, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=pathlib.Path, help="JSON caption manifest")
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--font", type=pathlib.Path, required=True, help="Chinese TTF/OTF font")
    args = parser.parse_args()
    if not args.font.is_file():
        parser.error(f"font not found: {args.font}")
    base = args.manifest.resolve().parent
    for item in load_manifest(args.manifest):
        source = (base / item["image"]).resolve()
        if not source.is_file():
            parser.error(f"image not found: {source}")
        output = args.output / f"{source.stem}-caption.png"
        render(item, source, output, args.font)
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
