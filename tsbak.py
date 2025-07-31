#!/usr/bin/env python3

import sys
from tagsync.core import TagSync

def show_help():
    print(f"""TagSync: tsbak.py
Usage: {sys.argv[0]} [-n name[,name2...]] <src1> [src2 ...] <dest1> [-n name[,name2...]] <src3> ... <dest2> ...
  -n, --name NAMES    Only backup files/dirs tagged with these names (comma or semicolon separated). May repeat for groups.
  -F, --follow        Follow symlinks (not recommended).
  --dry-run           Show what would be done, but don't actually copy.
  -v, --verbose       Extra output.
  -q, --quiet         Only warnings/errors.
  -h, --help          Show help.
""")

def parse_args(argv):
    DRYRUN = VERBOSE = QUIET = FOLLOW = False
    groups = []
    cur_names = []
    cur_srcs = []

    args = argv[1:]
    while args:
        arg = args.pop(0)
        if arg in ("-n", "--name"):
            if not args or args[0].startswith("-"):
                print("-n requires at least one name", file=sys.stderr)
                sys.exit(1)
            if len(cur_srcs) > 1:
                print("Must specify only one destination per group", file=sys.stderr)
                sys.exit(1)
            if cur_srcs:
                groups.append((cur_names[:], cur_srcs[:]))
                cur_srcs.clear()
            names = [n.strip() for n in args.pop(0).replace(';', ',').split(',') if n.strip()]
            cur_names = names
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
            cur_srcs.append(arg)
    if cur_srcs:
        groups.append((cur_names[:], cur_srcs[:]))
    return groups, DRYRUN, VERBOSE, QUIET, FOLLOW

def validate_input(paths):
    if len(paths) < 2:
        print("Need at least one source and a destination in each group.", file=sys.stderr)
        return None, None
    dest = paths[-1]
    src_list = paths[:-1]
    if not os.path.isdir(dest):
        print(f"Destination {dest} is not a directory or not found. Skipping group.", file=sys.stderr)
        return None, None
    return src_list, dest

def main():
    groups, DRYRUN, VERBOSE, QUIET, FOLLOW = parse_args(sys.argv)
    tagsync = TagSync(dry_run=DRYRUN, verbose=VERBOSE, quiet=QUIET, follow=FOLLOW)
    for names, paths in groups:
        src_list, dest = validate_input(paths)
        if not src_list:
            continue
        tagsync.backup(src_list, dest, names)

if __name__ == "__main__":
    main()
