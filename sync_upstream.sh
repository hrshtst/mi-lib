#!/usr/bin/env bash
#
# Fast-forward the upstream libraries' main branches. In fork mode the
# forks are fast-forwarded to their upstreams, both locally and on the
# origin forks; in forkless mode (OWNER matches UPSTREAM_OWNER) the
# local clones are simply fast-forwarded from origin.
#
# Usage:
#   ./sync_upstream.sh            # Fetch, fast-forward (and push forks)
#   ./sync_upstream.sh --dry-run  # Only show how far each library is behind

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

if milib_forkless; then
  REMOTE=origin
else
  REMOTE=upstream
fi

SYNCED=""
FAILED=""
for lib in $UPSTREAM_LIBS; do
  echo "==> $lib"
  if ! git -C "$lib" remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "❌  No $REMOTE remote (run clone.sh to configure it)"
    FAILED="$FAILED $lib"
    continue
  fi
  git -C "$lib" fetch -q "$REMOTE" main
  behind=$(git -C "$lib" rev-list --count "main..$REMOTE/main")
  ahead=$(git -C "$lib" rev-list --count "$REMOTE/main..main")
  if [ "$ahead" -gt 0 ]; then
    echo "⚠️  main has $ahead local commit(s) not in $REMOTE, skipping"
    FAILED="$FAILED $lib"
    continue
  fi
  if [ "$behind" -eq 0 ]; then
    echo "✅  Already up to date"
    continue
  fi
  if $DRY_RUN; then
    if milib_forkless; then
      echo "💡 (dry-run) Would fast-forward main by $behind commit(s)"
    else
      echo "💡 (dry-run) Would fast-forward main by $behind commit(s) and push"
    fi
    continue
  fi
  current=$(git -C "$lib" symbolic-ref --short -q HEAD || echo "(detached)")
  if [ "$current" = "main" ]; then
    git -C "$lib" merge --ff-only -q "$REMOTE/main"
  else
    # Fast-forward main without switching away from the current branch.
    git -C "$lib" fetch -q . "$REMOTE/main:main"
    echo "⚠️  '$current' is checked out; consider rebasing it onto main"
  fi
  if milib_forkless; then
    echo "✅  Fast-forwarded main by $behind commit(s)"
  else
    git -C "$lib" push -q origin main
    echo "✅  Fast-forwarded main by $behind commit(s) and pushed"
  fi
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
# jinx-local-words: "config env"
# End:
