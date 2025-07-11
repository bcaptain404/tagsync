#!/usr/bin/env bash

# v0.2.0 -- TagSync: Tag files with ts/uuid/name1;name2...
XATTR_NAME="user.backup_id"
DRYRUN=0
VERBOSE=0
QUIET=0
FOLLOW=0
REMOVE=0
REPLACE_ALL=0
REMOVE_NAMES=()
ADD_NAMES=()

show_help() {
  cat <<EOF
TagSync: tstag.sh v0.2.0
Usage: $0 [options] [-n name[,name2...]]... [-x name[,name2...]]... [-X] [-r] <file> [<file> ...]
  -n, --name NAMES    Add one or more names to tag (comma or semicolon separated, may repeat).
  -x NAMES            Remove one or more names from tag (comma or semicolon separated, must provide at least one name).
  -X                  Remove all names (keep UUID).
  -r, --remove        Remove tag entirely.
  -F, --follow        Follow symlinks.
  --dry-run           Only show what would be done.
  -v, --verbose       Extra output.
  -q, --quiet         Only warnings/errors.
  -h, --help          Show help.

Examples:
  $0 -n foo,bar file.txt          # Tag file.txt as ts/uuid/foo;bar
  $0 -x foo file.txt              # Remove only 'foo' from tag names
  $0 -X file.txt                  # Remove all names (keep UUID)
  $0 -r file.txt                  # Remove the tag entirely

Notes:
- Names must be specified before files.
- If -x is used without any names, warns and skips.
- -X and -x are mutually exclusive.
- -r takes precedence: removes the tag regardless of other options.
EOF
}

warn() { echo "$@" >&2; }
log() { (( QUIET )) || echo "$@"; }
vlog() { (( VERBOSE )) && (( ! QUIET )) && echo "$@"; }

FATTR_FLAG=""
(( FOLLOW )) && FATTR_FLAG="-h"

STATE="OPTS"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        warn "-n/--name requires an argument"
        continue
      fi
      IFS=',;' read -ra NMS <<< "$1"
      ADD_NAMES+=("${NMS[@]}")
      shift
      ;;
    -x)
      shift
      if [[ -z "$1" || "$1" =~ ^- ]]; then
        warn "-x requires at least one name"
        continue
      fi
      if [[ $REPLACE_ALL -eq 1 ]]; then
        warn "-x and -X are mutually exclusive"
        continue
      fi
      IFS=',;' read -ra RNS <<< "$1"
      REMOVE_NAMES+=("${RNS[@]}")
      shift
      ;;
    -X)
      REPLACE_ALL=1
      if [[ ${#REMOVE_NAMES[@]} -gt 0 ]]; then
        warn "-x and -X are mutually exclusive"
        exit 1
      fi
      shift
      ;;
    -r|--remove)
      REMOVE=1
      shift
      ;;
    -F|--follow)
      FOLLOW=1
      FATTR_FLAG="-h"
      shift
      ;;
    --dry-run)
      DRYRUN=1
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -q|--quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      warn "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      # First non-flag is a file; break to collect all files
      break
      ;;
  esac
done

FILES=("$@")


FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
  show_help; exit 1
fi

for OBJ in "${FILES[@]}"; do
  if [[ ! -e "$OBJ" && ! -L "$OBJ" ]]; then
    warn "Not found: $OBJ"
    continue
  fi

  CUR_TAG=$(getfattr $FATTR_FLAG --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)

  # REMOVE (-r): delete the entire xattr
  if (( REMOVE )); then
    if [[ -z "$CUR_TAG" ]]; then
      warn "$OBJ: Not tagged, cannot remove"
      continue
    fi
    if (( DRYRUN )); then
      log "[DRY-RUN] Would remove tag from $OBJ"
    else
      if setfattr $FATTR_FLAG -x "$XATTR_NAME" "$OBJ"; then
        log "Removed tag from $OBJ"
      else
        warn "Failed to remove tag from $OBJ"
      fi
    fi
    continue
  fi

  # If not tagged and trying to -x or -X, warn and continue
  if [[ -z "$CUR_TAG" && ( ${#REMOVE_NAMES[@]} -gt 0 || $REPLACE_ALL -eq 1 ) ]]; then
    warn "$OBJ: Not tagged, cannot remove name(s)"
    continue
  fi

  # If not tagged and adding, create a new tag
  if [[ -z "$CUR_TAG" ]]; then
    UUID=$(uuidgen)
    NEW_NAMES=""
    if [[ ${#ADD_NAMES[@]} -gt 0 ]]; then
      NEW_NAMES=$(IFS=';'; echo "${ADD_NAMES[*]}")
      TAG="ts/$UUID/$NEW_NAMES"
    else
      TAG="ts/$UUID"
    fi
    # xattr length check
    if [[ ${#TAG} -gt 250 ]]; then
      warn "Tag too long for $OBJ, skipping"
      continue
    fi
    if (( DRYRUN )); then
      log "[DRY-RUN] Would tag $OBJ as $TAG"
    else
      if setfattr $FATTR_FLAG -n "$XATTR_NAME" -v "$TAG" "$OBJ"; then
        log "Tagged $OBJ as $TAG"
      else
        warn "Failed to tag $OBJ"
      fi
    fi
    continue
  fi

  # Parse current tag: always starts with ts/uuid, optionally /name1;name2...
  UUID=$(echo "$CUR_TAG" | awk -F'/' '{print $2}')
  NAMES_PART=$(echo "$CUR_TAG" | cut -d'/' -f3-)
  IFS=';' read -ra CUR_NAMES <<< "$NAMES_PART"

  # REMOVE NAMES (-x)
  if [[ ${#REMOVE_NAMES[@]} -gt 0 ]]; then
    NEW_NAMES=()
    for name in "${CUR_NAMES[@]}"; do
      skip=0
      for rem in "${REMOVE_NAMES[@]}"; do
        [[ "$name" == "$rem" ]] && skip=1
      done
      (( skip == 0 && ${#name} > 0 )) && NEW_NAMES+=("$name")
    done
    if [[ ${#NEW_NAMES[@]} -gt 0 ]]; then
      TAG="ts/$UUID/$(IFS=';'; echo "${NEW_NAMES[*]}")"
    else
      TAG="ts/$UUID"
    fi
    if (( DRYRUN )); then
      log "[DRY-RUN] Would tag $OBJ as $TAG"
    else
      if setfattr $FATTR_FLAG -n "$XATTR_NAME" -v "$TAG" "$OBJ"; then
        log "Updated tag for $OBJ: $TAG"
      else
        warn "Failed to update tag for $OBJ"
      fi
    fi
    continue
  fi

  # REMOVE ALL NAMES (-X)
  if (( REPLACE_ALL )); then
    TAG="ts/$UUID"
    if (( DRYRUN )); then
      log "[DRY-RUN] Would tag $OBJ as $TAG"
    else
      if setfattr $FATTR_FLAG -n "$XATTR_NAME" -v "$TAG" "$OBJ"; then
        log "Removed all names from $OBJ (kept UUID)"
      else
        warn "Failed to update tag for $OBJ"
      fi
    fi
    continue
  fi

  # ADD NAMES
  if [[ ${#ADD_NAMES[@]} -gt 0 ]]; then
    # Avoid duplicates: merge current names with new ones, unique
    ALL_NAMES=("${CUR_NAMES[@]}" "${ADD_NAMES[@]}")
    # Clean up empty entries, normalize, remove dupes
    NORM_NAMES=($(printf "%s\n" "${ALL_NAMES[@]}" | awk 'NF' | sort -u))
    TAG="ts/$UUID"
    if [[ ${#NORM_NAMES[@]} -gt 0 ]]; then
      TAG="$TAG/$(IFS=';'; echo "${NORM_NAMES[*]}")"
    fi
    if [[ ${#TAG} -gt 250 ]]; then
      warn "Tag too long for $OBJ, skipping"
      continue
    fi
    if (( DRYRUN )); then
      log "[DRY-RUN] Would tag $OBJ as $TAG"
    else
      if setfattr $FATTR_FLAG -n "$XATTR_NAME" -v "$TAG" "$OBJ"; then
        log "Tagged $OBJ as $TAG"
      else
        warn "Failed to tag $OBJ"
      fi
    fi
    continue
  fi

  # If none of the above, do nothing (just re-tag as is)
  vlog "No operation specified for $OBJ"
done
