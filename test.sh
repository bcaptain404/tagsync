#!/usr/bin/env bash

XATTR_NAME="user.backup_id"

for TARGET in "$@"; do
  TAG=$(getfattr --only-values -n "$XATTR_NAME" "$TARGET" 2>/dev/null)
  if [[ -n "$TAG" && "${TAG:0:3}" == "ts/" ]]; then
    echo "$TARGET"
  fi
done
