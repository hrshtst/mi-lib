#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

# List of libraries
# shellcheck source=liblist
. ./liblist
# Owner of the forked repositories: taken from the environment when
# set, otherwise derived from the origin URL of this repository.
OWNER="${OWNER:-$(git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#')}"
if [ -z "$OWNER" ]; then
  echo "❌  Cannot determine the fork owner; set the OWNER environment variable."
  exit 1
fi
echo "Fork owner: $OWNER"
UPSTREAM_OWNER="mi-lib"

# Prerequisite packages are installed separately by install_prereq.sh.

# Add the upstream remote to libraries forked from the mi-lib
# organization, unless it is already configured.
add_upstream() {
    case " $UPSTREAM_LIBS " in
        *" $1 "*)
            if ! git -C "$1" remote get-url upstream >/dev/null 2>&1; then
                echo "   Adding upstream remote ${UPSTREAM_OWNER}/$1"
                git -C "$1" remote add upstream "git@github.com:${UPSTREAM_OWNER}/$1.git"
            fi
            ;;
    esac
}

for lib in $LIBS; do
    echo "==> Cloning $lib"
    if [ -d "$lib" ]; then
        echo "⚠️  Directory '$lib' already exists, skipping clone."
    else
        git clone "git@github.com:${OWNER}/${lib}.git" "$lib" || {
            echo "❌  Failed to clone ${OWNER}/${lib}"
            continue
        }
    fi
    add_upstream "$lib"
done

# Local Variables:
# jinx-local-words: "env liblist"
# End:
