#!/bin/bash

XATTR_NAME="user.backup_id"
DRYRUN=0

show_help() {
  cat <<EOF
Usage: $0 <src> <dest> [--dry-run] [--help]
  <src>         Source directory to back up from.
  <dest>        Destination directory to back up to.
  [--dry-run]   Show what would be done, but don't copy anything.
  [--help]      Show this help message.
EOF
}

# --help takes precedence over everything
for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

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
  show_help
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
          if ! rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"; then
            echo "WARNING: rsync failed for $OBJ" >&2
          fi
        fi
      else
        REL_PATH="${OBJ#$ABS_SRC/}"
        DEST_PATH="$ABS_DEST/$REL_PATH"
        if (( DRYRUN )); then
          echo "[DRY-RUN] Would run: mkdir -p \"$(dirname "$DEST_PATH")\""
          echo "[DRY-RUN] Would run: rsync -iauHAXP --no-links --relative \"$OBJ\" \"$ABS_DEST/\""
        else
          if ! mkdir -p "$(dirname "$DEST_PATH")"; then
            echo "WARNING: Failed to create directory $(dirname "$DEST_PATH")" >&2
          fi
          if ! rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"; then
            echo "WARNING: rsync failed for $OBJ" >&2
          fi
        fi
      fi
    fi
done
