#!/usr/bin/env bash

# v0.1.2
# List only TAGGED files/dirs as ls would, using ls for formatting.

XATTR_NAME="user.backup_id"

show_help() {
  cat <<EOF
TagSync: tsls.sh v0.1.2
Usage: $0 [OPTIONS] [files-or-dirs...]
  -h, --help      Show this help.
  [ls-args...]    Any arguments not recognized as flags are passed to ls.
  Only tagged files/dirs are listed.
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

if [[ ${#LS_PATHS[@]} -eq 0 ]]; then
  # No files/dirs specified: use '.'
  # If '.' is tagged, print '.'
  if getfattr --only-values -n "$XATTR_NAME" "." &>/dev/null; then
    ls "${LS_FLAGS[@]}" .
    exit 0
  fi
  # Otherwise, only list tagged files in the current dir
  TO_LS=()
  while IFS= read -r f; do
    if getfattr --only-values -n "$XATTR_NAME" "$f" &>/dev/null; then
      TO_LS+=("$f")
    fi
  done < <(ls -A1)
  if [[ ${#TO_LS[@]} -gt 0 ]]; then
    ls "${LS_FLAGS[@]}" "${TO_LS[@]}"
  fi
  exit 0
fi

# Some files/dirs were specified. List only those that are tagged.
TO_LS=()
for ARG in "${LS_PATHS[@]}"; do
  if getfattr --only-values -n "$XATTR_NAME" "$ARG" &>/dev/null; then
    TO_LS+=("$ARG")
  fi
done

if [[ ${#TO_LS[@]} -gt 0 ]]; then
  ls "${LS_FLAGS[@]}" "${TO_LS[@]}"
fi
