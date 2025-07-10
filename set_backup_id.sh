#!/bin/bash

XATTR_NAME="user.backup_id"
DRYRUN=0

show_help() {
  cat <<EOF
Usage: $0 <file|dir> [unset] [--dry-run] [--help]
  <file|dir>      File or directory to operate on.
  [unset]         Remove backup ID from object instead of setting it.
  [--dry-run]     Show what would be done, but don't change anything.
  [--help]        Show this help message.
EOF
}

# Parse for --help first
for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

# Parse --dry-run and clean arg list
NEWARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRYRUN=1
  else
    NEWARGS+=("$arg")
  fi
done

set -- "${NEWARGS[@]}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  show_help
  exit 1
fi

OBJ="$1"

if [[ $# -eq 2 ]]; then
  if [[ "$2" != "unset" ]]; then
    echo "Unknown argument: $2" >&2
    show_help
    exit 1
  fi
  if (( DRYRUN )); then
    echo "[DRY-RUN] Would unset $XATTR_NAME from $OBJ"
  else
    if setfattr -x "$XATTR_NAME" "$OBJ"; then
      echo "Unset $XATTR_NAME from $OBJ"
    else
      echo "WARNING: Failed to unset $XATTR_NAME from $OBJ" >&2
    fi
  fi
else
  ID=$(uuidgen)
  if (( DRYRUN )); then
    echo "[DRY-RUN] Would set $XATTR_NAME=$ID on $OBJ"
  else
    if setfattr -n "$XATTR_NAME" -v "$ID" "$OBJ"; then
      echo "Set $XATTR_NAME=$ID on $OBJ"
    else
      echo "WARNING: Failed to set $XATTR_NAME on $OBJ" >&2
    fi
  fi
fi
