#!/usr/bin/env python3.12

import sys
import os
import subprocess

XATTR_NAME = "user.backup_id"

def show_help():
    print(f"""TagSync: tsbak.py
Usage:
  {sys.argv[0]} --from SRC [--from SRC2 ...] --to DEST [options]
Options:
  -n, --name NAMES    Only backup files/dirs tagged with these names (comma or semicolon separated).
  -F, --follow        Follow symlinks (not recommended).
  --dry-run           Show what would be done, but don't actually copy.
  -v, --verbose       Extra output.
  -q, --quiet         Only warnings/errors.
  -h, --help          Show help.
Examples:
  {sys.argv[0]} --from mydir --from mydir2 --to /mnt/backup -n foo,bar --dry-run
""")

def log(msg, quiet):
    if not quiet:
        print(msg)

def vlog(msg, verbose, quiet):
    if verbose and not quiet:
        print(msg)

def warn(msg):
    print(msg, file=sys.stderr)

def get_xattr(path):
    try:
        val = os.getxattr(path, XATTR_NAME)
        return val.decode() if isinstance(val, bytes) else val
    except (OSError, AttributeError):
        try:
            res = subprocess.run(
                ["getfattr", "--only-values", "-n", XATTR_NAME, path],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
            )
            return res.stdout.strip() if res.returncode == 0 else ''
        except Exception:
            return ''

def find_tagged_files(src, names=None, follow=False):
    tagged = []
    abs_src = os.path.abspath(src)
    for dirpath, dirnames, filenames in os.walk(abs_src, followlinks=follow):
        for fname in filenames + dirnames:
            fullpath = os.path.join(dirpath, fname)
            if os.path.islink(fullpath):
                continue
            tag = get_xattr(fullpath)
            if tag and tag.startswith('ts/'):
                if not names:
                    tagged.append(fullpath)
                else:
                    tag_names = tag.split('/', 2)[-1].split(';') if '/' in tag[3:] else []
                    for name in names:
                        if name in tag_names:
                            tagged.append(fullpath)
                            break
    return tagged

def backup_object(obj, abs_src, abs_dest, dry_run, verbose, quiet):
    if os.path.isdir(obj) and not os.path.islink(obj):
        if dry_run:
            log(f"[DRY-RUN] Would rsync -iauHAX --no-links --relative '{obj}' '{abs_dest}/'", quiet)
        else:
            result = subprocess.run([
                "rsync", "-iauHAX", "--no-links", "--relative", obj, abs_dest + "/"
            ])
            if result.returncode != 0:
                warn(f"rsync failed for {obj}")
            else:
                log(f"Backed up directory: {obj}", quiet)
    else:
        rel_path = os.path.relpath(obj, abs_src)
        dest_path = os.path.join(abs_dest, rel_path)
        if dry_run:
            log(f"[DRY-RUN] Would mkdir -p '{os.path.dirname(dest_path)}'", quiet)
            log(f"[DRY-RUN] Would rsync -iauHAX --no-links --relative '{obj}' '{abs_dest}/'", quiet)
        else:
            try:
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            except Exception:
                warn(f"Failed to create directory for {dest_path}")
            result = subprocess.run([
                "rsync", "-iauHAX", "--no-links", "--relative", obj, abs_dest + "/"
            ])
            if result.returncode != 0:
                warn(f"rsync failed for {obj}")
            else:
                log(f"Backed up file: {obj}", quiet)

def backup(src_list, dest, names=None, dry_run=False, verbose=False, quiet=False, follow=False):
    abs_dest = os.path.abspath(dest)
    for src in src_list:
        if not os.path.isdir(src):
            warn(f"Source {src} is not a directory or not found. Skipping.")
            continue
        abs_src = os.path.abspath(src)
        objs = find_tagged_files(src, names, follow)
        for obj in objs:
            backup_object(obj, abs_src, abs_dest, dry_run, verbose, quiet)

def parse_args(argv):
    DRYRUN = VERBOSE = QUIET = FOLLOW = False
    names = []
    from_srcs = []
    to_dest = None

    args = argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--from":
            i += 1
            if i >= len(args):
                print("--from requires an argument", file=sys.stderr)
                sys.exit(1)
            from_srcs.append(args[i])
        elif arg == "--to":
            i += 1
            if i >= len(args):
                print("--to requires an argument", file=sys.stderr)
                sys.exit(1)
            if to_dest is not None:
                print("Only one --to destination may be supplied.", file=sys.stderr)
                sys.exit(1)
            to_dest = args[i]
        elif arg in ("-n", "--name"):
            i += 1
            if i >= len(args):
                print("-n/--name requires at least one name", file=sys.stderr)
                sys.exit(1)
            names = [n.strip() for n in args[i].replace(';', ',').split(',') if n.strip()]
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
        elif arg.startswith('-'):
            print(f"Unknown flag: {arg}", file=sys.stderr)
            show_help()
            sys.exit(1)
        else:
            print(f"Unknown or misplaced argument: {arg}", file=sys.stderr)
            show_help()
            sys.exit(1)
        i += 1

    if not from_srcs:
        print("At least one --from SRC must be supplied.", file=sys.stderr)
        show_help()
        sys.exit(1)
    if not to_dest:
        print("Exactly one --to DEST must be supplied.", file=sys.stderr)
        show_help()
        sys.exit(1)

    return from_srcs, to_dest, names, DRYRUN, VERBOSE, QUIET, FOLLOW

def main():
    from_srcs, to_dest, names, DRYRUN, VERBOSE, QUIET, FOLLOW = parse_args(sys.argv)
    backup(from_srcs, to_dest, names, DRYRUN, VERBOSE, QUIET, FOLLOW)

if __name__ == "__main__":
    main()
