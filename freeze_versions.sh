#!/usr/bin/env bash
#
# Freeze the current library versions into the version lock file:
# record each library's HEAD commit and branch. The counterpart of
# thaw_versions.sh.
#
# A lock must be reproducible from its commit IDs alone, so freezing
# refuses to run while any configured library has staged or unstaged
# changes to tracked files. Untracked files are ignored (builds
# generate many) and are never captured by a lock.
#
# Usage:
#   ./freeze_versions.sh            # Write the lock file
#   ./freeze_versions.sh --dry-run  # Only show what would be recorded
#   ./freeze_versions.sh --check    # Only verify the libraries are clean

set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=load_config.sh
. ./load_config.sh

MODE=freeze
if [[ $# -gt 0 ]]; then
  case "$1" in
    --dry-run|-n)
      MODE=dry-run
      ;;
    --check)
      MODE=check
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dry-run|--check]"
      exit 1
      ;;
  esac
fi

for lib in $LIBS; do
  if [ ! -d "$lib" ]; then
    echo "❌ Directory '$lib' not found (run clone.sh)" >&2
    exit 1
  fi
done

DIRTY=""
for lib in $LIBS; do
  if [ -n "$(git -C "$lib" status --porcelain --untracked-files=no)" ]; then
    DIRTY="$DIRTY $lib"
  fi
done
if [ -n "$DIRTY" ]; then
  {
    echo "❌ Cannot freeze a reproducible version lock."
    echo
    echo "Tracked changes:"
    for lib in $DIRTY; do
      echo "  $lib"
    done
    echo
    echo "Commit or stash these changes, then rebuild."
    echo "$VERSIONS_LOCK was not modified."
  } >&2
  exit 1
fi
if [ "$MODE" = "check" ]; then
  exit 0
fi

record() {
  local lib
  for lib in $LIBS; do
    echo "$lib $(git -C "$lib" rev-parse HEAD) $(git -C "$lib" rev-parse --abbrev-ref HEAD)"
  done
}

if [ "$MODE" = "dry-run" ]; then
  record > "$VERSIONS_LOCK.tmp"
  if [ -f "$VERSIONS_LOCK" ]; then
    if diff -u "$VERSIONS_LOCK" "$VERSIONS_LOCK.tmp"; then
      echo "💡 (dry-run) $VERSIONS_LOCK is already up to date"
    else
      echo "💡 (dry-run) Would update $VERSIONS_LOCK as above"
    fi
  else
    cat "$VERSIONS_LOCK.tmp"
    echo "💡 (dry-run) Would create $VERSIONS_LOCK with the lines above"
  fi
  rm -f "$VERSIONS_LOCK.tmp"
else
  record > "$VERSIONS_LOCK.tmp"
  mv "$VERSIONS_LOCK.tmp" "$VERSIONS_LOCK"
  echo "✅ Recorded $(wc -l < "$VERSIONS_LOCK") libraries in $VERSIONS_LOCK"
fi

# Local Variables:
# jinx-local-words: "config env versions"
# End:
