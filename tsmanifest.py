#!/usr/bin/env python3.12

import sys
import os
import json
import datetime

XATTR_NAME = "user.backup_id"
CONFIG_DIR = os.path.expanduser("~/.config/tagsync")
MANIFEST = os.path.join(CONFIG_DIR, "manifest.json")

verbose = False

def show_help():
    print(f"""tsmanifest.py - TagSync manifest manager

Usage:
  {sys.argv[0]} [--flush] [--scan DIR ...] [--update] [--rebuild DIR ...] [-v]

Options:
  --flush             Empty out the manifest before scanning/adding
  --scan DIR ...      One or more directories to scan recursively for tagged files/dirs and add/update manifest entries
  --update            Update manifest entries for all recorded files (refresh info and set 'date_missing' if not found)
  --rebuild DIR ...   Attempt to find/re-link files with 'date_missing' in manifest by searching these dirs for matching tags
  -v, --verbose       Print more info
  -h, --help          Show this help
""")

def get_tag(path):
    try:
        return os.getxattr(path, XATTR_NAME).decode()
    except OSError as e:
        # [Errno 61] No data available = xattr not set, so treat as untagged
        if getattr(e, 'errno', None) == 61:
            return None
        return None

def load_manifest(filename):
    if not os.path.exists(filename):
        return {}
    try:
        with open(filename, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def save_manifest(manifest, filename):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, "w") as f:
        json.dump(manifest, f, indent=2)

def collect_info(obj, tag):
    """Return stat info dict for the given file if tag is present, else None."""
    try:
        st = os.lstat(obj)
        return {
            "mtime": int(st.st_mtime),
            "ctime": int(st.st_ctime),
            "size": int(st.st_size),
            "tag": tag,
        }
    except Exception as e:
        print(f"{obj}: Failed to stat: {e}", file=sys.stderr)
        return None

def scan_and_collect(base_path):
    found = {}

    for dirpath, dirnames, filenames in os.walk(base_path):
        # We don't want to manifest a dest dir
        tagsync_path = os.path.join(dirpath, "tagsync.json")
        if os.path.isfile(tagsync_path):
            try:
                with open(tagsync_path, "r") as f:
                    data = json.load(f)
                if data.get("type") == "dest":
                    print(
                        f"\n\n*** ERROR: Directory '{dirpath}' is a TagSync backup destination (tagsync.json type='dest'). ***\n"
                        f"Refusing to scan here. This would be tragic. Exiting.\n",
                        file=sys.stderr,
                    )
                    sys.exit(66)
            except Exception as e:
                print(
                    f"WARNING: Could not read {tagsync_path}: {e} -- continuing anyway.",
                    file=sys.stderr,
                )
        # Continue regular scan
        for entry in filenames + dirnames:
            obj = os.path.join(dirpath, entry)
            tag = get_tag(obj)
            if not (tag and tag.startswith("ts/")):
                continue
            info = collect_info(obj, tag)
            if info:
                found[os.path.abspath(obj)] = info
                if verbose:
                    print(f"Found: {obj} (size {info['size']}, mtime {info['mtime']}, tag {tag})")
    return found

def update_manifest_entries(manifest):
    changed = False
    now = datetime.datetime.now().isoformat()
    for abspath, entry in manifest.items():
        if os.path.exists(abspath):
            try:
                st = os.lstat(abspath)
                tag = get_tag(abspath)
                entry["mtime"] = int(st.st_mtime)
                entry["ctime"] = int(st.st_ctime)
                entry["size"] = int(st.st_size)
                entry["tag"] = tag
                entry["date_updated"] = now
                if "date_missing" in entry:
                    del entry["date_missing"]
                if verbose:
                    print(f"{abspath}: Updated entry.")
                changed = True
            except Exception as e:
                print(f"{abspath}: Failed to update entry: {e}", file=sys.stderr)
        else:
            if "date_missing" not in entry:
                entry["date_missing"] = now
                if verbose:
                    print(f"{abspath}: File missing, date_missing set.")
                changed = True
    return changed

def parse_args():
    global verbose
    flush = False
    scan_dirs = []
    update_manifest_flag = False
    rebuild_dirs = []
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            show_help()
            sys.exit(0)
        elif arg == "--flush":
            flush = True
            i += 1
        elif arg in ("-v", "--verbose"):
            verbose = True
            i += 1
        elif arg == "--scan":
            i += 1
            if i >= len(args):
                print("--scan requires at least one directory", file=sys.stderr)
                show_help()
                sys.exit(1)
            while i < len(args) and not args[i].startswith("-"):
                scan_dirs.append(args[i])
                i += 1
        elif arg == "--update":
            update_manifest_flag = True
            i += 1
        elif arg == "--rebuild":
            i += 1
            if i >= len(args):
                print("--rebuild requires at least one directory", file=sys.stderr)
                show_help()
                sys.exit(1)
            while i < len(args) and not args[i].startswith("-"):
                rebuild_dirs.append(args[i])
                i += 1
        else:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            show_help()
            sys.exit(1)
    return flush, scan_dirs, update_manifest_flag, rebuild_dirs

def get_missing_manifest_entries(manifest):
    """Return a list of (abspath, entry) for manifest items with date_missing set."""
    return [(abspath, entry) for abspath, entry in manifest.items() if "date_missing" in entry]

def build_uuid_lookup(missing_entries):
    """Return a dict mapping uuid -> (abspath, entry) for all missing manifest entries."""
    uuid_to_manifestkey = {}
    for abspath, entry in missing_entries:
        tag = entry.get("tag", "")
        if tag and tag.startswith("ts/"):
            uuid = tag.split("/", 2)[1]
            uuid_to_manifestkey[uuid] = (abspath, entry)
    return uuid_to_manifestkey

def find_tagged_files_by_uuid(search_dirs, uuids):
    """Return dict of uuid -> found_path for any file in search_dirs with a tag matching uuids."""
    found = {}
    for search_dir in search_dirs:
        for dirpath, dirnames, filenames in os.walk(search_dir):
            for name in filenames + dirnames:
                path = os.path.join(dirpath, name)
                tag = get_tag(path)
                if tag and tag.startswith("ts/"):
                    uuid = tag.split("/", 2)[1]
                    if uuid in uuids:
                        found[uuid] = path
    return found

def update_manifest_entry_for_found_file(manifest, old_abspath, entry, found_path):
    st = os.lstat(found_path)
    tag = get_tag(found_path)
    entry["mtime"] = int(st.st_mtime)
    entry["ctime"] = int(st.st_ctime)
    entry["size"] = int(st.st_size)
    entry["tag"] = tag
    entry["date_updated"] = datetime.datetime.now().isoformat()
    entry.pop("date_missing", None)
    # If path changed, update the manifest key
    if os.path.abspath(found_path) != old_abspath:
        manifest[os.path.abspath(found_path)] = entry
        del manifest[old_abspath]
    else:
        manifest[old_abspath] = entry

def rebuild_missing_files(manifest, rebuild_dirs):
    missing = get_missing_manifest_entries(manifest)
    if not missing:
        print("No missing files found in manifest. Run --update first to mark missing files.")
        return

    uuid_to_manifestkey = build_uuid_lookup(missing)
    if not uuid_to_manifestkey:
        print("No missing files with valid TagSync UUID found in manifest.")
        return

    # Search for missing files by uuid
    found = find_tagged_files_by_uuid(rebuild_dirs, set(uuid_to_manifestkey.keys()))
    found_count = 0

    # Update found entries in manifest
    for uuid, found_path in found.items():
        abspath, entry = uuid_to_manifestkey[uuid]
        update_manifest_entry_for_found_file(manifest, abspath, entry, found_path)
        if os.path.abspath(found_path) != abspath:
            print(f"Restored missing file {uuid}: new path {found_path}")
        else:
            print(f"Restored missing file {uuid}: {found_path}")
        found_count += 1

    # Print not found messages for remaining
    missing_uuids = set(uuid_to_manifestkey.keys()) - set(found.keys())
    for uuid in missing_uuids:
        print(f"File for missing tag {uuid} not found in rebuild dirs.")

    if found_count == 0:
        print("No missing files were restored.")

def main():
    if len(sys.argv) == 1:
        show_help()
        sys.exit(0)
    flush, scan_dirs, update_manifest_flag, rebuild_dirs = parse_args()

    if flush:
        flush_manifest()
        if not scan_dirs and not update_manifest_flag and not rebuild_dirs:
            return

    manifest = load_manifest(MANIFEST)

    if scan_dirs:
        validate_scan_dirs(scan_dirs)
        scan_and_update_manifest(manifest, scan_dirs)

    if update_manifest_flag:
        changed = update_manifest_entries(manifest)
        save_manifest(manifest, MANIFEST)
        if verbose:
            print(f"Manifest updated for existing files.")

    if rebuild_dirs:
        rebuild_missing_files(manifest, rebuild_dirs)
        save_manifest(manifest, MANIFEST)

if __name__ == "__main__":
    main()

def flush_manifest():
    save_manifest({}, MANIFEST)
    if verbose:
        print(f"Manifest flushed at {MANIFEST}")

def validate_scan_dirs(scan_dirs):
    for scan_dir in scan_dirs:
        if not os.path.exists(scan_dir) or not os.path.isdir(scan_dir):
            print(f"Not a directory: {scan_dir}", file=sys.stderr)
            sys.exit(1)

def scan_and_update_manifest(manifest, scan_dirs):
    now = datetime.datetime.now().isoformat()
    total_collected = 0
    for scan_dir in scan_dirs:
        collected = scan_and_collect(scan_dir)
        for abspath, info in collected.items():
            if abspath not in manifest:
                info["date_added"] = now
            info["date_updated"] = now
            manifest[abspath] = info
        total_collected += len(collected)
    save_manifest(manifest, MANIFEST)
    if verbose:
        print(f"Wrote manifest for {total_collected} objects (total {len(manifest)}) to {MANIFEST}")

def main():
    if len(sys.argv) == 1:
        show_help()
        sys.exit(0)
    flush, scan_dirs, update_manifest_flag = parse_args()

    if flush:
        flush_manifest()
        if not scan_dirs and not update_manifest_flag:
            return

    manifest = load_manifest(MANIFEST)

    if scan_dirs:
        validate_scan_dirs(scan_dirs)
        scan_and_update_manifest(manifest, scan_dirs)

    if update_manifest_flag:
        changed = update_manifest_entries(manifest)
        save_manifest(manifest, MANIFEST)
        if verbose:
            print(f"Manifest updated for existing files.")

if __name__ == "__main__":
    main()

