#!/bin/bash

# Usage: ./set_backup_id.sh <file|dir> [unset] [--dry-run]

XATTR_NAME="user.backup_id"
DRYRUN=0

# Collect new argument list without --dry-run
NEWARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRYRUN=1
  else
    NEWARGS+=("$arg")
  fi
done

set -- "${NEWARGS[@]}"

# Allow only 1 or 2 args (file [unset]), no blanks
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <file|dir> [unset] [--dry-run]"
  exit 1
fi

OBJ="$1"

if [[ $# -eq 2 ]]; then
  if [[ "$2" != "unset" ]]; then
    echo "Unknown argument: $2"
    echo "Usage: $0 <file|dir> [unset] [--dry-run]"
    exit 1
  fi
  if (( DRYRUN )); then
    echo "[DRY-RUN] Would unset $XATTR_NAME from $OBJ"
  else
    setfattr -x "$XATTR_NAME" "$OBJ" && echo "Unset $XATTR_NAME from $OBJ"
  fi
else
  ID=$(uuidgen)
  if (( DRYRUN )); then
    echo "[DRY-RUN] Would set $XATTR_NAME=$ID on $OBJ"
  else
    setfattr -n "$XATTR_NAME" -v "$ID" "$OBJ" && echo "Set $XATTR_NAME=$ID on $OBJ"
  fi
fi
