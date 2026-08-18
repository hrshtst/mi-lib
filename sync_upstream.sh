#!/usr/bin/env bash
#
# Fast-forward the upstream libraries' main branches. In fork mode the
# forks are fast-forwarded to their upstreams, both locally and on the
# origin forks; in forkless mode (OWNER matches UPSTREAM_OWNER) the
# local clones are simply fast-forwarded from origin.
#
# Branches listed in SYNC_BRANCHES (e.g. fork branches carrying
# patches pending as upstream pull requests) are additionally
# fast-forwarded from origin — their source of truth — per library;
# libraries without such a branch are skipped, and nothing is pushed
# for them.
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
NOT_ON_MAIN=""
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
    echo "✅  main already up to date"
  elif $DRY_RUN; then
    if milib_forkless; then
      echo "💡 (dry-run) Would fast-forward main by $behind commit(s)"
    else
      echo "💡 (dry-run) Would fast-forward main by $behind commit(s) and push"
    fi
  else
    current=$(git -C "$lib" symbolic-ref --short -q HEAD || echo "(detached)")
    if [ "$current" = "main" ]; then
      git -C "$lib" merge --ff-only -q "$REMOTE/main"
    else
      # Fast-forward main without switching away from the current branch.
      git -C "$lib" fetch -q . "$REMOTE/main:main"
      echo "⚠️  '$current' is checked out; consider rebasing it onto main"
      NOT_ON_MAIN="$NOT_ON_MAIN $lib($current)"
    fi
    if milib_forkless; then
      echo "✅  Fast-forwarded main by $behind commit(s)"
    else
      git -C "$lib" push -q origin main
      echo "✅  Fast-forwarded main by $behind commit(s) and pushed"
    fi
    SYNCED="$SYNCED $lib"
  fi

  # Configured fork branches, fast-forwarded from origin (nothing is
  # pushed: origin already carries their newest state).
  for br in $SYNC_BRANCHES; do
    if ! git -C "$lib" fetch -q origin \
        "refs/heads/$br:refs/remotes/origin/$br" 2>/dev/null; then
      continue  # this library does not carry the branch
    fi
    if ! git -C "$lib" rev-parse --quiet --verify \
        "refs/heads/$br" >/dev/null 2>&1; then
      if $DRY_RUN; then
        echo "💡 (dry-run) Would create '$br' from origin"
      else
        git -C "$lib" branch -q --track "$br" "origin/$br"
        echo "✅  Created '$br' from origin"
        SYNCED="$SYNCED $lib($br)"
      fi
      continue
    fi
    b_behind=$(git -C "$lib" rev-list --count "$br..origin/$br")
    b_ahead=$(git -C "$lib" rev-list --count "origin/$br..$br")
    if [ "$b_ahead" -gt 0 ]; then
      echo "⚠️  '$br' has $b_ahead local commit(s) not on origin, skipping"
      FAILED="$FAILED $lib($br)"
      continue
    fi
    if [ "$b_behind" -eq 0 ]; then
      echo "✅  '$br' already up to date"
      continue
    fi
    if $DRY_RUN; then
      echo "💡 (dry-run) Would fast-forward '$br' by $b_behind commit(s)"
      continue
    fi
    if [ "$(git -C "$lib" symbolic-ref --short -q HEAD || true)" = "$br" ]; then
      git -C "$lib" merge --ff-only -q "origin/$br"
    else
      # Fast-forward without switching away from the current branch.
      git -C "$lib" fetch -q . "origin/$br:$br"
    fi
    echo "✅  Fast-forwarded '$br' by $b_behind commit(s)"
    SYNCED="$SYNCED $lib($br)"
  done
done

if [ -n "$SYNCED" ]; then
  echo
  echo "🎉 Synced:$SYNCED"
  echo "💡 Rebuild to adopt the updates: ./build_compile_commands.sh"
fi
if [ -n "$NOT_ON_MAIN" ]; then
  echo "⚠️ main updated but not checked out in:$NOT_ON_MAIN"
  echo "💡 Rebase those branches onto main (or check out main) before rebuilding to test the upstream state"
fi
if [ -n "$FAILED" ]; then
  echo "❌ Needs attention:$FAILED"
  exit 1
fi

# Local Variables:
# jinx-local-words: "config env"
# End:
