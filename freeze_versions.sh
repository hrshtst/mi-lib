#!/usr/bin/env bash
#
# Freeze the current library versions into the version lock file:
# record each library's HEAD commit, branch, and a dirty marker for
# uncommitted changes to tracked files. The counterpart of
# thaw_versions.sh.
#
# Usage:
#   ./freeze_versions.sh            # Write the lock file
#   ./freeze_versions.sh --dry-run  # Only show what would be recorded

set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=load_config.sh
. ./load_config.sh

DRY_RUN=false
if [[ $# -gt 0 ]]; then
  case "$1" in
    --dry-run|-n)
      DRY_RUN=true
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dry-run]"
      exit 1
      ;;
  esac
fi

record() {
  local lib sha branch dirty
  for lib in $LIBS; do
    if [ ! -d "$lib" ]; then
      echo "❌ Directory '$lib' not found (run clone.sh)" >&2
      return 1
    fi
    sha=$(git -C "$lib" rev-parse HEAD)
    branch=$(git -C "$lib" rev-parse --abbrev-ref HEAD)
    if [ -n "$(git -C "$lib" status --porcelain --untracked-files=no)" ]; then
      dirty=" dirty"
    else
      dirty=""
    fi
    echo "$lib $sha $branch$dirty"
  done
}

if $DRY_RUN; then
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
