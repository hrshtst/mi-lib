#!/usr/bin/env bash

set -e

. "liblist"
JSON="$(pwd)/compile_commands.json"
make clean
for lib in $LIBS; do
  echo "==> Processing $lib"
  cd "$lib" || continue
  echo "Checking out branch 'compat/bear'..."
  # git fetch origin compat/bear >/dev/null 2>&1
  git checkout compat/bear 2>/dev/null || {
    echo "❌  Failed to checkout 'compat/bear' in $lib"
  }
  cd ..
done

bear -- make
cd pedi2/test || exit
if [ ! -d gtest ]; then
  unzip archive/gtest-1.7.0.zip
  mv gtest-1.7.0 gtest
fi
bear --append --output "$JSON" -- make
cd ../app/dynmorph || exit
bear --append --output "$JSON" -- make
cd ../joystick || exit
bear --append --output "$JSON" -- make
cd ../.. || exit
if ! command -v sponge &> /dev/null; then
  sudo apt install moreutils
fi
compdb -p . list | sponge compile_commands.json

for lib in $LIBS; do
  cd "$lib" || continue
  git checkout main 2>/dev/null || {
    echo "❌  Failed to checkout 'main' in $lib"
  }
  cd ..
done

# Local Variables:
# jinx-local-words: "compat env json liblist usr"
# End:
