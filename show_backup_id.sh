#!/bin/bash

XATTR_NAME="user.backup_id"

show_help() {
  cat <<EOF
Usage: $0 <file|dir> [file|dir] ... [--help]
  <file|dir>      Files or directories to query for backup ID.
  [--help]        Show this help message.
EOF
}

# Print usage if no arguments given
if [[ $# -eq 0 ]]; then
  show_help
  exit 1
fi

# Check for --help/-h
for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

for OBJ in "$@"; do
  if [[ "$OBJ" == -* ]]; then
    echo "Unknown argument: $OBJ"
    show_help
    exit 1
  fi
done

for OBJ in "$@"; do
  if [[ ! -e "$OBJ" ]]; then
    echo "WARNING: File or directory not found: $OBJ" >&2
    continue
  fi
  ID=$(getfattr --only-values -n "$XATTR_NAME" "$OBJ" 2>/dev/null)
  if [[ -n "$ID" ]]; then
    echo "$OBJ: $ID"
  fi
done
