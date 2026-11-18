#!/usr/bin/env python3
"""Prepare verifiable, immutable PWA MP3 assets from original private Drive ZIPs.

ZIPs are NOT committed, fetched by CI, or trusted by their names. A manual
release must provide the actual bytes and verify them against the catalog.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from zipfile import ZipFile, BadZipFile

ENTRY_RE = re.compile(r"^audio/tts/assets/vi-v1/lesson-card-([1-9][0-9]*)\.mp3$")
SHA = re.compile(r"^[a-f0-9]{64}$")
MAX_FILE_BYTES = 500_000


def catalog_entries(catalog, grade):
    row = next((r for r in catalog.get("grades", []) if r.get("grade") == grade), None)
    if row is None:
        raise ValueError("Unknown grade")
    ranges = row.get("ranges")
    if not isinstance(ranges, list):
        raise ValueError("Missing audio ranges")
    ids = set()
    for pair in ranges:
        if not isinstance(pair, list) or len(pair) != 2 or \
           not all(type(n) is int for n in pair):
            raise ValueError("Invalid range")
        lo, hi = pair
        if lo < 1 or hi > 100000 or lo > hi or hi - lo > 1000:
            raise ValueError("Unsafe card range")
        for number in range(lo, hi + 1):
            if number in ids:
                raise ValueError("Duplicated card")
            ids.add(number)
    if len(ids) != row["assetCount"]:
        raise ValueError("Audio catalog count mismatch")
    return row, ids


def validate_source(source, row, expected_ids):
    if source.name != row["fileName"] or not SHA.fullmatch(row["sha256"]):
        raise ValueError("Unexpected source identity")
    if source.stat().st_size != row["sizeBytes"]:
        raise ValueError(f"Source {source.name} byte-size mismatch")
    h = hashlib.sha256()
    with source.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            h.update(chunk)
    if h.hexdigest() != row["sha256"]:
        raise ValueError(f"Source {source.name} SHA-256 mismatch")
    return inspect_zip(source, expected_ids)


def inspect_zip(source, expected_ids):
    with ZipFile(source) as archive:
        found = {}
        seen = set()
        for file in archive.infolist():
            # The original ZIP uses Windows backslashes for paths.
            name = file.filename.replace("\\", "/")
            if name.startswith("/") or ".." in Path(name).parts or \
               ((file.external_attr >> 16) & 0o170000) == 0o120000 or \
               name in seen:
                raise ValueError(f"Unsafe or duplicate ZIP entry: {name}")
            seen.add(name)
            match = ENTRY_RE.fullmatch(name)
            if file.is_dir() or match is None:
                continue
            card_id = int(match.group(1))
            if card_id not in expected_ids or card_id in found:
                raise ValueError("Unexpected or duplicate card audio")
            if file.file_size <= 0 or file.file_size > MAX_FILE_BYTES:
                raise ValueError("Card audio outside safe size limit")
            found[card_id] = file
        if set(found) != expected_ids:
            raise ValueError(f"Missing card audio: {len(expected_ids - set(found))}")
        # The source must include an internal manifest mapping those same IDs.
        manifest = json.loads(archive.read("manifest.json"))
        entries = manifest.get("entries", {})
        for card_id, file in found.items():
            record = entries.get(f"lesson-card:{card_id}")
            if not isinstance(record, dict) or record.get("available") is not True or \
               record.get("assetPath") != f"audio/tts/assets/vi-v1/lesson-card-{card_id}.mp3":
                raise ValueError(f"Invalid internal audio mapping: {card_id}")
        # Verify all CRCs (including manifest & feedback) before publish.
        bad = archive.testzip()
        if bad:
            raise ValueError(f"Archive CRC invalid: {bad}")
        return sorted(found)


def publish_grade(archive_path, row, ids, out_root, *, dry_run=False):
    validate_source(archive_path, row, ids)
    if dry_run:
        return len(ids)
    dest = out_root / "audio" / "tts" / "2026-04-27-v1" / f"grade-{row['grade']}"
    dest.mkdir(parents=True, exist_ok=True)
    with ZipFile(archive_path) as archive:
        names = {
            file.filename.replace("\\", "/"): file.filename
            for file in archive.infolist()
        }
        for card_id in sorted(ids):
            path = f"audio/tts/assets/vi-v1/lesson-card-{card_id}.mp3"
            data = archive.read(names[path])
            if not data or len(data) > MAX_FILE_BYTES or \
               not (data.startswith(b"ID3") or (data[0] == 0xFF and data[1] & 0xE0 == 0xE0)):
                raise ValueError(f"Invalid MP3 header in card {card_id}")
            (dest / f"lesson-card-{card_id}.mp3").write_bytes(data)
    return len(ids)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog",
                        default="frontend-flutter/assets/content/audio/catalog.json")
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    catalog = json.loads(Path(args.catalog).read_text(encoding="utf-8"))
    if catalog.get("schema") != "hhk-audio-v1" or \
       catalog.get("contentVersion") != "2026-04-27-v1":
        raise ValueError("Unsupported verified catalog")
    if not args.dry_run and args.output_dir is None:
        parser.error("--output-dir is required outside --dry-run")
    rows = catalog["grades"]
    if [r.get("grade") for r in rows] != [1, 2, 3, 4, 5]:
        raise ValueError("All five grades must be present")
    total = 0
    # Fail the whole release before publishing partial audio output.
    for row in rows:
        validated, ids = catalog_entries(catalog, row["grade"])
        validate_source(args.source_dir / validated["fileName"], validated, ids)
        total += len(ids)
    for row in rows:
        _, ids = catalog_entries(catalog, row["grade"])
        publish_grade(args.source_dir / row["fileName"], row, ids,
                      args.output_dir, dry_run=args.dry_run)
    print(json.dumps({"status": "VERIFIED_ALL", "grades": len(rows),
                      "cardAudioFiles": total, "dryRun": args.dry_run}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, BadZipFile, KeyError) as exc:
        print(json.dumps({"status": "BLOCKED", "error": str(exc)}),
              file=sys.stderr)
        sys.exit(2)
