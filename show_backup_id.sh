#!/bin/bash

XATTR_NAME="user.backup_id"
FOLLOW=0

show_help() {
  cat <<EOF
Usage: $0 <file|dir> [file|dir] ... [--help] [-F|--follow]
  <file|dir>      Files, directories, or symlinks to query for backup ID.
  [--help]        Show this help message.
  -F, --follow    Query the target of a symlink (default: operate on the link itself).
EOF
}

# Print usage if no arguments given
if [[ $# -eq 0 ]]; then
  show_help
  exit 1
fi

# Parse for --help/-h and --follow/-F, clean arg list
NEWARGS=()
for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help; exit 0 ;;
    -F|--follow) FOLLOW=1 ;;
    -*)
      echo "Unknown argument: $arg"
      show_help
      exit 1
      ;;
    *) NEWARGS+=("$arg") ;;
  esac
done

set -- "${NEWARGS[@]}"

FATTR_FLAG=""
if (( FOLLOW )); then
  FATTR_FLAG="-h"
fi

for OBJ in "$@"; do
  if [[ ! -e "$OBJ" && ! -L "$OBJ" ]]; then
    echo "WARNING: File, directory, or symlink not found: $OBJ" >&2
    continue
  fi
  ID=$(getfattr $FATTR_FLAG --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)
  if [[ -n "$ID" ]]; then
    echo "$OBJ: $ID"
  fi
done
