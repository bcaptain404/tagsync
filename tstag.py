#!/usr/bin/env python3

import os
import sys
import uuid
import subprocess

XATTR_NAME = "user.backup_id"

def show_help():
    print(f"""TagSync: tstag.py
Usage: {sys.argv[0]} [options] [-n name[,name2...]]... [-x name[,name2...]]... [-X] [-r] <file> [<file> ...]
  -n, --name NAMES    Add one or more names to tag (comma or semicolon separated, may repeat).
  -x NAMES            Remove one or more names from tag (comma or semicolon separated, must provide at least one name).
  -X                  Remove all names (keep UUID).
  -r, --remove        Remove tag entirely.
  -F, --follow        Follow symlinks.
  --dry-run           Only show what would be done.
  -v, --verbose       Extra output.
  -q, --quiet         Only warnings/errors.
  -h, --help          Show help.

Examples:
  tstag.py -n foo,bar file.txt          # Tag file.txt as ts/uuid/foo;bar
  tstag.py -x foo file.txt              # Remove only 'foo' from tag names
  tstag.py -X file.txt                  # Remove all names (keep UUID)
  tstag.py -r file.txt                  # Remove the tag entirely
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
            # Use lgetxattr for symlink, but Python does not expose, so fallback to getfattr
            raise AttributeError()
    except Exception:
        # fallback to getfattr
        try:
            res = subprocess.run(
                ["getfattr"] + (["-h"] if not follow_symlinks else []) + ["--only-values", "-n", XATTR_NAME, path],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
            )
            return res.stdout.strip() if res.returncode == 0 else ''
        except Exception:
            return ''

def set_xattr(path, name, value, follow_symlinks, dryrun=False):
    if dryrun:
        return True
    try:
        if follow_symlinks:
            os.setxattr(path, name, value.encode())
            return True
        else:
            raise AttributeError()
    except Exception:
        # fallback to setfattr
        try:
            res = subprocess.run(
                ["setfattr"] + (["-h"] if not follow_symlinks else []) + ["-n", name, "-v", value, path],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return res.returncode == 0
        except Exception:
            return False

def remove_xattr(path, name, follow_symlinks, dryrun=False):
    if dryrun:
        return True
    try:
        if follow_symlinks:
            os.removexattr(path, name)
            return True
        else:
            raise AttributeError()
    except Exception:
        # fallback to setfattr
        try:
            res = subprocess.run(
                ["setfattr"] + (["-h"] if not follow_symlinks else []) + ["-x", name, path],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return res.returncode == 0
        except Exception:
            return False

def main():
    import shlex

    DRYRUN = VERBOSE = QUIET = FOLLOW = REMOVE = REPLACE_ALL = False
    ADD_NAMES = []
    REMOVE_NAMES = []
    files = []

    # begin refactor as function ParseArgs
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-n", "--name"):
            i += 1
            if i >= len(args) or args[i].startswith('-'):
                warn("-n/--name requires an argument")
                continue
            ADD_NAMES += [n.strip() for n in args[i].replace(';', ',').split(',') if n.strip()]
        elif arg == "-x":
            i += 1
            if i >= len(args) or args[i].startswith('-'):
                warn("-x requires at least one name")
                continue
            if REPLACE_ALL:
                warn("-x and -X are mutually exclusive")
                continue
            REMOVE_NAMES += [n.strip() for n in args[i].replace(';', ',').split(',') if n.strip()]
        elif arg == "-X":
            REPLACE_ALL = True
            if REMOVE_NAMES:
                warn("-x and -X are mutually exclusive")
                sys.exit(1)
        elif arg in ("-r", "--remove"):
            REMOVE = True
        elif arg in ("-F", "--follow"):
            FOLLOW = True
        elif arg == "--dry-run":
            DRYRUN = True
        elif arg in ("-v", "--verbose"):
            VERBOSE = True
        elif arg in ("-q", "--quiet"):
            QUIET = True
        elif arg in ("-h", "--help"):
            show_help()
            sys.exit(0)
        elif arg.startswith("-"):
            warn(f"Unknown option: {arg}")
            show_help()
            sys.exit(1)
        else:
            files = args[i:]
            break
        i += 1
    # end refactor as function ParseArgs

    if not files:
        show_help()
        sys.exit(1)

    # begin refactor as function ProcessFiles
    for obj in files:
        if not os.path.exists(obj) and not os.path.islink(obj):
            warn(f"Not found: {obj}")
            continue

        cur_tag = get_xattr(obj, FOLLOW)

        # REMOVE (-r): delete the entire xattr
        if REMOVE:
            if not cur_tag:
                warn(f"{obj}: Not tagged, cannot remove")
                continue
            if DRYRUN:
                log(f"[DRY-RUN] Would remove tag from {obj}", QUIET)
            else:
                if remove_xattr(obj, XATTR_NAME, FOLLOW):
                    log(f"Removed tag from {obj}", QUIET)
                else:
                    warn(f"Failed to remove tag from {obj}")
            continue

        # If not tagged and trying to -x or -X, warn and continue
        if not cur_tag and (REMOVE_NAMES or REPLACE_ALL):
            warn(f"{obj}: Not tagged, cannot remove name(s)")
            continue

        # If not tagged and adding, create a new tag
        if not cur_tag:
            new_uuid = str(uuid.uuid4())
            if ADD_NAMES:
                new_names = ";".join(ADD_NAMES)
                tag = f"ts/{new_uuid}/{new_names}"
            else:
                tag = f"ts/{new_uuid}"
            if len(tag) > 250:
                warn(f"Tag too long for {obj}, skipping")
                continue
            if DRYRUN:
                log(f"[DRY-RUN] Would tag {obj} as {tag}", QUIET)
            else:
                if set_xattr(obj, XATTR_NAME, tag, FOLLOW):
                    log(f"Tagged {obj} as {tag}", QUIET)
                else:
                    warn(f"Failed to tag {obj}")
            continue

        # Parse current tag: always starts with ts/uuid, optionally /name1;name2...
        try:
            parts = cur_tag.split('/', 2)
            uuid_part = parts[1]
            names_part = parts[2] if len(parts) > 2 else ''
            cur_names = [n for n in names_part.split(';') if n]
        except Exception:
            warn(f"{obj}: Invalid tag format, skipping")
            continue

        # REMOVE NAMES (-x)
        if REMOVE_NAMES:
            new_names = [name for name in cur_names if name and name not in REMOVE_NAMES]
            if new_names:
                tag = f"ts/{uuid_part}/" + ";".join(new_names)
            else:
                tag = f"ts/{uuid_part}"
            if DRY
    # end refactor as function ProcessFiles
