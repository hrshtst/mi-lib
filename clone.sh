#!/usr/bin/env bash

# List of libraries
. "liblist"
OWNER="hrshtst"

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
