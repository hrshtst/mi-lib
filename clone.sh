#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

# List of libraries
# shellcheck source=liblist
. ./liblist
OWNER="hrshtst"
UPSTREAM_OWNER="mi-lib"

echo "installing required packages..."
### (for download & compilation)
sudo apt install git wget unzip rename make gcc fakeroot pkg-config
### (for ZEDA & X11 & OpenGL)
sudo apt install libxml2-dev liblzf-dev xorg-dev libxft-dev libfreetype-dev libtiff-dev libjpeg-dev libmagickwand-dev freeglut3-dev libglew-dev libglfw3-dev

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
# jinx-local-words: "env hrshtst liblist usr"
# End:
