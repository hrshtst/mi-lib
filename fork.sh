#!/usr/bin/env bash
#
# fork.sh
#
# Checks if you're logged in to GitHub via gh CLI. If not, attempts
# login, then forks the configured upstream libraries into your
# personal account. In forkless mode (OWNER matches UPSTREAM_OWNER)
# there is nothing to fork and the script exits immediately.
#
# Usage:
#   ./fork.sh            # Normal execution
#   ./fork.sh --dry-run  # Show what would be done, but don't fork
#

set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=load_config.sh
. ./load_config.sh
read -ra FORK_LIBS <<< "$UPSTREAM_LIBS"
DRY_RUN=false

# === ARGUMENT PARSING ===
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
  echo "💡 Forkless mode (OWNER=$OWNER): the original repositories are tracked directly; nothing to fork."
  exit 0
fi

# === FUNCTIONS ===

check_gh_installed() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI (gh) not found. Please install it:"
    echo "    https://github.com/cli/cli#installation"
    exit 1
  fi
}

check_gh_login() {
  echo "🔍 Checking GitHub login status..."
  if gh auth status >/dev/null 2>&1; then
    USERNAME=$(gh api user -q .login)
    echo "✅ Logged in to GitHub as: $USERNAME"
  else
    echo "⚠️  Not logged in to GitHub."
    echo "Attempting to log in..."
    gh auth login --hostname github.com --git-protocol "$GIT_PROTOCOL"

    if gh auth status >/dev/null 2>&1; then
      USERNAME=$(gh api user -q .login)
      echo "✅ Successfully logged in as: $USERNAME"
    else
      echo "❌ Login failed. Please try manually:"
      echo "   gh auth login --hostname github.com --git-protocol $GIT_PROTOCOL"
      exit 1
    fi
  fi
}

fork_repos() {
  echo "🔁 Starting to fork repositories from '$UPSTREAM_OWNER'..."
  if $DRY_RUN; then
    echo "💡 Dry-run mode enabled — no actual forks will be created."
  fi

  for repo in "${FORK_LIBS[@]}"; do
    echo "➡️  Target: ${UPSTREAM_OWNER}/${repo}"
    if $DRY_RUN; then
      echo "   (dry-run) Would run: gh repo fork ${UPSTREAM_OWNER}/${repo} --clone=false"
    else
      if gh repo fork "${UPSTREAM_OWNER}/${repo}" --clone=false >/dev/null 2>&1; then
        echo "   ✅ Forked ${repo}"
      else
        echo "   ⚠️  Skipped or failed to fork ${repo} (possibly already forked)"
      fi
    fi
  done

  echo "🎉 Forking process completed."
}

# === MAIN EXECUTION FLOW ===
check_gh_installed
check_gh_login
fork_repos

# Local Variables:
# jinx-local-words: "auth config env gh github hostname repo"
# End:
