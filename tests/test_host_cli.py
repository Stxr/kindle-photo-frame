from __future__ import annotations

import pathlib
import tempfile
import unittest

from host.photo_frame import collect_photos


class HostCliTests(unittest.TestCase):
    def test_collect_photos_recurses_and_filters(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            nested = root / "nested"
            nested.mkdir()
            (root / "a.JPG").write_bytes(b"a")
            (nested / "b.png").write_bytes(b"b")
            (nested / "notes.txt").write_text("skip")
            self.assertEqual(
                [path.name for path in collect_photos([root])],
                ["a.JPG", "b.png"],
            )


if __name__ == "__main__":
    unittest.main()
