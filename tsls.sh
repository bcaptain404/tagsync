#!/usr/bin/env bash
echo "argv: $@" >&2


# v0.2.3 -- TagSync: List files/dirs tagged (optionally by name), works for files or directories

XATTR_NAME="user.backup_id"
DEBUG=0

show_help() {
  cat <<EOF
TagSync: tsls.sh v0.2.3
Usage: $0 [-n name[,name2...]]... [dir|file ...] [--debug]
  -n, --name NAMES  Only show files tagged with these names (comma or semicolon separated). May repeat for groups.
  --debug           Print debug info to stderr.
  -h, --help        Show help.

If no -n is given, all tagged files/dirs are shown.
You can supply multiple groups: e.g.
  tsls.sh -n work,per src1 -n sys src2

Lists only files/dirs that are tagged with the given names in each group, or all tagged files if no names.
EOF
}

# --- Argument parsing ---
GROUPS=()
CURRENT_NAMES=()
CURRENT_PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=1; shift ;;
    -n|--name)
      shift
      [[ -z "$1" || "$1" =~ ^- ]] && { echo "-n requires at least one name" >&2; exit 1; }
      [[ ${#CURRENT_PATHS[@]} -gt 0 ]] && { GROUPS+=("${CURRENT_NAMES[*]}:::${CURRENT_PATHS[*]}"); CURRENT_PATHS=(); }
      IFS=',;' read -ra NMS <<< "$1"
      CURRENT_NAMES=("${NMS[@]}")
      ;;
    -h|--help)
      show_help; exit 0
      ;;
    *)
      CURRENT_PATHS+=("$1")
      ;;
  esac
  shift
done
[[ ${#CURRENT_PATHS[@]} -gt 0 || ${#CURRENT_NAMES[@]} -gt 0 ]] && GROUPS+=("${CURRENT_NAMES[*]}:::${CURRENT_PATHS[*]}")
if [[ ${#GROUPS[@]} -eq 0 ]]; then
  GROUPS+=(":::.")
fi

for GROUP in "${GROUPS[@]}"; do
  NAMES_PART="${GROUP%%:::*}"
  PATHS_PART="${GROUP#*:::}"
  IFS=' ' read -ra NAMES <<< "$NAMES_PART"
  IFS=' ' read -ra PATHS <<< "$PATHS_PART"
  [[ ${#PATHS[@]} -eq 0 ]] && PATHS=(".")

  ((DEBUG)) && echo "---- GROUP ----" >&2
  ((DEBUG)) && echo "NAMES: ${NAMES[*]}" >&2
  ((DEBUG)) && echo "PATHS: ${PATHS[*]}" >&2

  TO_LIST=()
  for TARGET in "${PATHS[@]}"; do
    ((DEBUG)) && echo "TARGET: $TARGET" >&2
    if [[ -d "$TARGET" && ! -L "$TARGET" ]]; then
      mapfile -t FILES < <(ls -A1 "$TARGET")
      for FILE in "${FILES[@]}"; do
        OBJ="$TARGET/$FILE"
        TAG=$(getfattr --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)
        ((DEBUG)) && echo "  FILE: $OBJ   TAG: $TAG" >&2
        if [[ -n "$TAG" && "${TAG:0:3}" == "ts/" ]]; then
          if [[ ${#NAMES[@]} -eq 0 ]]; then
            TO_LIST+=("$OBJ")
            ((DEBUG)) && echo "    -> Added (any tag)" >&2
          else
            NAMES_PART_TAG=$(echo "$TAG" | cut -d'/' -f3-)
            for NAME in "${NAMES[@]}"; do
              if [[ "$NAMES_PART_TAG" =~ (^|[;])$NAME([;]|$) ]]; then
                TO_LIST+=("$OBJ")
                ((DEBUG)) && echo "    -> Added (name match: $NAME)" >&2
                break
              fi
            done
          fi
        fi
      done
    elif [[ -e "$TARGET" || -L "$TARGET" ]]; then
      TAG=$(getfattr --only-values -n "$XATTR_NAME" "$TARGET" 2>/dev/null)
      ((DEBUG)) && echo "  FILE: $TARGET   TAG: $TAG" >&2
      if [[ -n "$TAG" && "${TAG:0:3}" == "ts/" ]]; then
        if [[ ${#NAMES[@]} -eq 0 ]]; then
          TO_LIST+=("$TARGET")
          ((DEBUG)) && echo "    -> Added (any tag)" >&2
        else
          NAMES_PART_TAG=$(echo "$TAG" | cut -d'/' -f3-)
          for NAME in "${NAMES[@]}"; do
            if [[ "$NAMES_PART_TAG" =~ (^|[;])$NAME([;]|$) ]]; then
              TO_LIST+=("$TARGET")
              ((DEBUG)) && echo "    -> Added (name match: $NAME)" >&2
              break
            fi
          done
        fi
      fi
    fi
  done

  ((DEBUG)) && echo "TO_LIST: ${TO_LIST[*]}" >&2
  if [[ ${#TO_LIST[@]} -gt 0 ]]; then
    ls -d "${TO_LIST[@]}"
  fi
done
