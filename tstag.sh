#!/usr/bin/env bash

# v0.1.2

XATTR_NAME="user.backup_id"
DRYRUN=0
FOLLOW=0
VERBOSE=0
QUIET=0
UNSET=0

show_help() {
  cat <<EOF
TagSync: $0 v0.1.2
Usage: $0 [OPTIONS] <file|dir|symlink> [<file|dir|symlink>...]
  -u, --unset      Remove backup ID from each object (instead of setting)
  -F, --follow     Operate on the target of symlinks.
                   (Default: operate on the symlink itself.)
  --dry-run        Show what would be done, but don't change anything.
  -v, --verbose    Show extra details about what is happening.
  -q, --quiet      Only print warnings or errors.
  -h, --help       Show this help message.
  <file|dir|symlink>  One or more objects to operate on.
EOF
}

PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    --dry-run) DRYRUN=1 ;;
    -F|--follow) FOLLOW=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet) QUIET=1 ;;
    -u|--unset) UNSET=1 ;;
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

  if (( UNSET )); then
    if (( DRYRUN )); then
      log "[DRY-RUN] Would unset $XATTR_NAME from $OBJ"
    else
      if setfattr $FATTR_FLAG -x "$XATTR_NAME" "$OBJ"; then
        log "Untagged $OBJ"
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
        log "Tagged $OBJ"
        vlog "Set $XATTR_NAME=$ID on $OBJ"
      else
        warn "WARNING: Failed to set $XATTR_NAME on $OBJ"
      fi
    fi
  fi
done
