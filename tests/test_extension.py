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

    def test_each_rotation_choice_has_selected_and_unselected_variant(self) -> None:
        root_items = json.loads((EXTENSION / "menu.json").read_text())["items"][0]["items"]
        rtc_items = next(item for item in root_items if item["name"] == "Auto-wake rotation interval")["items"]
        choices = [item for item in root_items if item.get("params") == "minute"]
        choices.extend(rtc_items)
        for param in ("minute", "rtc300", "rtc900", "rtc1800", "rtc3600", "rtc86400"):
            variants = [item for item in choices if item.get("params") == param]
            self.assertEqual(len(variants), 2, param)
            self.assertEqual(sum(item["name"].startswith("✓ ") for item in variants), 1, param)
            self.assertTrue(all("if" in item and item.get("refresh") is True for item in variants))

    def test_kual_does_not_offer_non_waking_hourly_or_daily_modes(self) -> None:
        menu = json.loads((EXTENSION / "menu.json").read_text())
        params = {item.get("params") for item in menu["items"][0]["items"]}
        self.assertFalse({"hourly", "daily"} & params)


if __name__ == "__main__":
    unittest.main()
