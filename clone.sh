#!/usr/bin/env bash

# List of libraries
. "liblist"
OWNER="hrshtst"

echo "installing required packages..."
### (for download & compilation)
sudo apt install git wget unzip rename make gcc fakeroot pkg-config
### (for ZEDA & X11 & OpenGL)
sudo apt install libxml2-dev liblzf-dev xorg-dev libxft-dev libfreetype-dev libtiff-dev libjpeg-dev libmagickwand-dev freeglut3-dev libglew-dev libglfw3-dev

for lib in $LIBS; do
    echo "==> Cloning $lib"
    if [ -d "$lib" ]; then
        echo "⚠️  Directory '$lib' already exists, skipping."
        continue
    fi
    git clone "git@github.com:${OWNER}/${lib}.git" "$lib" || {
        echo "❌  Failed to clone ${OWNER}/${lib}"
    }
done

# Local Variables:
# jinx-local-words: "env hrshtst liblist usr"
# End:
