"""Rehydrate verified CS16Forge knife viewmodels from the acquisition manifest."""

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import urllib.request
import zipfile


REPO = Path(__file__).resolve().parent.parent
MANIFEST = REPO / "models_src/knives/manifest.json"
DEFAULT_CACHE = REPO / ".orchestration/knives/zips"
DEFAULT_OUTPUT = REPO / "models_src/knives"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def checked_model(path, expected):
    return path.is_file() and sha256(path.read_bytes()) == expected


def fetch(entry, cache_dir, output_dir, offline):
    slug = entry["slug"]
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", slug):
        raise ValueError(f"Unsafe slug: {slug!r}")
    model = output_dir / slug / "v_knife.mdl"
    if checked_model(model, entry["mdl_sha256"]):
        print(f"VERIFIED {slug}: existing MDL")
        return
    if offline:
        raise ValueError(f"{slug}: missing or SHA-256-mismatched MDL: {model}")

    archive_path = cache_dir / (slug + ".zip")
    if archive_path.exists():
        archive = archive_path.read_bytes()
        origin = "cache"
    else:
        request = urllib.request.Request(entry["download_url"], headers={"User-Agent": "knife-acquisition"})
        with urllib.request.urlopen(request, timeout=90) as response:
            archive = response.read()
        origin = "download"
    if sha256(archive) != entry["zip_sha256"]:
        raise ValueError(f"{slug}: ZIP SHA-256 mismatch ({origin}): {archive_path}")

    with zipfile.ZipFile(io.BytesIO(archive)) as zf:
        matches = [info for info in zf.infolist()
                   if info.filename.replace("\\", "/").lower().endswith("/v_knife.mdl")
                   and not info.is_dir()]
        if len(matches) != 1:
            raise ValueError(f"{slug}: expected exactly one v_knife.mdl in ZIP, found {len(matches)}")
        data = zf.read(matches[0])  # Read exactly one model; never extract other ZIP entries.
    if sha256(data) != entry["mdl_sha256"]:
        raise ValueError(f"{slug}: extracted MDL SHA-256 mismatch")

    if origin == "download":
        cache_dir.mkdir(parents=True, exist_ok=True)
        temporary_zip = archive_path.with_suffix(".zip.part")
        temporary_zip.write_bytes(archive)
        os.replace(temporary_zip, archive_path)
    model.parent.mkdir(parents=True, exist_ok=True)
    temporary_model = model.with_suffix(".mdl.part")
    temporary_model.write_bytes(data)
    os.replace(temporary_model, model)
    print(f"VERIFIED {slug}: {origin}, {len(data)} MDL bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slug", action="append", help="Fetch/verify only this slug (repeatable)")
    parser.add_argument("--offline", action="store_true", help="Verify existing MDLs only; no network or extraction")
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE, help="ZIP cache directory")
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT, help="Model destination root")
    args = parser.parse_args()
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))
    known = {entry["slug"] for entry in entries}
    unknown = set(args.slug or []) - known
    if unknown:
        parser.error("unknown slug(s): " + ", ".join(sorted(unknown)))
    selected = [entry for entry in entries if args.slug is None or entry["slug"] in args.slug]
    try:
        for entry in selected:
            fetch(entry, args.cache_dir, args.output_root, args.offline)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"Verified {len(selected)} knife model(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
