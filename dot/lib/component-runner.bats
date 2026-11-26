#!/usr/bin/env bats
# Component runner: phase order, required and optional failures, and dry runs.
# shellcheck disable=SC2329 # the runner calls the stub components by name

setup() {
  load "../tests/test-helpers"
  load_dot_for_test
  reset_components_for_test
  RUN_LOG="$DOT_TEST_TMP/run.log"
  : >"$RUN_LOG"

  define_component stub_first required "First"
  component_stub_first_install() { echo "first install" >>"$RUN_LOG"; }
  component_stub_first_update() { echo "first update" >>"$RUN_LOG"; }
  component_stub_first_check() { echo "first check" >>"$RUN_LOG"; }

  define_component stub_optional optional "Optional"
  component_stub_optional_install() {
    echo "optional install" >>"$RUN_LOG"
    return 1
  }
  component_stub_optional_check() {
    echo "optional check" >>"$RUN_LOG"
    return 1
  }

  define_component stub_last required "Last"
  component_stub_last_install() { echo "last install" >>"$RUN_LOG"; }
  component_stub_last_check() { echo "last check" >>"$RUN_LOG"; }
}

teardown() {
  cleanup_dot_test
}

@test "install runs every component in order and continues past optional failures" {
  run run_component_phase install
  [ "$status" -eq 0 ]
  [ "$(cat "$RUN_LOG")" = $'first install\noptional install\nlast install' ]
  [[ "$output" == *"stub_optional"*"failed"* ]]
}

@test "a failed required component stops install" {
  component_stub_first_install() {
    echo "first install" >>"$RUN_LOG"
    return 1
  }
  run run_component_phase install
  [ "$status" -eq 1 ]
  [ "$(cat "$RUN_LOG")" = "first install" ]
  [[ "$output" == *"Required component stub_first failed; stopping"* ]]
}

@test "update runs install for components without an update step" {
  run run_component_phase update
  [ "$status" -eq 0 ]
  [ "$(cat "$RUN_LOG")" = $'first update\noptional install\nlast install' ]
}

@test "check runs every component after a required one fails, then fails" {
  component_stub_first_check() {
    echo "first check" >>"$RUN_LOG"
    return 1
  }
  run run_component_phase check
  [ "$status" -eq 1 ]
  [ "$(cat "$RUN_LOG")" = $'first check\noptional check\nlast check' ]
}

@test "a failed optional check does not fail check" {
  run run_component_phase check
  [ "$status" -eq 0 ]
}

@test "a step that prints a warning is marked warnings in the summary" {
  component_stub_last_install() { print_warning "something to look at"; }
  run run_component_phase install
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub_last"*"warnings"* ]]
}

@test "dry run prints the plan and runs nothing" {
  DOT_DRY_RUN=true
  run run_component_phase install
  [ "$status" -eq 0 ]
  [ ! -s "$RUN_LOG" ]
  [[ "$output" == *"Would run component_stub_first_install"* ]]
}

@test "--only limits the phase to the selected components" {
  select_components "stub_last" ""
  run run_component_phase install
  [ "$status" -eq 0 ]
  [ "$(cat "$RUN_LOG")" = "last install" ]
}
