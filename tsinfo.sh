#!/usr/bin/env bash

# v0.1.2

XATTR_NAME="user.backup_id"
FOLLOW=0
VERBOSE=0
QUIET=0

show_help() {
  cat <<EOF
TagSync: $0 v0.1.2
Usage: $0 [OPTIONS] <file|dir|symlink> [<file|dir|symlink>...]
  -F, --follow     Query the target of symlinks.
                   (Default: operate on the symlink itself.)
  -v, --verbose    Show extra details about what is happening.
  -q, --quiet      Only print warnings or errors.
  -h, --help       Show this help message.
  <file|dir|symlink>  One or more objects to query for backup ID.
EOF
}

PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -F|--follow) FOLLOW=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet) QUIET=1 ;;
    --) shift; break ;;
    -*)
      echo "Unknown argument: $1" >&2
      show_help; exit 1
      ;;
    *)
      PATHS+=("$1")
      ;;
  esac
  shift
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
  show_help
  exit 1
fi

FATTR_FLAG=""
if (( FOLLOW )); then
  FATTR_FLAG="-h"
fi

log()   { (( QUIET )) || echo "$@"; }
vlog()  { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }
warn()  { echo "$@" >&2; }

for OBJ in "${PATHS[@]}"; do
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
