# shellcheck shell=bash
# Shared setup for dot's bats tests: load "<relative path>/tests/test-helpers".
# Sources dot/bin/dot (functions only, nothing runs) with a throwaway HOME,
# state directory, and packages directory, so tests never touch the real Mac.

DOT_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOT_TEST_BIN="$DOT_TEST_ROOT/bin/dot"

# use_temporary_home: point HOME, XDG_STATE_HOME, and the packages directory
# at a new temporary directory, DOT_TEST_TMP.
use_temporary_home() {
  DOT_TEST_TMP="$(mktemp -d)"
  export HOME="$DOT_TEST_TMP/home"
  export XDG_STATE_HOME="$HOME/.local/state"
  export DOT_PACKAGES_DIR="$DOT_TEST_TMP/packages"
  export NO_COLOR=1
  unset DOT_RUN_LOCK_DIR DOT_LIB_LOADED
  mkdir -p "$HOME" "$DOT_PACKAGES_DIR"
}

# load_dot_for_test: a temporary HOME, then every dot function.
load_dot_for_test() {
  use_temporary_home
  # shellcheck source=../bin/dot
  source "$DOT_TEST_BIN"
}

cleanup_dot_test() {
  if [[ -n "${DOT_TEST_TMP:-}" ]]; then
    rm -rf "$DOT_TEST_TMP"
  fi
}

# reset_components_for_test: forget the real components, so a test can define stubs:
#   reset_components_for_test
#   define_component stub_a required "Stub A"
#   component_stub_a_install() { ...; }
reset_components_for_test() {
  local name
  for name in ${DOT_COMPONENTS[@]+"${DOT_COMPONENTS[@]}"}; do
    unset -f "component_${name}_install" "component_${name}_update" "component_${name}_check"
    unset "DOT_COMPONENT_REQUIREMENT__$name" "DOT_COMPONENT_TITLE__$name"
  done
  DOT_COMPONENTS=()
  DOT_ONLY_COMPONENTS=""
  DOT_SKIP_COMPONENTS=""
}

# relative_path_to_root DIR: print one "../" per component of DIR, so that
# "$(relative_path_to_root DIR)${target#/}" is a relative link from DIR to target.
relative_path_to_root() {
  local dir="$1" up=""
  while [[ "$dir" != / ]]; do
    up+="../"
    dir="$(dirname "$dir")"
  done
  printf '%s\n' "$up"
}

# assert_fails COMMAND...: fail the test when the command succeeds. A bare
# `! command` never fails a bats test, because errexit ignores negated commands.
assert_fails() {
  if "$@"; then
    printf 'expected to fail: %s\n' "$*"
    return 1
  fi
}
