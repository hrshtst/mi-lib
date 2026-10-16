#!/usr/bin/env bash
#
# Thaw the library versions recorded in the version lock file: check
# out each configured library at its recorded commit. Lock entries
# for libraries outside the configuration are left untouched (so a
# consumer building a subset can thaw from a fuller lock), and
# repositories with local changes to tracked files are skipped. Each
# library is put back on its recorded branch where that loses no
# commit, and is left detached at the recorded commit otherwise.
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

# How a library ($1) gets onto its recorded branch ($3) at the
# recorded commit ($2) without losing a commit: "checkout" when the
# local branch points there, "fast-forward" when the local branch is
# behind it (an ancestor of the commit), "track" when the branch is
# not local but origin has it there, and "detach" otherwise. A local
# branch that has moved ahead or diverged is never reset. Keeping the
# branch lets a later freeze record its name, where a detached
# checkout would record HEAD.
branch_action() {
  local tip
  if [ "$3" = "HEAD" ]; then
    echo detach
  elif tip="$(git -C "$1" rev-parse --quiet --verify "refs/heads/$3" 2>/dev/null)"; then
    if [ "$tip" = "$2" ]; then
      echo checkout
    elif git -C "$1" merge-base --is-ancestor "$tip" "$2" 2>/dev/null; then
      echo fast-forward
    else
      echo detach
    fi
  elif [ "$(git -C "$1" rev-parse --quiet --verify "refs/remotes/origin/$3" 2>/dev/null)" = "$2" ]; then
    echo track
  else
    echo detach
  fi
}

# Check out the recorded commit ($2) of a library ($1) as
# branch_action decided ($4) for the recorded branch ($3).
apply_action() {
  case "$4" in
    checkout)
      git -C "$1" checkout -q "$3"
      ;;
    fast-forward)
      echo "⏩  Fast-forwarding '$3' from $(git -C "$1" rev-parse --short "refs/heads/$3")"
      git -C "$1" checkout -q -B "$3" "$2"
      ;;
    track)
      git -C "$1" checkout -q --track -b "$3" "origin/$3"
      ;;
    detach)
      git -C "$1" checkout -q --detach "$2"
      ;;
  esac
}

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
    # A checkout left detached at the recorded commit, by an earlier
    # thaw for instance, goes back onto its branch where that loses no
    # commit. The commit stays the same, so local changes are kept.
    if [ "$(git -C "$lib" rev-parse --abbrev-ref HEAD)" = "HEAD" ]; then
      action="$(branch_action "$lib" "$sha" "$branch")"
      if [ "$action" = "detach" ]; then
        if [ "$branch" != "HEAD" ]; then
          echo "⚠️  Branch '$branch' no longer points at the recorded commit; left detached"
        fi
      elif $DRY_RUN; then
        echo "💡 (dry-run) Would reattach '$branch' ($action)"
      else
        apply_action "$lib" "$sha" "$branch" "$action"
        echo "🔗  Reattached '$branch'"
      fi
    fi
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
  action="$(branch_action "$lib" "$sha" "$branch")"
  if $DRY_RUN; then
    echo "💡 (dry-run) Would check out ${sha:0:7} ($branch, $action), currently at $(git -C "$lib" rev-parse --short HEAD)"
    continue
  fi
  apply_action "$lib" "$sha" "$branch" "$action"
  if [ "$action" = "detach" ] && [ "$branch" != "HEAD" ]; then
    echo "⚠️  Branch '$branch' no longer points at the recorded commit; detached"
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
