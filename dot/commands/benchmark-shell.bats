#!/usr/bin/env bats
# dot benchmark-shell: parsing Fish `time` reports and summarizing startup
# times. These tests never start Fish, so CI does not need it.

setup() {
  load "../tests/test-helpers"
  load_dot_for_test
}

teardown() {
  cleanup_dot_test
}

@test "fish_time_report_ms converts every unit to milliseconds and skips other lines" {
  local report
  report="$(
    cat <<'EOF'

________________________________________________________
Executed in   99.70 millis    fish           external
   usr time   31.91 millis   68.00 micros   31.84 millis
Executed in   23.00 micros    fish           external
Executed in    1.21 secs      fish           external
Executed in    2.00 mins      fish           external
EOF
  )"
  [ "$(fish_time_report_ms <<<"$report")" = $'99.70\n0.02\n1210.00\n120000.00' ]
}

@test "fish_time_report_ms fails on a unit it does not know" {
  run fish_time_report_ms <<<"Executed in   3.00 hours    fish           external"
  [ "$status" -eq 1 ]
}

@test "startup_time_summary prints fastest, median, mean, and slowest" {
  [ "$(printf '%s\n' 30 10 20 | startup_time_summary)" = "10.0 20.0 20.0 30.0" ]
  [ "$(printf '%s\n' 40 10 30 20 | startup_time_summary)" = "10.0 25.0 25.0 40.0" ]
}

@test "startup_time_summary fails without any times" {
  run startup_time_summary </dev/null
  [ "$status" -eq 1 ]
}

@test "dot benchmark-shell rejects run counts outside 1-100" {
  local runs
  for runs in 0 101 abc; do
    run "$DOT_TEST_BIN" benchmark-shell --runs "$runs"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Runs must be a number from 1 to 100"* ]]
  done
}
