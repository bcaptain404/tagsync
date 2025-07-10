#!/bin/bash

# Usage: ./backup.sh <src> <dest> [--dry-run]

XATTR_NAME="user.backup_id"
DRYRUN=0

NEWARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRYRUN=1
  else
    NEWARGS+=("$arg")
  fi
done

set -- "${NEWARGS[@]}"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <src> <dest> [--dry-run]"
  exit 1
fi

SRC="$1"
DEST="$2"

ABS_SRC=$(realpath "$SRC")
ABS_DEST=$(realpath "$DEST")

find "$ABS_SRC" \( -type f -o -type d \) ! -type l \
  ! -path "$ABS_DEST" ! -path "$ABS_DEST/*" -print0 | while IFS= read -r -d '' OBJ; do
    if getfattr --only-values -n "$XATTR_NAME" "$OBJ" &>/dev/null; then
      if [[ -d "$OBJ" ]]; then
        if (( DRYRUN )); then
          echo "[DRY-RUN] Would run: rsync -iauHAXP --no-links --relative \"$OBJ\" \"$ABS_DEST/\""
        else
          rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"
        fi
      else
        REL_PATH="${OBJ#$ABS_SRC/}"
        DEST_PATH="$ABS_DEST/$REL_PATH"
        if (( DRYRUN )); then
          echo "[DRY-RUN] Would run: mkdir -p \"$(dirname "$DEST_PATH")\""
          echo "[DRY-RUN] Would run: rsync -iauHAXP --no-links --relative \"$OBJ\" \"$ABS_DEST/\""
        else
          mkdir -p "$(dirname "$DEST_PATH")"
          rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"
        fi
      fi
    fi
done
