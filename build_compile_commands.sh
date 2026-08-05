#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
JSON="$(pwd)/compile_commands.json"

make clean
bear -- make

# The top-level Makefile does not build pedi2's test suite and app
# subdirectories; capture them separately. The app directories are not
# covered by `make clean`, so force recompilation with -B lest bear
# miss their sources when they are up to date.
cd pedi2/test
if [ ! -d gtest ]; then
  unzip archive/gtest-1.7.0.zip
  mv gtest-1.7.0 gtest
fi
bear --append --output "$JSON" -- make
cd ../app/dynmorph
bear --append --output "$JSON" -- make -B
cd ../joystick
bear --append --output "$JSON" -- make -B
cd ../../..

# Add header entries for clangd.
compdb -p . list > "$JSON.tmp"
mv "$JSON.tmp" "$JSON"

# Local Variables:
# jinx-local-words: "compdb env gtest json pedi2"
# End:
