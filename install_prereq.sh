#!/usr/bin/env bash
#
# Install or check the packages required to build the mi-lib workspace.
#
# Usage:
#   ./install_prereq.sh          # Install required packages (uses sudo)
#   ./install_prereq.sh --check  # Only report missing prerequisites (no sudo)

set -euo pipefail

### (for download & compilation)
BUILD_PKGS=(git wget unzip rename make gcc fakeroot pkg-config)
### (for ZEDA & X11 & OpenGL)
LIB_PKGS=(libxml2-dev liblzf-dev xorg-dev libxft-dev libfreetype-dev libtiff-dev libjpeg-dev libwebp-dev libmagickwand-dev freeglut3-dev libglew-dev libglfw3-dev)
### (for generating compile_commands.json)
TOOL_PKGS=(bear)
### (recommended: per-directory PATH/LD_LIBRARY_PATH for ~/usr)
RECOMMENDED_PKGS=(direnv)

CHECK=false
if [[ $# -gt 0 ]]; then
  case "$1" in
    --check|-c)
      CHECK=true
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--check]"
      exit 1
      ;;
  esac
fi

if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg-query >/dev/null 2>&1; then
  echo "❌ This script supports Debian/Ubuntu (apt) only; install the equivalent packages manually on other systems."
  exit 1
fi

installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

if $CHECK; then
  MISSING=""
  for p in "${BUILD_PKGS[@]}" "${LIB_PKGS[@]}" "${TOOL_PKGS[@]}"; do
    installed "$p" || MISSING="$MISSING $p"
  done
  command -v compdb >/dev/null 2>&1 || MISSING="$MISSING compdb(pip)"
  RECOMMENDED=""
  for p in "${RECOMMENDED_PKGS[@]}"; do
    installed "$p" || RECOMMENDED="$RECOMMENDED $p"
  done
  [ -n "$RECOMMENDED" ] && echo "⚠️  Recommended but not installed:$RECOMMENDED"
  if [ -n "$MISSING" ]; then
    echo "❌ Missing prerequisites:$MISSING"
    echo "💡 Run $0 to install packages; install compdb with: pip install --user compdb"
    exit 1
  fi
  echo "✅ All prerequisites are installed."
  exit 0
fi

echo "installing required packages..."
sudo apt-get install -y "${BUILD_PKGS[@]}" "${LIB_PKGS[@]}" "${TOOL_PKGS[@]}" "${RECOMMENDED_PKGS[@]}"

if ! command -v compdb >/dev/null 2>&1; then
  echo "❌ compdb is still missing (build_compile_commands.sh needs it); install it with: pip install --user compdb"
  exit 1
fi
echo "✅ All prerequisites are installed."

# Local Variables:
# jinx-local-words: "env pkg prereq sudo"
# End:
