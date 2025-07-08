#!/bin/bash

# Usage: ./backup.sh <src> <dest>
# Copies all objects flagged with user.backup_id to <dest>, preserving full hierarchy from <src> root.
SRC="$1"
DEST="$2"
XATTR_NAME="user.backup_id"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <src> <dest>"
  exit 1
fi

ABS_SRC=$(realpath "$SRC")
ABS_DEST=$(realpath "$DEST")

# Exclude the destination dir and any symlinks from scan/copy
find "$ABS_SRC" \( -type f -o -type d \) ! -type l \
  ! -path "$ABS_DEST" ! -path "$ABS_DEST/*" -print0 | while IFS= read -r -d '' OBJ; do
    if getfattr --only-values -n "$XATTR_NAME" "$OBJ" &>/dev/null; then
      if [[ -d "$OBJ" ]]; then
        rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"
      else
        REL_PATH="${OBJ#$ABS_SRC/}"
        DEST_PATH="$ABS_DEST/$REL_PATH"
        mkdir -p "$(dirname "$DEST_PATH")"
        rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"
      fi
    fi
done
