#!/usr/bin/env bash
#
# check-gh-login-and-fork.sh
#
# Checks if you're logged in to GitHub via gh CLI (SSH).
# If not, attempts login, then forks a list of repositories
# from the 'mi-lib' organization into your personal account.
#
# Usage:
#   ./check-gh-login-and-fork.sh            # Normal execution
#   ./check-gh-login-and-fork.sh --dry-run  # Show what would be done, but don't fork
#

set -euo pipefail

cd "$(dirname "$0")"

# === CONFIGURATION ===
ORG="mi-lib"
# shellcheck source=liblist
. ./liblist
read -ra LIBS <<< "$UPSTREAM_LIBS"
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
    gh auth login --hostname github.com --git-protocol ssh

    if gh auth status >/dev/null 2>&1; then
      USERNAME=$(gh api user -q .login)
      echo "✅ Successfully logged in as: $USERNAME"
    else
      echo "❌ Login failed. Please try manually:"
      echo "   gh auth login --hostname github.com --git-protocol ssh"
      exit 1
    fi
  fi
}

fork_repos() {
  echo "🔁 Starting to fork repositories from '$ORG'..."
  if $DRY_RUN; then
    echo "💡 Dry-run mode enabled — no actual forks will be created."
  fi

  for repo in "${LIBS[@]}"; do
    echo "➡️  Target: ${ORG}/${repo}"
    if $DRY_RUN; then
      echo "   (dry-run) Would run: gh repo fork ${ORG}/${repo} --clone=false"
    else
      if gh repo fork "${ORG}/${repo}" --clone=false >/dev/null 2>&1; then
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
# jinx-local-words: "auth env gh github hostname repo usr"
# End:
