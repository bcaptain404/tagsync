#!/usr/bin/env bash

# v0.1.2
# Only lists tagged files/dirs as ls would, using ls for formatting.
# For tagged dirs: lists only the dir itself, not its contents.

XATTR_NAME="user.backup_id"

show_help() {
  cat <<EOF
TagSync: tsls.sh v0.1.2
Usage: $0 [OPTIONS] [files-or-dirs...]
  -h, --help      Show this help.
  [ls-args...]    Any arguments not recognized as flags are passed to ls.
  Only tagged files/dirs are listed. Tagged dirs print the dir only (not contents).
EOF
}

LS_FLAGS=()
LS_PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -*) LS_FLAGS+=("$1") ;;
    *) LS_PATHS+=("$1") ;;
  esac
  shift
done

# If stdout is a terminal and no --color flag present, force color for ls output
COLORFLAG=0
for f in "${LS_FLAGS[@]}"; do
  [[ "$f" == --color* ]] && COLORFLAG=1 && break
done
if [[ $COLORFLAG -eq 0 && -t 1 ]]; then
  LS_FLAGS+=("--color=always")
fi

if [[ ${#LS_PATHS[@]} -eq 0 ]]; then
  # No files/dirs specified: use '.'
  if getfattr --only-values -n "$XATTR_NAME" "." &>/dev/null; then
    ls "${LS_FLAGS[@]}" -d .
    exit 0
  fi
  # Otherwise, only list tagged files in the current dir
  TO_LS_FILES=()
  TO_LS_DIRS=()
  while IFS= read -r f; do
    if getfattr --only-values -n "$XATTR_NAME" "$f" &>/dev/null; then
      if [[ -d "$f" && ! -L "$f" ]]; then
        TO_LS_DIRS+=("$f")
      else
        TO_LS_FILES+=("$f")
      fi
    fi
  done < <(ls -A1)
  if [[ ${#TO_LS_FILES[@]} -gt 0 ]]; then
    ls "${LS_FLAGS[@]}" "${TO_LS_FILES[@]}"
  fi
  if [[ ${#TO_LS_DIRS[@]} -gt 0 ]]; then
    ls "${LS_FLAGS[@]}" -d "${TO_LS_DIRS[@]}"
  fi
  exit 0
fi

# Some files/dirs were specified.
TO_LS_FILES=()
TO_LS_DIRS=()
for ARG in "${LS_PATHS[@]}"; do
  if getfattr --only-values -n "$XATTR_NAME" "$ARG" &>/dev/null; then
    if [[ -d "$ARG" && ! -L "$ARG" ]]; then
      TO_LS_DIRS+=("$ARG")
    else
      TO_LS_FILES+=("$ARG")
    fi
  fi
done

if [[ ${#TO_LS_FILES[@]} -gt 0 ]]; then
  ls "${LS_FLAGS[@]}" "${TO_LS_FILES[@]}"
fi
if [[ ${#TO_LS_DIRS[@]} -gt 0 ]]; then
  ls "${LS_FLAGS[@]}" -d "${TO_LS_DIRS[@]}"
fi
