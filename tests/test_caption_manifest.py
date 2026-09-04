from __future__ import annotations

import json
import pathlib
import tempfile
import unittest

from host.render_captions import load_manifest


class CaptionManifestTests(unittest.TestCase):
    def test_loads_caption_and_optional_subtitle(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "captions.json"
            path.write_text(
                json.dumps([{"image": "cat.jpg", "caption": "先看五秒", "subtitle": "家中"}]),
                encoding="utf-8",
            )
            self.assertEqual(load_manifest(path)[0]["caption"], "先看五秒")

    def test_rejects_missing_caption(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "captions.json"
            path.write_text('[{"image":"cat.jpg"}]', encoding="utf-8")
            with self.assertRaises(ValueError):
                load_manifest(path)


if __name__ == "__main__":
    unittest.main()
