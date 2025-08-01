#!/usr/bin/env python3

import sys
import os
import json

XATTR_NAME = "user.backup_id"
CONFIG_DIR = os.path.expanduser("~/.config/tagsync")
MANIFEST = os.path.join(CONFIG_DIR, "manifest.json")

verbose = False
debug = False

def show_help():
    print(f"""tsuntag.py - Remove or edit TagSync file tags
Usage:
  {sys.argv[0]} <file1> [file2 ...] [-n group1,group2] [-N] [-v]
Options:
  <file>          File(s) to untag or modify tag (required)
  -n, --names     Comma/semicolon list: remove only those names from tag
  -N, --nuke-names Remove all group names, keep UUID
  -v, --verbose   Print more info
      --debug     Print debug info
  -h, --help      Show this help
""")

def get_tag(file):
    try:
        return os.getxattr(file, XATTR_NAME).decode()
    except OSError as e:
        if getattr(e, 'errno', None) == 61:
            return None
        return None

def set_tag(file, tag):
    try:
        os.setxattr(file, XATTR_NAME, tag.encode())
        return True
    except Exception:
        print(f"{file}: Failed to set xattr.", file=sys.stderr)
        return False

def remove_tag(file):
    try:
        os.removexattr(file, XATTR_NAME)
        return True
    except Exception:
        print(f"{file}: Failed to remove tag.", file=sys.stderr)
        return False

# NEW: update manifest entry after tag change/removal
def update_manifest(file, tag, tag_removed=False):
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        if os.path.exists(MANIFEST):
            with open(MANIFEST, "r") as f:
                manifest = json.load(f)
        else:
            manifest = {}
    except Exception:
        manifest = {}
    abs_path = os.path.abspath(file)
    if tag_removed or not tag:
        if abs_path in manifest:
            del manifest[abs_path]
            if verbose:
                print(f"{file}: Removed from manifest.")
    else:
        try:
            st = os.lstat(file)
            entry = {
                "mtime": int(st.st_mtime),
                "ctime": int(st.st_ctime),
                "size": int(st.st_size),
                "tag": tag,
            }
            manifest[abs_path] = entry
            if verbose:
                print(f"{file}: Manifest updated.")
        except Exception as e:
            print(f"{file}: Failed to update manifest: {e}", file=sys.stderr)
    try:
        with open(MANIFEST, "w") as f:
            json.dump(manifest, f, indent=2)
    except Exception as e:
        print(f"{file}: Failed to write manifest: {e}", file=sys.stderr)

def parse_args():
    global verbose
    global debug

    files = []
    names = []
    nuke_names = False

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            show_help()
            sys.exit(0)
        elif arg == "--debug":
            debug = True
        elif arg in ("-v", "--verbose"):
            verbose = True
        elif arg in ("-n", "--names"):
            i += 1
            if i >= len(args):
                print("Missing name(s) after -n/--names", file=sys.stderr)
                sys.exit(1)
            names = [n.strip() for n in args[i].replace(';', ',').split(',') if n.strip()]
        elif arg in ("-N", "--nuke-names"):
            nuke_names = True
        elif arg.startswith('-'):
            print(f"Unknown argument: {arg}", file=sys.stderr)
            show_help()
            sys.exit(1)
        else:
            files.append(arg)
        i += 1

    if not files:
        show_help()
        sys.exit(1)
    if names and nuke_names:
        print("Can't use both -n and -N.", file=sys.stderr)
        sys.exit(1)
    return files, names, nuke_names

def Untag(file, names, nuke_names):
    old_tag = get_tag(file)
    if not old_tag or not old_tag.startswith("ts/"):
        if verbose:
            print(f"{file}: No ts/ tag found.")
        # NEW: Remove from manifest if it exists, just in case
        update_manifest(file, None, tag_removed=True)
        return

    tag_parts = old_tag.split('/', 2)
    if verbose:
        print(f"{file}: Old tag: {old_tag}")

    if not names and not nuke_names:
        # No group options: remove the whole attribute if it starts with ts/
        removed = remove_tag(file)
        if removed:
            print(f"{file}: tag removed")
            # NEW: Remove from manifest
            update_manifest(file, None, tag_removed=True)
        return

    unique_id = tag_parts[1] if len(tag_parts) > 1 else ""
    cur_names = tag_parts[2].split(';') if len(tag_parts) > 2 else []

    if nuke_names:
        new_tag = f"ts/{unique_id}"
        if verbose:
            print(f"{file}: nuked all names")
    elif names:
        # Remove only listed names
        new_names = [n for n in cur_names if n and n not in names]
        if not new_names:
            new_tag = f"ts/{unique_id}"
        else:
            new_tag = f"ts/{unique_id}/" + ";".join(new_names)
        if verbose:
            removed_names = [n for n in cur_names if n in names]
            if removed_names:
                print(f"{file}: removed: {', '.join(removed_names)}")
            if new_names:
                print(f"{file}: remaining: {', '.join(new_names)}")
            else:
                print(f"{file}: no names remain, only uuid kept")
    else:
        # Should never get here
        print(f"{file}: Internal error", file=sys.stderr)
        return

    if new_tag == old_tag:
        if verbose:
            print(f"{file}: tag unchanged.")
    else:
        tagged = set_tag(file, new_tag)
        if tagged:
            print(f"{file}: tag updated")
            # NEW: Update manifest (remove if no group names left)
            if new_tag == f"ts/{unique_id}":
                update_manifest(file, None, tag_removed=True)
            else:
                update_manifest(file, new_tag, tag_removed=False)

def main():
    global verbose
    global debug

    if verbose:
        print("Verbose mode.")
    if debug:
        print("Debug mode.")

    files, names, nuke_names = parse_args()

    for file in files:
        if not os.path.exists(file):
            print(f"{file}: File not found.", file=sys.stderr)
            # NEW: Remove from manifest if present
            update_manifest(file, None, tag_removed=True)
            continue
        Untag(file, names, nuke_names)

if __name__ == "__main__":
    main()
