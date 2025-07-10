#!/bin/bash

XATTR_NAME="user.backup_id"
FOLLOW=0
VERBOSE=0
QUIET=0

show_help() {
  cat <<EOF
Usage: $0 <file|dir> [file|dir] ... [--help] [-F|--follow] [-v|--verbose] [-q|--quiet]
  <file|dir>      Files, directories, or symlinks to query for backup ID.
  [--help]        Show this help message.
  -F, --follow    Query the target of a symlink.
                  (Default: never follow symlinks, operate on the symlink itself.)
  -v, --verbose   Show extra details about what is happening.
  -q, --quiet     Only print warnings or errors.
EOF
}

# Print usage if no arguments given
if [[ $# -eq 0 ]]; then
  show_help
  exit 1
fi

NEWARGS=()
for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help; exit 0 ;;
    -F|--follow) FOLLOW=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet) QUIET=1 ;;
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

log()   { (( QUIET )) || echo "$@"; }
vlog()  { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }
warn()  { echo "$@" >&2; }

for OBJ in "$@"; do
  if [[ ! -e "$OBJ" && ! -L "$OBJ" ]]; then
    warn "WARNING: File, directory, or symlink not found: $OBJ"
    continue
  fi
  ID=$(getfattr $FATTR_FLAG --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)
  if [[ -n "$ID" ]]; then
    log "$OBJ: $ID"
  else
    vlog "$OBJ: [not set]"
  fi
done
