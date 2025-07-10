#!/usr/bin/env bash

# v0.1.2
# List only TAGGED files by default.
# With -V/--verbose, show all files; tagged ones in magenta.

XATTR_NAME="user.backup_id"
VERBOSE=0

show_help() {
  cat <<EOF
TagSync: tsls.sh v0.1.2
Usage: $0 [OPTIONS] [DIR ...]
  -V, --verbose   Show all files; highlight tagged files in magenta.
  -h, --help      Show this help.
  [DIR ...]       Directory/directories to list (default: .)
EOF
}

DIRS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -V|--verbose) VERBOSE=1 ;;
    *) DIRS+=("$1") ;;
  esac
  shift
done

if [[ ${#DIRS[@]} -eq 0 ]]; then DIRS=("."); fi

for DIR in "${DIRS[@]}"; do
  # List all files/dirs, one per line, skipping . and ..
  mapfile -t FILES < <(ls -A1 "$DIR")
  for FILE in "${FILES[@]}"; do
    FULL="$DIR/$FILE"
    if getfattr --only-values -n "$XATTR_NAME" "$FULL" &>/dev/null; then
      # Tagged file
      if (( VERBOSE )); then
        echo -e "\033[35m$FILE\033[0m"
      else
        echo "$FILE"
      fi
    else
      # Not tagged
      if (( VERBOSE )); then
        echo "$FILE"
      fi
    fi
  done
done
