#!/usr/bin/env python3

import sys
import os
import subprocess

XATTR_NAME = "user.backup_id"

def show_help():
    print(f"""TagSync: tsinfo.py
Usage: {sys.argv[0]} [OPTIONS] <file|dir|symlink> [<file|dir|symlink>...]
  -F, --follow     Query the target of symlinks.
                   (Default: operate on the symlink itself.)
  -v, --verbose    Show extra details about what is happening.
  -q, --quiet      Only print warnings or errors.
  -h, --help       Show this help message.
  <file|dir|symlink>  One or more objects to query for backup ID.
""")

def warn(msg):
    print(msg, file=sys.stderr)

def log(msg, quiet):
    if not quiet:
        print(msg)

def vlog(msg, verbose, quiet):
    if verbose and not quiet:
        print(msg)

def get_xattr(path, follow_symlinks):
    try:
        if follow_symlinks:
            return os.getxattr(path, XATTR_NAME).decode()
        else:
            raise AttributeError()
    except Exception:
        # fallback to getfattr
        try:
            cmd = ["getfattr"]
            if not follow_symlinks:
                cmd += ["-h"]
            cmd += ["--only-values", "-n", XATTR_NAME, path]
            result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            return result.stdout.strip() if result.returncode == 0 else ''
        except Exception:
            return ''

def main():
    FOLLOW = False
    VERBOSE = False
    QUIET = False
    paths = []

    args = sys.argv[1:]
    while args:
        arg = args.pop(0)
        if arg in ("-h", "--help"):
            show_help()
            sys.exit(0)
        elif arg in ("-F", "--follow"):
            FOLLOW = True
        elif arg in ("-v", "--verbose"):
            VERBOSE = True
        elif arg in ("-q", "--quiet"):
            QUIET = True
        elif arg == "--":
            break
        elif arg.startswith('-'):
            warn(f"Unknown argument: {arg}")
            show_help()
            sys.exit(1)
        else:
            paths.append(arg)
    # Add any remaining args after -- (could be file paths)
    paths += args

    if not paths:
        show_help()
        sys.exit(1)

    for obj in paths:
        if not os.path.exists(obj) and not os.path.islink(obj):
            warn(f"WARNING: File, directory, or symlink not found: {obj}")
            continue
        tag_id = get_xattr(obj, FOLLOW)
        if tag_id:
            log(f"{obj}: {tag_id}", QUIET)
        else:
            log(f"{obj}: [not set]", QUIET)
            # To only show with --verbose, comment out line above and uncomment line below
            # vlog(f"{obj}: [not set]", VERBOSE, QUIET)

if __name__ == "__main__":
    main()
