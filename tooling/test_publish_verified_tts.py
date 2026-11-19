import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from zipfile import ZipFile

from publish_verified_tts import (
    catalog_entries, inspect_zip, publish_grade, validate_source
)


class PublishAudioTest(unittest.TestCase):
    def test_real_catalog_ids_are_backed_by_current_flutter_content(self):
        catalog = json.loads(Path(
            "frontend-flutter/assets/content/audio/catalog.json"
        ).read_text(encoding="utf-8"))
        self.assertEqual(catalog["schema"], "hhk-audio-v1")
        self.assertEqual([g["grade"] for g in catalog["grades"]], [1, 2, 3, 4, 5])
        self.assertEqual(sum(g["assetCount"] for g in catalog["grades"]), 4200)
        for grade in (1, 2, 3, 4, 5):
            row, ids = catalog_entries(catalog, grade)
            data = json.loads(Path(
                f"frontend-flutter/assets/content/grades/grade-{grade}.json"
            ).read_text(encoding="utf-8"))
            available = {c["id"] for c in data["cards"] if c.get("isActive") != 0}
            self.assertEqual(len(ids), row["assetCount"])
            self.assertEqual(ids - available, set())
            # Old Drive bundles do not contain audio for 140 new cards per grade.
            self.assertEqual(len(available - ids), 140)

    def test_source_zip_is_verified_before_any_publishing(self):
        with TemporaryDirectory() as temp:
            directory = Path(temp)
            target = directory / "grade-1.zip"
            track = b"\xff\xfb\x90\x64\x11\x22\x33\x44"
            internal = "audio\\tts\\assets\\vi-v1\\lesson-card-42.mp3"
            manifest = {"entries": {
                "lesson-card:42": {
                    "available": True,
                    "assetPath": "audio/tts/assets/vi-v1/lesson-card-42.mp3"
                }
            }}
            with ZipFile(target, "w") as archive:
                archive.writestr(internal, track)
                archive.writestr("manifest.json", json.dumps(manifest))
            raw = target.read_bytes()
            row = {"grade": 1, "fileName": "grade-1.zip",
                   "sha256": hashlib.sha256(raw).hexdigest(),
                   "sizeBytes": len(raw), "assetCount": 1}
            self.assertEqual(inspect_zip(target, {42}), [42])
            self.assertEqual(validate_source(target, row, {42}), [42])
            self.assertEqual(publish_grade(target, row, {42},
                directory / "dist"), 1)
            published = directory / "dist/audio/tts/2026-04-27-v1/grade-1/lesson-card-42.mp3"
            self.assertEqual(published.read_bytes(), track)
            bundle = directory / "dist/audio/tts/2026-04-27-v1/packs/grade-1.zip"
            self.assertEqual(bundle.read_bytes(), raw)
            row["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                validate_source(target, row, {42})

    def test_archive_with_traversal_or_missing_card_cannot_be_released(self):
        with TemporaryDirectory() as temp:
            directory = Path(temp)
            bad = directory / "bad.zip"
            with ZipFile(bad, "w") as archive:
                archive.writestr("../lesson-card-42.mp3", b"bad")
                archive.writestr("manifest.json", '{"entries":{}}')
            with self.assertRaisesRegex(ValueError, "Unsafe"):
                inspect_zip(bad, {42})
            missing = directory / "missing.zip"
            with ZipFile(missing, "w") as archive:
                archive.writestr("manifest.json", '{"entries":{}}')
            with self.assertRaisesRegex(ValueError, "Missing card"):
                inspect_zip(missing, {42})


if __name__ == "__main__":
    unittest.main()
