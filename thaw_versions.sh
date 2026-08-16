#!/usr/bin/env bash
#
# Thaw the library versions recorded in the version lock file: check
# out each library at its recorded commit. Repositories with local
# changes to tracked files are skipped.
#
# Usage:
#   ./thaw_versions.sh            # Check out the recorded versions
#   ./thaw_versions.sh --dry-run  # Only show what would change

set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=load_config.sh
. ./load_config.sh

LOCK="$VERSIONS_LOCK"
if [ ! -f "$LOCK" ]; then
  echo "❌ $LOCK not found; run ./build_compile_commands.sh first"
  exit 1
fi

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

THAWED=""
SKIPPED=""
FAILED=""
while read -r lib sha branch flag; do
  [ -z "$lib" ] && continue
  echo "==> $lib"
  if [ ! -d "$lib" ]; then
    echo "❌  Directory not found (run clone.sh)"
    FAILED="$FAILED $lib"
    continue
  fi
  if [ "$(git -C "$lib" rev-parse HEAD)" = "$sha" ]; then
    echo "✅  Already at recorded version"
    continue
  fi
  if [ -n "$(git -C "$lib" status --porcelain --untracked-files=no)" ]; then
    echo "⚠️  Local changes present, skipping"
    SKIPPED="$SKIPPED $lib"
    continue
  fi
  if ! git -C "$lib" cat-file -e "$sha^{commit}" 2>/dev/null; then
    git -C "$lib" fetch -q --all 2>/dev/null || true
    if ! git -C "$lib" cat-file -e "$sha^{commit}" 2>/dev/null; then
      echo "❌  Recorded commit $sha not found"
      FAILED="$FAILED $lib"
      continue
    fi
  fi
  if [ "$flag" = "dirty" ]; then
    echo "⚠️  Recorded state had uncommitted changes that cannot be restored"
  fi
  if $DRY_RUN; then
    echo "💡 (dry-run) Would check out ${sha:0:7} ($branch), currently at $(git -C "$lib" rev-parse --short HEAD)"
    continue
  fi
  if [ "$branch" != "HEAD" ] && \
     [ "$(git -C "$lib" rev-parse --quiet --verify "refs/heads/$branch" 2>/dev/null)" = "$sha" ]; then
    git -C "$lib" checkout -q "$branch"
  else
    git -C "$lib" checkout -q --detach "$sha"
    if [ "$branch" != "HEAD" ]; then
      echo "⚠️  Branch '$branch' no longer points at the recorded commit; detached"
    fi
  fi
  echo "✅  Checked out ${sha:0:7} ($branch)"
  THAWED="$THAWED $lib"
done < "$LOCK"

if [ -n "$THAWED" ]; then
  echo
  echo "🎉 Thawed:$THAWED"
  echo "💡 Rebuild to match the recorded state: ./build_compile_commands.sh"
fi
if [ -n "$SKIPPED$FAILED" ]; then
  [ -n "$SKIPPED" ] && echo "⚠️ Skipped (local changes):$SKIPPED"
  [ -n "$FAILED" ] && echo "❌ Failed:$FAILED"
  exit 1
fi

# Local Variables:
# jinx-local-words: "env versions"
# End:
