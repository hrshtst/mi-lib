#!/usr/bin/env bash
#
# Thaw the library versions recorded in the version lock file: check
# out each configured library at its recorded commit. Lock entries
# for libraries outside the configuration are left untouched (so a
# consumer building a subset can thaw from a fuller lock), and
# repositories with local changes to tracked files are skipped.
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
IGNORED=""

# Only the configured libraries are thawed: lock entries for
# libraries the configuration leaves out (e.g. a consumer building a
# subset) are reported and left untouched, while a configured library
# without a lock entry is an error — the lock predates the
# configuration.
while read -r lib _; do
  if [ -z "$lib" ]; then continue; fi
  case " $LIBS " in
    *" $lib "*) ;;
    *) IGNORED="$IGNORED $lib" ;;
  esac
done < "$LOCK"

for lib in $LIBS; do
  echo "==> $lib"
  entry="$(grep -m 1 -- "^$lib " "$LOCK" || true)"
  if [ -z "$entry" ]; then
    echo "❌  No entry in $LOCK"
    FAILED="$FAILED $lib"
    continue
  fi
  read -r _ sha branch flag <<<"$entry"
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
  elif [ "$branch" != "HEAD" ] && \
       ! git -C "$lib" rev-parse --quiet --verify "refs/heads/$branch" >/dev/null 2>&1 && \
       [ "$(git -C "$lib" rev-parse --quiet --verify "refs/remotes/origin/$branch" 2>/dev/null)" = "$sha" ]; then
    # The recorded branch is not local but origin still has it at the
    # recorded commit: create it tracking origin instead of detaching,
    # so a later freeze records the branch name again. A local branch
    # that has moved elsewhere is never reset — that case detaches.
    git -C "$lib" checkout -q --track -b "$branch" "origin/$branch"
  else
    git -C "$lib" checkout -q --detach "$sha"
    if [ "$branch" != "HEAD" ]; then
      echo "⚠️  Branch '$branch' no longer points at the recorded commit; detached"
    fi
  fi
  echo "✅  Checked out ${sha:0:7} ($branch)"
  THAWED="$THAWED $lib"
done

if [ -n "$IGNORED" ]; then
  echo
  echo "ℹ️ Locked but not configured, left untouched:$IGNORED"
fi
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
