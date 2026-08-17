#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=load_config.sh
. ./load_config.sh

echo "Fork owner: $OWNER (protocol: $GIT_PROTOCOL)"

# Prerequisite packages are installed separately by install_prereq.sh.

# Add the upstream remote to libraries forked from the upstream
# organization, unless it is already configured. In forkless mode the
# origin already points at the upstream organization.
add_upstream() {
    if milib_forkless; then
        return 0
    fi
    case " $UPSTREAM_LIBS " in
        *" $1 "*)
            local url current
            url="$(milib_repo_url "$UPSTREAM_OWNER" "$1")"
            if ! current="$(git -C "$1" remote get-url upstream 2>/dev/null)"; then
                echo "   Adding upstream remote ${UPSTREAM_OWNER}/$1"
                git -C "$1" remote add upstream "$url"
            elif [ "$current" != "$url" ]; then
                echo "   Correcting upstream remote URL: $current -> $url"
                git -C "$1" remote set-url upstream "$url"
            fi
            ;;
    esac
}

FAILED=""
clone_one() {  # $1 = owner, $2 = repository
    echo "==> Cloning $2"
    if [ -d "$2" ]; then
        echo "⚠️  Directory '$2' already exists, skipping clone."
    else
        git clone "$(milib_repo_url "$1" "$2")" "$2" || {
            echo "❌  Failed to clone $1/$2"
            FAILED="$FAILED $2"
            return 0
        }
    fi
    add_upstream "$2"
}

for lib in $UPSTREAM_LIBS; do
    clone_one "$OWNER" "$lib"
done
if [ -n "$CUSTOM_LIB" ]; then
    clone_one "$CUSTOM_LIB_OWNER" "$CUSTOM_LIB"
fi

if [ -n "$FAILED" ]; then
    echo "❌ Failed to clone:$FAILED"
    exit 1
fi

# Local Variables:
# jinx-local-words: "config env"
# End:
