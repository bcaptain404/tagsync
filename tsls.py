#!/usr/bin/env python3.12

import sys
import os
import subprocess

XATTR_NAME = "user.backup_id"

verbose = False
debug = False

def show_help():
    print(f"""tsls.py - List TagSync-tagged files and directories (ls-powered)
Usage:
  {sys.argv[0]} [file_or_dir ...] [-n group1,group2] [ls_opts...]
Options:
  <file_or_dir>   File(s) or directory(ies) to search (defaults to current directory if none given)
  -n, --names     Comma or semicolon-separated list of group names to filter by
  -v, --verbose   Print more info
      --debug     Print debug info
  -h, --help      Show this help
  [ls_opts...]    Any other options are passed directly to 'ls'

Examples:
  {sys.argv[0]} -n foo,bar mydir -l --color=always
  {sys.argv[0]} --debug -n foo . -lh
""")

def get_tag(file):
    try:
        return os.getxattr(file, XATTR_NAME).decode()
    except OSError as e:
        if getattr(e, 'errno', None) == 61:
            return None
        return None

def parse_args():
    global verbose
    global debug

    paths = []
    names = []
    passthrough_ls = []

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
        elif arg.startswith("-"):
            # All other unknown options are for 'ls'
            passthrough_ls.append(arg)
        else:
            paths.append(arg)
        i += 1

    if not paths:
        paths = ["."]
    return paths, names, passthrough_ls

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

def collect_tagged(paths, names):
    tagged = []
    for path in paths:
        if os.path.isdir(path) and not os.path.islink(path):
            try:
                files = os.listdir(path)
            except Exception as e:
                print(f"{path}: Error reading directory: {e}", file=sys.stderr)
                continue
            for f in files:
                obj = os.path.join(path, f)
                tag = get_tag(obj)
                if debug:
                    print(f"DEBUG: {obj}: tag={tag}", file=sys.stderr)
                if tag_matches(tag, names):
                    tagged.append(obj)
        elif os.path.exists(path) or os.path.islink(path):
            tag = get_tag(path)
            if debug:
                print(f"DEBUG: {path}: tag={tag}", file=sys.stderr)
            if tag_matches(tag, names):
                tagged.append(path)
        else:
            print(f"{path}: File or directory not found.", file=sys.stderr)
    return tagged

def main():
    global verbose
    global debug

    if verbose:
        print("Verbose mode.")
    if debug:
        print("Debug mode.")

    paths, names, passthrough_ls = parse_args()

    tagged = collect_tagged(paths, names)
    if not tagged:
        if verbose:
            print("No tagged files or directories found matching criteria.")
        sys.exit(1)

    # Call ls with passthrough arguments and all tagged files
    ls_cmd = ["ls"] + passthrough_ls + tagged
    if debug:
        print(f"DEBUG: Running: {' '.join(ls_cmd)}", file=sys.stderr)
    try:
        subprocess.run(ls_cmd)
    except Exception as e:
        print(f"Error running ls: {e}", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()
