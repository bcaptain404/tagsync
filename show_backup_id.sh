#!/bin/bash

# Usage: ./show_backup_id.sh <file|dir> [file|dir] ...

XATTR_NAME="user.backup_id"

for OBJ in "$@"; do
  ID=$(getfattr --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)
  if [[ -n "$ID" ]]; then
    echo "$OBJ: $ID"
  fi
done
