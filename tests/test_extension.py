from __future__ import annotations

import json
import pathlib
import unittest
import xml.etree.ElementTree as ET


ROOT = pathlib.Path(__file__).resolve().parents[1]
EXTENSION = ROOT / "extension" / "photo-frame"


class ExtensionTests(unittest.TestCase):
    def test_config_registers_existing_dynamic_menu(self) -> None:
        config = ET.parse(EXTENSION / "config.xml")
        menu = config.find("./menus/menu")
        self.assertIsNotNone(menu)
        assert menu is not None
        self.assertEqual(menu.attrib, {"type": "json", "dynamic": "true"})
        self.assertEqual(menu.text, "menu.json")
        self.assertTrue((EXTENSION / menu.text).is_file())

    def test_menu_has_photo_frame_root(self) -> None:
        menu = json.loads((EXTENSION / "menu.json").read_text())
        self.assertEqual(menu["items"][0]["name"], "Photo Frame")


if __name__ == "__main__":
    unittest.main()
