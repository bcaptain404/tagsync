#!/bin/bash

XATTR_NAME="user.backup_id"
DRYRUN=0
FOLLOW=0
VERBOSE=0
QUIET=0

show_help() {
  cat <<EOF
Usage: $0 <file|dir> [unset] [--dry-run] [--help] [-F|--follow] [-v|--verbose] [-q|--quiet]
  <file|dir>      File, directory, or symlink to operate on.
  [unset]         Remove backup ID from object instead of setting it.
  [--dry-run]     Show what would be done, but don't change anything.
  [--help]        Show this help message.
  -F, --follow    Operate on the target of a symlink.
                  (Default: never follow symlinks, operate on the symlink itself.)
  -v, --verbose   Show extra details about what is happening.
  -q, --quiet     Only print warnings or errors.
EOF
}

# Parse options and clean arg list
NEWARGS=()
for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help; exit 0 ;;
    --dry-run) DRYRUN=1 ;;
    -F|--follow) FOLLOW=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet) QUIET=1 ;;
    *) NEWARGS+=("$arg") ;;
  esac
done

set -- "${NEWARGS[@]}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  show_help
  exit 1
fi

OBJ="$1"
FATTR_FLAG=""
if (( FOLLOW )); then
  FATTR_FLAG="-h"
fi

log()   { (( QUIET )) || echo "$@"; }
vlog()  { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }
warn()  { echo "$@" >&2; }

if [[ ! -e "$OBJ" && ! -L "$OBJ" ]]; then
  warn "WARNING: File, directory, or symlink not found: $OBJ"
else
  if [[ $# -eq 2 ]]; then
    if [[ "$2" != "unset" ]]; then
      warn "Unknown argument: $2"
      show_help
      exit 1
    fi
    if (( DRYRUN )); then
      log "[DRY-RUN] Would unset $XATTR_NAME from $OBJ"
    else
      if setfattr $FATTR_FLAG -x "$XATTR_NAME" "$OBJ"; then
        vlog "Unset $XATTR_NAME from $OBJ"
      else
        warn "WARNING: Failed to unset $XATTR_NAME from $OBJ"
      fi
    fi
  else
    ID=$(uuidgen)
    if (( DRYRUN )); then
      log "[DRY-RUN] Would set $XATTR_NAME=$ID on $OBJ"
    else
      if setfattr $FATTR_FLAG -n "$XATTR_NAME" -v "$ID" "$OBJ"; then
        vlog "Set $XATTR_NAME=$ID on $OBJ"
      else
        warn "WARNING: Failed to set $XATTR_NAME on $OBJ"
      fi
    fi
  fi
fi
