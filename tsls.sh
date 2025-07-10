#!/usr/bin/env bash

# v0.1.2
# List only TAGGED files by default.
# With -V/--verbose, show all files; tagged ones in magenta.

XATTR_NAME="user.backup_id"
VERBOSE=0

show_help() {
  cat <<EOF
TagSync: tsls.sh v0.1.2
Usage: $0 [OPTIONS] [--] [ls-args...]
  -V, --verbose   Show all files; highlight tagged files in magenta.
  -h, --help      Show this help.
  [ls-args...]    Any other arguments are passed to ls.
EOF
}

LS_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -V|--verbose) VERBOSE=1 ;;
    *) LS_ARGS+=("$1") ;;
  esac
  shift
done

# Run `ls -A1` to get plain filenames for parsing, but for output/formatting, user gets their own flags.
# Need to detect files in each target dir and filter as needed.

# Figure out which arguments are files/dirs, vs formatting flags for ls
LS_PATHS=()
for arg in "${LS_ARGS[@]}"; do
  [[ "$arg" =~ ^- ]] || LS_PATHS+=("$arg")
done
if [[ ${#LS_PATHS[@]} -eq 0 ]]; then
  LS_PATHS=(".")
fi

for DIR in "${LS_PATHS[@]}"; do
  # List files, using formatting flags, but always -A1 to get plain names for filtering
  mapfile -t FILES < <(ls -A1 -- "${DIR}")
  for FILE in "${FILES[@]}"; do
    FULL="$DIR/$FILE"
    if getfattr --only-values -n "$XATTR_NAME" "$FULL" &>/dev/null; then
      if (( VERBOSE )); then
        echo -e "\033[35m$FILE\033[0m"
      else
        echo "$FILE"
      fi
    else
      if (( VERBOSE )); then
        echo "$FILE"
      fi
    fi
  done
done
