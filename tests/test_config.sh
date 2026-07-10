#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOT="$ROOT/dot"
readonly SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_STATE_HOME="$SANDBOX/state"
mkdir -p "$HOME"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  return 1
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

test_config_lifecycle() {
  "$DOT" config set packages.brew.fonts.enabled yes
  assert_equals "$("$DOT" config get packages.brew.fonts.enabled)" "true"
  assert_equals "$("$DOT" config list)" "packages.brew.fonts.enabled=true"

  "$DOT" config unset packages.brew.fonts.enabled
  if "$DOT" config get packages.brew.fonts.enabled >/dev/null 2>&1; then
    fail "unset key remained readable"
  fi
}

test_invalid_boolean_fails() {
  if "$DOT" config set packages.brew.work.enabled perhaps >/dev/null 2>&1; then
    fail "invalid boolean unexpectedly succeeded"
  fi
}

test_invalid_key_fails() {
  if "$DOT" config set Invalid-Key value >/dev/null 2>&1; then
    fail "invalid key unexpectedly succeeded"
  fi
}

test_config_lifecycle
test_invalid_boolean_fails
test_invalid_key_fails
