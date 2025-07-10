#!/usr/bin/env bash

# v0.1.2
# List files but hide those that are tagged (by default).
# With -V/--verbose, show all, but tagged files are in magenta.

XATTR_NAME="user.backup_id"
VERBOSE=0

show_help() {
  cat <<EOF
TagSync: tsls.sh v0.1.2
Usage: $0 [OPTIONS] [--] [ls-args...]
  -V, --verbose   Show all files; highlight tagged files in magenta.
  -h, --help      Show this help.
  [ls-args...]    Any other arguments are passed to ls as usual.
EOF
}

# Parse only tsls-specific flags first
LS_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -V|--verbose) VERBOSE=1 ;;
    --) shift; while [[ $# -gt 0 ]]; do LS_ARGS+=("$1"); shift; done; break ;;
    -*) LS_ARGS+=("$1") ;; # pass all other flags straight to ls
    *) LS_ARGS+=("$1") ;;
  esac
  shift
done

# Find which files to list. If no file/dir given, use "."
LS_TARGETS=()
for arg in "${LS_ARGS[@]}"; do
  [[ "$arg" =~ ^- ]] || LS_TARGETS+=("$arg")
done
if [[ ${#LS_TARGETS[@]} -eq 0 ]]; then
  LS_TARGETS=(".")

  # Remove the trailing . from LS_ARGS so ls doesn't get a duplicate
  for i in "${!LS_ARGS[@]}"; do
    if [[ "${LS_ARGS[$i]}" == "." ]]; then
      unset "LS_ARGS[$i]"
    fi
  done
fi

# Do the ls, but capture the output to parse filenames
# Use -1 for predictable filename output, then replace with color as needed

if (( VERBOSE )); then
  # Show all files, tag the tagged ones with magenta.
  for TARGET in "${LS_TARGETS[@]}"; do
    # Get files/dirs in 1-column, hide . and .. if not asked for
    mapfile -t FILES < <(ls -A1 "${LS_ARGS[@]}" "$TARGET")
    for FILE in "${FILES[@]}"; do
      if getfattr --only-values -n "$XATTR_NAME" "$TARGET/$FILE" &>/dev/null; then
        # Magenta
        echo -e "\033[35m$FILE\033[0m"
      else
        echo "$FILE"
      fi
    done
  done
else
  # Hide tagged files, show only untagged
  for TARGET in "${LS_TARGETS[@]}"; do
    mapfile -t FILES < <(ls -A1 "${LS_ARGS[@]}" "$TARGET")
    for FILE in "${FILES[@]}"; do
      if ! getfattr --only-values -n "$XATTR_NAME" "$TARGET/$FILE" &>/dev/null; then
        echo "$FILE"
      fi
    done
  done
fi
