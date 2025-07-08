#!/bin/bash

# Usage: ./set_backup_id.sh <file|dir> [unset]
# If "unset" is given as the second arg, removes the xattr instead of setting.

XATTR_NAME="user.backup_id"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <file|dir> [unset]"
  exit 1
fi

OBJ="$1"

if [[ "$2" == "unset" ]]; then
  setfattr -x "$XATTR_NAME" "$OBJ" && echo "Unset $XATTR_NAME from $OBJ"
else
  ID=$(uuidgen)
  setfattr -n "$XATTR_NAME" -v "$ID" "$OBJ" && echo "Set $XATTR_NAME=$ID on $OBJ"
fi
