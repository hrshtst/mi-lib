#!/usr/bin/env bash

. "liblist"
JSON="$(pwd)/compile_commands.json"
make clean
for lib in $LIBS; do
  cd "$lib" || continue
  git fetch origin compat/bear >/dev/null 2>&1
  git checkout compat/bear 2>/dev/null || {
    echo "❌  Failed to checkout 'compat/bear' in $lib"
  }
  cd ..
done

bear -- make
cd pedi2/test || exit
bear --append --output "$JSON" -- make
cd ../app/dynmorph || exit
bear --append --output "$JSON" -- make
cd ../joystick || exit
bear --append --output "$JSON" -- make
cd ../.. || exit
compdb -p . list | sponge compile_commands.json

# Local Variables:
# jinx-local-words: "compat env json liblist usr"
# End:
