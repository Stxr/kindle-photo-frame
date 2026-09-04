from __future__ import annotations

import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PICKER = ROOT / "device" / "pick.sh"
SET_MODE = ROOT / "device" / "set-mode.sh"


class PickerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        base = pathlib.Path(self.temp.name)
        self.prepared = base / "prepared"
        self.linkss = base / "linkss"
        self.state = base / "state"
        self.prepared.mkdir()
        self.linkss.mkdir()
        self.env = os.environ | {
            "PHOTO_FRAME_ROOT": str(base),
            "PHOTO_FRAME_PREPARED": str(self.prepared),
            "PHOTO_FRAME_STATE": str(self.state),
            "PHOTO_FRAME_LINKSS": str(self.linkss),
            "PHOTO_FRAME_ACTIVE": str(self.linkss / "bg_ss00.png"),
            "PHOTO_FRAME_CONFIG": str(base / "config"),
            "PHOTO_FRAME_LOG": str(base / "test.log"),
            "PATH": "/usr/bin:/bin",
        }

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_script(self, script: pathlib.Path, *args: str, epoch: int = 0):
        env = self.env | {"PHOTO_FRAME_EPOCH": str(epoch)}
        return subprocess.run(
            [str(script), *args], env=env, text=True, capture_output=True
        )

    def add_photos(self) -> None:
        for name, data in (("a.png", b"A"), ("b.png", b"B"), ("c.png", b"C")):
            (self.prepared / name).write_bytes(data)

    def test_daily_rotation_is_deterministic(self) -> None:
        self.add_photos()
        result = self.run_script(PICKER, epoch=86400 * 4)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.linkss / "bg_ss00.png").read_bytes(), b"B")
        self.assertEqual((self.state / "current").read_text().strip(), "b.png")

    def test_hourly_rotation(self) -> None:
        self.add_photos()
        result = self.run_script(SET_MODE, "hourly", epoch=3600 * 5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.linkss / "bg_ss00.png").read_bytes(), b"C")
        self.assertEqual((pathlib.Path(self.temp.name) / "config").read_text(), "mode=hourly\n")

    def test_minute_rotation(self) -> None:
        self.add_photos()
        result = self.run_script(SET_MODE, "minute", epoch=60 * 7)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.linkss / "bg_ss00.png").read_bytes(), b"B")
        self.assertEqual((self.state / "mode").read_text(), "minute\n")

    def test_same_slot_does_not_rewrite_active_image(self) -> None:
        self.add_photos()
        first = self.run_script(SET_MODE, "minute", epoch=60 * 7)
        self.assertEqual(first.returncode, 0, first.stderr)
        active = self.linkss / "bg_ss00.png"
        first_mtime = active.stat().st_mtime_ns
        second = self.run_script(PICKER, epoch=60 * 7 + 30)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(active.stat().st_mtime_ns, first_mtime)

    def test_empty_library_is_non_destructive(self) -> None:
        active = self.linkss / "bg_ss00.png"
        active.write_bytes(b"ORIGINAL")
        result = self.run_script(PICKER, epoch=0)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(active.read_bytes(), b"ORIGINAL")

    def test_invalid_mode_is_rejected(self) -> None:
        result = self.run_script(SET_MODE, "weekly")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
