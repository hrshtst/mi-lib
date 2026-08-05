#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
JSON="$(pwd)/compile_commands.json"

make clean
bear -- make

# Add header entries for clangd.
compdb -p . list > "$JSON.tmp"
mv "$JSON.tmp" "$JSON"

# Record the exact library versions this database was built from.
# shellcheck source=liblist
. ./liblist
for lib in $LIBS; do
  sha=$(git -C "$lib" rev-parse HEAD)
  branch=$(git -C "$lib" rev-parse --abbrev-ref HEAD)
  if [ -n "$(git -C "$lib" status --porcelain --untracked-files=no)" ]; then
    dirty=" dirty"
  else
    dirty=""
  fi
  echo "$lib $sha $branch$dirty"
done > versions.lock

# Local Variables:
# jinx-local-words: "clangd compat env json liblist sha shellcheck tmp usr"
# End:
