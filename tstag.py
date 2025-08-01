#!/usr/bin/env python3

import sys
import os
import uuid
import json

XATTR_NAME = "user.backup_id"
CONFIG_DIR = os.path.expanduser("~/.config/tagsync")
MANIFEST = os.path.join(CONFIG_DIR, "manifest.json")

verbose=False
debug=False

def show_help():
    print(f"""tstag.py - Tag a file with a UUID and optional group names.
Usage:
  {sys.argv[0]} <file1> [file2 ...] [-n groupName1,groupName2] [-v]
Options:
  <file>         File(s) to tag (required)
  -n, --names    Comma or semicolon-separated list of group names (optional)
  -v, --verbose  Print more info
      --debug    Print debug info
  -h, --help     Show this help
""")

def get_tag(file):
    try:
        return os.getxattr(file, XATTR_NAME).decode()
    except OSError as e:
        # [Errno 61] No data available = xattr not set, so treat as untagged
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

def update_manifest(file, tag):
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        if os.path.exists(MANIFEST):
            with open(MANIFEST, "r") as f:
                manifest = json.load(f)
        else:
            manifest = {}
    except Exception:
        manifest = {}
    # Get file stat info
    try:
        st = os.lstat(file)
        entry = {
            "mtime": int(st.st_mtime),
            "ctime": int(st.st_ctime),
            "size": int(st.st_size),
            "tag": tag,
        }
        manifest[os.path.abspath(file)] = entry
        with open(MANIFEST, "w") as f:
            json.dump(manifest, f, indent=2)
        if verbose:
            print(f"{file}: Manifest updated.")
    except Exception as e:
        print(f"{file}: Failed to update manifest: {e}", file=sys.stderr)

def parse_args():
    global verbose
    global debug

    files = []
    names = []

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            show_help()
            sys.exit(0)
        elif arg == "--debug":
            debug=True
        elif arg in ("-v", "--verbose"):
            verbose=True
        elif arg in ("-n", "--names"):
            i += 1
            if i >= len(args):
                print("Missing name(s) after -n/--names", file=sys.stderr)
                sys.exit(1)
            names = [n.strip() for n in args[i].replace(';', ',').split(',') if n.strip()]
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
    return files, names

def AddTag(file, names):
    old_tag = get_tag(file)
    cur_names=[]
    unique_id=""
    uuid_state=""
    tag_state=""

    if verbose:
        print( f"current file: {file}" )

    already_tagged = bool(old_tag)
    if already_tagged:
        uuid_state="!" # denotes a pre-existing attribute
        # Parse out any existing group names
        tag_parts = old_tag.split('/', 2)
        if len(tag_parts) >= 3:
            cur_names=[n for n in tag_parts[2].split(';')]
            if debug:
                print(f"#tag_parts: {len(tag_parts)}")
                print(f"#cur_names: {len(cur_names)}: {cur_names}")
        unique_id=tag_parts[1]
        if verbose:
            print( f"already tagged: {unique_id}")
            print( f"previous tag: {old_tag}")
    else:
        uuid_state="+" # denotes a new attribute 
        unique_id = f"{uuid.uuid4()}" # create the uuid
        if verbose:
            print( f"created new id: {unique_id}")

    new_names = [n for n in names if n and n not in cur_names]

    new_tag = "ts/" + unique_id
    note = f"{file}: ts/{uuid_state}{unique_id}"

    if cur_names or new_names: # add delimiter, all tags will be appended after
        new_tag += "/"
        note += "/"

    if cur_names:
        # add the old names back in
        new_tag += ";".join(cur_names)
        note += "!" + ";!".join(cur_names) # exclamation denotes old attribute

    if new_names:
        if cur_names:
            # must add semicolon
            new_tag += ";"
            note += ";"
        # now add the new names
        new_tag += ";".join(new_names)
        note += "+" + ";+".join(new_names) # plus sign denotes new attribute

    if verbose:
        print(f"setting tag: {new_tag}")

    if new_tag != old_tag:
        tagged = set_tag(file, new_tag)
        if not tagged:
            # Print an error instead of bailing out
            print(f"{file}: Error - failed to set tag.", file=sys.stderr)
            return
        update_manifest(file, new_tag)
    elif verbose:
        print("tag unchanged.")

    print(note)

def main():
    global verbose
    global debug

    if verbose:
        print("Verbose mode.")
    if debug:
        print("Debug mode.")

    files, names = parse_args()

    for file in files:
        if not os.path.exists(file):
            print(f"{file}: File not found.", file=sys.stderr)
            continue  # continue to next file (if supplied)
        AddTag(file, names)

if __name__ == "__main__":
    main()
