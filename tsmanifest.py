#!/usr/bin/env python3

import sys
import os
import json

XATTR_NAME = "user.backup_id"
CONFIG_DIR = os.path.expanduser("~/.config/tagsync")
MANIFEST = os.path.join(CONFIG_DIR, "manifest.json")

verbose = False

def show_help():
    print(f"""tsmanifest.py - Scan for TagSync-tagged files/dirs and update manifest.json.
Usage:
  {sys.argv[0]} [--flush] <path> [-v]
Options:
  <path>        Directory to scan recursively for tagged files/dirs
  --flush       Empty out the manifest before scanning/adding
  -v, --verbose Print more info
  -h, --help    Show this help
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

def parse_args():
    global verbose
    args = sys.argv[1:]
    path = None
    flush = False
    for arg in args:
        if arg in ("-h", "--help"):
            show_help()
            sys.exit(0)
        elif arg in ("-v", "--verbose"):
            verbose = True
        elif arg == "--flush":
            flush = True
        elif path is None:
            path = arg
        else:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            show_help()
            sys.exit(1)
    return flush, (os.path.abspath(path) if path else None)

def main():
    flush, path = parse_args()

    if flush:
        # Empty out the manifest first
        save_manifest({}, MANIFEST)
        if verbose:
            print(f"Manifest flushed at {MANIFEST}")
        # If no path to scan, just exit
        if not path:
            return

    if not path:
        show_help()
        sys.exit(1)
    if not os.path.exists(path) or not os.path.isdir(path):
        print(f"Not a directory: {path}", file=sys.stderr)
        sys.exit(1)

    manifest = load_manifest(MANIFEST)
    collected = scan_and_collect(path)
    manifest.update(collected)
    save_manifest(manifest, MANIFEST)
    if verbose:
        print(f"Wrote manifest for {len(collected)} objects (total {len(manifest)}) to {MANIFEST}")

if __name__ == "__main__":
    main()
