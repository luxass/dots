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

assert_contains() {
  local output="$1"
  local expected="$2"
  [[ "$output" == *"$expected"* ]] || fail "expected output to contain: $expected"
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"
  [[ "$output" != *"$unexpected"* ]] || fail "expected output not to contain: $unexpected"
}

test_version() {
  local output
  output="$($DOT --version)"
  assert_contains "$output" "dot version 1.3.0"
}

test_help() {
  local output
  output="$($DOT help)"
  assert_contains "$output" "USAGE:"
  assert_contains "$output" "doctor"
  assert_contains "$output" "package"
  assert_contains "$output" "codex"
  assert_not_contains "$output" "retry-failed"
  assert_not_contains "$output" "completions"
  assert_not_contains "$output" "unlink"
}

test_unknown_command_fails() {
  local output status
  set +e
  output="$($DOT definitely-not-a-command 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "unknown command unexpectedly succeeded"
  assert_contains "$output" "Unknown command: definitely-not-a-command"
}

test_global_verbose_option_preserves_dispatch() {
  local output
  output="$($DOT --verbose --version)"
  assert_contains "$output" "dot version 1.3.0"
}

test_option_separator() {
  local output
  output="$($DOT -- --version)"
  assert_contains "$output" "dot version 1.3.0"
}

test_removed_commands_fail() {
  local command status

  for command in links retry-failed link unlink completions edit; do
    set +e
    "$DOT" "$command" >/dev/null 2>&1
    status=$?
    set -e
    [[ "$status" -ne 0 ]] || fail "removed command unexpectedly succeeded: $command"
  done
}

test_package_retry() {
  local output
  output="$($DOT package retry)"
  assert_contains "$output" "No failed package files found"
}

test_cli_runs_through_symlink() {
  local bin output
  bin="$SANDBOX/bin"
  mkdir -p "$bin"
  ln -s "$DOT" "$bin/dot"

  output="$("$bin/dot" --version)"
  assert_contains "$output" "dot version 1.3.0"
}

test_version
test_help
test_unknown_command_fails
test_global_verbose_option_preserves_dispatch
test_option_separator
test_removed_commands_fail
test_package_retry
test_cli_runs_through_symlink
