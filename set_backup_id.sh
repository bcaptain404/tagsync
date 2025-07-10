#!/bin/bash

XATTR_NAME="user.backup_id"
DRYRUN=0
FOLLOW=0

show_help() {
  cat <<EOF
Usage: $0 <file|dir> [unset] [--dry-run] [--help] [-F|--follow]
  <file|dir>      File, directory, or symlink to operate on.
  [unset]         Remove backup ID from object instead of setting it.
  [--dry-run]     Show what would be done, but don't change anything.
  [--help]        Show this help message.
  -F, --follow    Operate on the target of a symlink (default: operate on the link itself).
EOF
}

# Parse for --help/-h first
for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

# Parse --dry-run and --follow/-F, clean arg list
NEWARGS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRYRUN=1 ;;
    -F|--follow) FOLLOW=1 ;;
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

if [[ ! -e "$OBJ" && ! -L "$OBJ" ]]; then
  echo "WARNING: File, directory, or symlink not found: $OBJ" >&2
else
  if [[ $# -eq 2 ]]; then
    if [[ "$2" != "unset" ]]; then
      echo "Unknown argument: $2" >&2
      show_help
      exit 1
    fi
    if (( DRYRUN )); then
      echo "[DRY-RUN] Would unset $XATTR_NAME from $OBJ"
    else
      if setfattr $FATTR_FLAG -x "$XATTR_NAME" "$OBJ"; then
        echo "Unset $XATTR_NAME from $OBJ"
      else
        echo "WARNING: Failed to unset $XATTR_NAME from $OBJ" >&2
      fi
    fi
  else
    ID=$(uuidgen)
    if (( DRYRUN )); then
      echo "[DRY-RUN] Would set $XATTR_NAME=$ID on $OBJ"
    else
      if setfattr $FATTR_FLAG -n "$XATTR_NAME" -v "$ID" "$OBJ"; then
        echo "Set $XATTR_NAME=$ID on $OBJ"
      else
        echo "WARNING: Failed to set $XATTR_NAME on $OBJ" >&2
      fi
    fi
  fi
fi
