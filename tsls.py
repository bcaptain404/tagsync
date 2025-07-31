#!/usr/bin/env python3

import sys
import os

XATTR_NAME = "user.backup_id"

verbose = False
debug = False

def show_help():
    print(f"""tsls.py - List TagSync-tagged files and directories
Usage:
  {sys.argv[0]} <file_or_dir1> [file_or_dir2 ...] [-n group1,group2] [-v]
Options:
  <file_or_dir>   File(s) or directory(ies) to search (defaults to current directory if none given)
  -n, --names     Comma or semicolon-separated list of group names to filter by
  -v, --verbose   Print more info
      --debug     Print debug info
  -h, --help      Show this help

Examples:
  {sys.argv[0]}            # List all tagged files in .
  {sys.argv[0]} -n foo,bar mydir
  {sys.argv[0]} --debug -n foo .
""")

def get_tag(file):
    try:
        return os.getxattr(file, XATTR_NAME).decode()
    except OSError as e:
        # [Errno 61] No data available = xattr not set, so treat as untagged
        if getattr(e, 'errno', None) == 61:
            return None
        return None

def parse_args():
    global verbose
    global debug

    paths = []
    names = []

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
        elif arg.startswith('-'):
            print(f"Unknown argument: {arg}", file=sys.stderr)
            show_help()
            sys.exit(1)
        else:
            paths.append(arg)
        i += 1

    if not paths:
        paths = ["."]
    return paths, names

def tag_matches(tag, names):
    if not tag or not tag.startswith("ts/"):
        return False
    if not names:
        return True
    tag_parts = tag.split("/", 2)
    if len(tag_parts) < 3:
        return False
    tag_names = [n for n in tag_parts[2].split(";") if n]
    return any(name in tag_names for name in names)

def list_tagged(path, names):
    listed = False

    if os.path.isdir(path) and not os.path.islink(path):
        try:
            files = os.listdir(path)
        except Exception as e:
            print(f"{path}: Error reading directory: {e}", file=sys.stderr)
            return False
        for f in files:
            obj = os.path.join(path, f)
            tag = get_tag(obj)
            if debug:
                print(f"DEBUG: {obj}: tag={tag}", file=sys.stderr)
            if tag_matches(tag, names):
                print(obj)
                listed = True
    elif os.path.exists(path) or os.path.islink(path):
        tag = get_tag(path)
        if debug:
            print(f"DEBUG: {path}: tag={tag}", file=sys.stderr)
        if tag_matches(tag, names):
            print(path)
            listed = True
    else:
        print(f"{path}: File or directory not found.", file=sys.stderr)
    return listed

def main():
    global verbose
    global debug

    if verbose:
        print("Verbose mode.")
    if debug:
        print("Debug mode.")

    paths, names = parse_args()
    found_any = False

    for path in paths:
        if list_tagged(path, names):
            found_any = True

    if not found_any and verbose:
        print("No tagged files or directories found matching criteria.")

if __name__ == "__main__":
    main()
