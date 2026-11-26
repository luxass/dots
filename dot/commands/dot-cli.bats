#!/usr/bin/env bats
# The dot command line, run as a real process with set -euo pipefail.
# Only commands that change nothing: help, usage, components, and dry runs.

setup() {
  load "../tests/test-helpers"
  use_temporary_home
}

teardown() {
  cleanup_dot_test
}

@test "dot --version" {
  run "$DOT_TEST_BIN" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "dot "* ]]
}

@test "dot with no command shows help listing every command" {
  run "$DOT_TEST_BIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"init "*"update "*"doctor "*"components "*"package "* ]]
}

@test "every listed command exists and has --help" {
  local summary name
  # shellcheck source=../bin/dot
  source "$DOT_TEST_BIN"
  for summary in "${DOT_COMMAND_SUMMARIES[@]}"; do
    name="${summary%%|*}"
    run "$DOT_TEST_BIN" "$name" --help
    [ "$status" -eq 0 ] || {
      echo "no help for $name"
      return 1
    }
    [[ "$output" == *"USAGE"* ]]
  done
}

@test "unknown commands and usage functions are not commands" {
  run "$DOT_TEST_BIN" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command: bogus"* ]]

  run "$DOT_TEST_BIN" init-usage
  [ "$status" -eq 1 ]
}

@test "dot components --names prints the run order" {
  local expected
  run "$DOT_TEST_BIN" components --names
  [ "$status" -eq 0 ]
  expected="$(bash -c 'source "$1"; printf "%s\n" "${DOT_COMPONENT_ORDER[@]}"' _ "$DOT_TEST_BIN")"
  [ "$output" = "$expected" ]
}

@test "dot init --dry-run changes nothing" {
  run "$DOT_TEST_BIN" init --dry-run --only stow,skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would run component_stow_install"* ]]
  [[ "$output" == *"Would run component_skills_install"* ]]
  [ ! -e "$XDG_STATE_HOME/dot/run.lock" ]
  [ -z "$(find "$HOME" -type l)" ]
}

@test "an unknown component name fails before anything runs" {
  run "$DOT_TEST_BIN" update --only stow,nope --no-pull
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown component 'nope' in --only"* ]]
}
