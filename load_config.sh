#!/usr/bin/env bash
#
# load_config.sh -- single entry point for the workspace configuration.
#
#   . ./load_config.sh            # from scripts: sets variables and helpers
#   ./load_config.sh --get VAR    # print one resolved variable (Makefile)
#
# config.default is sourced first, then config.local unless CI=true
# (config.local is also gitignored, so CI checkouts never contain it).
# Precedence: environment > config.local > config.default.
#
# This file is sourced into scripts running under `set -euo pipefail`:
# use only `if` forms (no `[ ... ] && ...` line-enders) and tolerate
# unset variables.
#
# shellcheck disable=SC2034  # LIBS etc. are consumed by sourcing scripts

MILIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

_MILIB_VARS="UPSTREAM_LIBS CUSTOM_LIB CUSTOM_LIB_DEPS CPP_LIBS \
CUSTOM_TEST_CMD UPSTREAM_OWNER OWNER CUSTOM_LIB_OWNER GIT_PROTOCOL \
PREFIX ENVRC_DIR APP_DIRS COMPILE_DB VERSIONS_LOCK"

# Remember which variables the caller already set in the environment.
for _v in $_MILIB_VARS; do
  eval "_milib_env_$_v=\${$_v-__milib_unset__}"
done

# shellcheck source=config.default
. "$MILIB_ROOT/config.default"
if [ "${CI:-}" != "true" ] && [ -f "$MILIB_ROOT/config.local" ]; then
  # shellcheck source=/dev/null
  . "$MILIB_ROOT/config.local"
fi

# Re-apply environment values (highest precedence).
for _v in $_MILIB_VARS; do
  eval "_e=\$_milib_env_$_v"
  # shellcheck disable=SC2154  # _e is assigned via eval above
  if [ "$_e" != "__milib_unset__" ]; then
    eval "$_v=\$_e"
  fi
done
unset _v _e

### Derived values ###################################################

_milib_origin_url() {
  git -C "$MILIB_ROOT" remote get-url origin 2>/dev/null || true
}

_milib_origin_owner() {
  _milib_origin_url | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#'
}

if [ -z "${OWNER:-}" ]; then
  OWNER="$(_milib_origin_owner)"
fi
if [ -z "${CUSTOM_LIB_OWNER:-}" ]; then
  CUSTOM_LIB_OWNER="$(_milib_origin_owner)"
fi
if [ -z "${GIT_PROTOCOL:-}" ]; then
  case "$(_milib_origin_url)" in
    git@* | ssh://*) GIT_PROTOCOL="ssh" ;;
    *) GIT_PROTOCOL="https" ;;
  esac
fi
case "$GIT_PROTOCOL" in
  ssh | https) ;;
  *)
    echo "❌ GIT_PROTOCOL must be \"ssh\" or \"https\" (or empty to derive): $GIT_PROTOCOL" >&2
    exit 1
    ;;
esac
if [ -z "${COMPILE_DB:-}" ]; then
  COMPILE_DB="$MILIB_ROOT/compile_commands.json"
fi
case "$VERSIONS_LOCK" in
  /*) ;;
  *) VERSIONS_LOCK="$MILIB_ROOT/$VERSIONS_LOCK" ;;
esac
if [ -n "${CUSTOM_LIB:-}" ]; then
  LIBS="$UPSTREAM_LIBS $CUSTOM_LIB"
else
  LIBS="$UPSTREAM_LIBS"
fi
# Effective CPP_LIBS: entries outside UPSTREAM_LIBS are dropped, so a
# configuration that lists only a few libraries keeps working with the
# tracked default.
_cpp_libs=""
for _l in ${CPP_LIBS:-}; do
  case " $UPSTREAM_LIBS " in
    *" $_l "*) _cpp_libs="$_cpp_libs $_l" ;;
  esac
done
CPP_LIBS="${_cpp_libs# }"
unset _l _cpp_libs

### Helpers ##########################################################

# milib_repo_url <owner> <repo>: clone URL for the configured protocol.
milib_repo_url() {
  if [ "$GIT_PROTOCOL" = "ssh" ]; then
    echo "git@github.com:$1/$2.git"
  else
    echo "https://github.com/$1/$2.git"
  fi
}

# True when the original repositories are tracked directly (no forks).
milib_forkless() {
  [ "$OWNER" = "$UPSTREAM_OWNER" ]
}

### --get mode (only when executed, not sourced) #####################

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  if [ "${1:-}" = "--get" ] && [ -n "${2:-}" ]; then
    eval "printf '%s\n' \"\${$2:-}\""
  else
    echo "Usage: $0 --get VARIABLE" >&2
    exit 1
  fi
fi

# Local Variables:
# jinx-local-words: "config env gitignored"
# End:
