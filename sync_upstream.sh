#!/usr/bin/env bash
#
# Fast-forward the forked libraries' main branches to their mi-lib
# upstreams, both locally and on the origin forks.
#
# Usage:
#   ./sync_upstream.sh            # Fetch, fast-forward, and push
#   ./sync_upstream.sh --dry-run  # Only show how far each fork is behind

set -euo pipefail

cd "$(dirname "$0")"

# List of libraries
# shellcheck source=liblist
. ./liblist

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

SYNCED=""
FAILED=""
for lib in $UPSTREAM_LIBS; do
  echo "==> $lib"
  if ! git -C "$lib" remote get-url upstream >/dev/null 2>&1; then
    echo "❌  No upstream remote (run clone.sh to configure it)"
    FAILED="$FAILED $lib"
    continue
  fi
  git -C "$lib" fetch -q upstream main
  behind=$(git -C "$lib" rev-list --count main..upstream/main)
  ahead=$(git -C "$lib" rev-list --count upstream/main..main)
  if [ "$ahead" -gt 0 ]; then
    echo "⚠️  main has $ahead local commit(s) not in upstream, skipping"
    FAILED="$FAILED $lib"
    continue
  fi
  if [ "$behind" -eq 0 ]; then
    echo "✅  Already up to date"
    continue
  fi
  if $DRY_RUN; then
    echo "💡 (dry-run) Would fast-forward main by $behind commit(s) and push"
    continue
  fi
  current=$(git -C "$lib" symbolic-ref --short -q HEAD || echo "(detached)")
  if [ "$current" = "main" ]; then
    git -C "$lib" merge --ff-only -q upstream/main
  else
    # Fast-forward main without switching away from the current branch.
    git -C "$lib" fetch -q . upstream/main:main
    echo "⚠️  '$current' is checked out; consider rebasing it onto main"
  fi
  git -C "$lib" push -q origin main
  echo "✅  Fast-forwarded main by $behind commit(s) and pushed"
  SYNCED="$SYNCED $lib"
done

if [ -n "$SYNCED" ]; then
  echo
  echo "🎉 Synced:$SYNCED"
  echo "💡 Rebuild to adopt the updates: ./build_compile_commands.sh"
fi
if [ -n "$FAILED" ]; then
  echo "❌ Needs attention:$FAILED"
  exit 1
fi

# Local Variables:
# jinx-local-words: "env liblist"
# End:
