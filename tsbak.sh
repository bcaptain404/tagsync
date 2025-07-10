#!/usr/bin/env bash

# v0.1.2

XATTR_NAME="user.backup_id"
DRYRUN=0
VERBOSE=0
QUIET=0

show_help() {
  cat <<EOF
TagSync: $0 v0.1.2
Usage: $0 [OPTIONS] <src1> [<src2> ...] <dest>
  -F, --follow     (Reserved for future) -- currently, symlinks are never followed or backed up.
  --dry-run        Show what would be done, but don't copy anything.
  -v, --verbose    Show extra details about each operation.
  -q, --quiet      Only print warnings or errors.
  -h, --help       Show this help message.
  <src1> [src2 ...]  One or more source directories to back up from.
  <dest>             Destination directory to back up to.

  Symlinks are never followed or backed up, and will be skipped.
EOF
}

PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    --dry-run) DRYRUN=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet) QUIET=1 ;;
    -F|--follow) ;; # Reserved, no-op for now
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

if [[ ${#PATHS[@]} -lt 2 ]]; then
  show_help
  exit 1
fi

DEST="${PATHS[-1]}"
SRC_LIST=("${PATHS[@]:0:${#PATHS[@]}-1}")

log()   { (( QUIET )) || echo "$@"; }
vlog()  { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }
warn()  { echo "$@" >&2; }

if [[ ! -d "$DEST" ]]; then
  warn "WARNING: Destination directory not found: $DEST"
  exit 1
fi

for SRC in "${SRC_LIST[@]}"; do
  if [[ ! -d "$SRC" ]]; then
    warn "WARNING: Source directory not found: $SRC"
    continue
  fi

  ABS_SRC=$(realpath "$SRC")
  ABS_DEST=$(realpath "$DEST")

  find "$ABS_SRC" \( -type f -o -type d \) ! -type l \
    ! -path "$ABS_DEST" ! -path "$ABS_DEST/*" -print0 | while IFS= read -r -d '' OBJ; do
      if [[ ! -e "$OBJ" ]]; then
        warn "WARNING: File or directory not found: $OBJ"
        continue
      fi
      if getfattr --only-values -n "$XATTR_NAME" "$OBJ" &>/dev/null; then
        if [[ -d "$OBJ" ]]; then
          if (( DRYRUN )); then
            log "[DRY-RUN] Would run: rsync -iauHAXP --no-links --relative \"$OBJ\" \"$ABS_DEST/\""
          else
            if ! rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"; then
              warn "WARNING: rsync failed for $OBJ"
            else
              vlog "Backed up directory: $OBJ"
            fi
          fi
        else
          REL_PATH="${OBJ#$ABS_SRC/}"
          DEST_PATH="$ABS_DEST/$REL_PATH"
          if (( DRYRUN )); then
            log "[DRY-RUN] Would run: mkdir -p \"$(dirname "$DEST_PATH")\""
            log "[DRY-RUN] Would run: rsync -iauHAXP --no-links --relative \"$OBJ\" \"$ABS_DEST/\""
          else
            if ! mkdir -p "$(dirname "$DEST_PATH")"; then
              warn "WARNING: Failed to create directory $(dirname "$DEST_PATH")"
            fi
            if ! rsync -iauHAXP --no-links --relative "$OBJ" "$ABS_DEST/"; then
              warn "WARNING: rsync failed for $OBJ"
            else
              vlog "Backed up file: $OBJ"
            fi
          fi
        fi
      else
        vlog "Skipped (not flagged): $OBJ"
      fi
    done
done
