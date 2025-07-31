#!/usr/bin/env bash

# v0.2.0 -- TagSync: Backup tagged files/dirs by name and group, to one or more destinations.

XATTR_NAME="user.backup_id"
DRYRUN=0
VERBOSE=0
QUIET=0
FOLLOW=0

show_help() {
  cat <<EOF
TagSync: tsbak.sh v0.2.0
Usage: $0 [-n name[,name2...]] <src1> [src2 ...] <dest1> [-n name[,name2...]] <src3> ... <dest2> ...
  -n, --name NAMES    Only backup files/dirs tagged with these names (comma or semicolon separated). May repeat for groups.
  -F, --follow        Follow symlinks (not recommended).
  --dry-run           Show what would be done, but don't actually copy.
  -v, --verbose       Extra output.
  -q, --quiet         Only warnings/errors.
  -h, --help          Show help.
EOF
}

warn() { echo "$@" >&2; }
log() { (( QUIET )) || echo "$@"; }
vlog() { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }

FATTR_FLAG=""
(( FOLLOW )) && FATTR_FLAG="-h"

GROUPS=()
CUR_NAMES=()
CUR_SRCS=()

# ========== Refactored Functions ==========

ValidateInput() {
  local PATHS=("$@")
  if [[ ${#PATHS[@]} -lt 2 ]]; then
    warn "Need at least one source and a destination in each group."
    return 1
  fi

  DEST="${PATHS[-1]}"
  SRC_LIST=("${PATHS[@]:0:${#PATHS[@]}-1}")

  if [[ ! -d "$DEST" ]]; then
    warn "Destination $DEST is not a directory or not found. Skipping group."
    return 1
  fi

  return 0
}

FindTaggedFiles() {
  local SRC="$1"
  local -n __RESULT=$2
  local -a NAMES_LOCAL=("${NAMES[@]}")
  local ABS_SRC=$(realpath "$SRC")

  mapfile -t __RESULT < <(
    find "$ABS_SRC" \( -type f -o -type d \) ! -type l -print0 |
    xargs -0 -n1 bash -c '
      XATTR_NAME="user.backup_id"
      OBJ="$0"
      TAG=$(getfattr --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)
      if [[ -n "$TAG" && "${TAG:0:3}" == "ts/" ]]; then
        if [[ '"${#NAMES_LOCAL[@]}"' -eq 0 ]]; then
          echo "$OBJ"
        else
          NAMES_PART=$(echo "$TAG" | cut -d"/" -f3-)
          for NAME in "'"${NAMES_LOCAL[*]}"'"; do
            [[ "$NAMES_PART" =~ (^|[;])$NAME([;]|$) ]] && echo "$OBJ" && break
          done
        fi
      fi
    '
  )
}

BackupObjectList() {
  local OBJ
  for OBJ in "${OBJS[@]}"; do
    if [[ -d "$OBJ" && ! -L "$OBJ" ]]; then
      if (( DRYRUN )); then
        log "[DRY-RUN] Would rsync -iauHAX --no-links --relative '$OBJ' '$ABS_DEST/'"
      else
        if ! rsync -iauHAX --no-links --relative "$OBJ" "$ABS_DEST/"; then
          warn "rsync failed for $OBJ"
        else
          log "Backed up directory: $OBJ"
        fi
      fi
    else
      REL_PATH="${OBJ#$ABS_SRC/}"
      DEST_PATH="$ABS_DEST/$REL_PATH"
      if (( DRYRUN )); then
        log "[DRY-RUN] Would mkdir -p '$(dirname "$DEST_PATH")'"
        log "[DRY-RUN] Would rsync -iauHAX --no-links --relative '$OBJ' '$ABS_DEST/'"
      else
        mkdir -p "$(dirname "$DEST_PATH")" || warn "Failed to create directory for $DEST_PATH"
        if ! rsync -iauHAX --no-links --relative "$OBJ" "$ABS_DEST/"; then
          warn "rsync failed for $OBJ"
        else
          log "Backed up file: $OBJ"
        fi
      fi
    fi
  done
}

# ========== Argument Parsing ==========

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      shift
      [[ -z "$1" || "$1" =~ ^- ]] && { warn "-n requires at least one name"; exit 1; }
      [[ ${#CUR_SRCS[@]} -gt 1 ]] && { warn "Must specify only one destination per group"; exit 1; }
      [[ ${#CUR_SRCS[@]} -gt 0 ]] && GROUPS+=("${CUR_NAMES[*]}:::${CUR_SRCS[*]}")
      IFS=',;' read -ra CUR_NAMES <<< "$1"
      CUR_SRCS=()
      ;;
    -F|--follow)
      FOLLOW=1
      FATTR_FLAG="-h"
      ;;
    --dry-run)
      DRYRUN=1
      ;;
    -v|--verbose)
      VERBOSE=1
      ;;
    -q|--quiet)
      QUIET=1
      ;;
    -h|--help)
      show_help; exit 0
      ;;
    -*)
      warn "Unknown flag: $1"; show_help; exit 1
      ;;
    *)
      CUR_SRCS+=("$1")
      ;;
  esac
  shift
done

[[ ${#CUR_SRCS[@]} -gt 0 ]] && GROUPS+=("${CUR_NAMES[*]}:::${CUR_SRCS[*]}")

# ========== Group Processing ==========

for GROUP in "${GROUPS[@]}"; do
  IFS=' ' read -ra NAMES <<< "${GROUP%%:::*}"
  IFS=' ' read -ra PATHS <<< "${GROUP#*:::}"

  ValidateInput "${PATHS[@]}" || exit 1
done

for GROUP in "${GROUPS[@]}"; do
  IFS=' ' read -ra NAMES <<< "${GROUP%%:::*}"
  IFS=' ' read -ra PATHS <<< "${GROUP#*:::}"

  ABS_DEST=$(realpath "$DEST")

  for SRC in "${SRC_LIST[@]}"; do
    if [[ ! -d "$SRC" ]]; then
      warn "Source $SRC is not a directory or not found. Skipping."
      continue
    fi

    ABS_SRC=$(realpath "$SRC")

    FindTaggedFiles "$SRC" OBJS
    BackupObjectList
  done
done
