#!/bin/bash

XATTR_NAME="user.backup_id"
DRYRUN=0
VERBOSE=0
QUIET=0

show_help() {
  cat <<EOF
Usage: $0 <src> <dest> [--dry-run] [--help] [-v|--verbose] [-q|--quiet]
  <src>         Source directory to back up from.
  <dest>        Destination directory to back up to.
  [--dry-run]   Show what would be done, but don't copy anything.
  [--help]      Show this help message.
  -v, --verbose Show extra details about each operation.
  -q, --quiet   Only print warnings or errors.

  Symlinks are never followed or backed up, and will be skipped.
EOF
}

# --help takes precedence over everything
NEWARGS=()
for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help; exit 0 ;;
    --dry-run) DRYRUN=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet) QUIET=1 ;;
    *) NEWARGS+=("$arg") ;;
  esac
done

set -- "${NEWARGS[@]}"

if [[ $# -ne 2 ]]; then
  show_help
  exit 1
fi

SRC="$1"
DEST="$2"

log()   { (( QUIET )) || echo "$@"; }
vlog()  { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }
warn()  { echo "$@" >&2; }

if [[ ! -d "$SRC" ]]; then
  warn "WARNING: Source directory not found: $SRC"
  exit 0
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
