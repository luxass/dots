#!/usr/bin/env bats
# Run lock: one dot init or update at a time. acquire_run_lock sets an EXIT
# trap, so tests that take the lock do it in a subshell.

setup() {
  load "../tests/test-helpers"
  load_dot_for_test
}

teardown() {
  if [[ -n "${HOLDER_PID:-}" ]]; then
    kill "$HOLDER_PID" 2>/dev/null || true
  fi
  cleanup_dot_test
}

@test "acquire creates the lock with this PID, and exit releases it" {
  (
    acquire_run_lock
    [ "$(cat "$DOT_RUN_LOCK_DIR/pid")" = "$$" ]
  )
  [ ! -e "$DOT_RUN_LOCK_DIR" ]
}

@test "a lock held by a live process blocks another run" {
  sleep 30 &
  HOLDER_PID=$!
  mkdir -p "$DOT_RUN_LOCK_DIR"
  echo "$HOLDER_PID" >"$DOT_RUN_LOCK_DIR/pid"

  run acquire_run_lock
  [ "$status" -eq 1 ]
  [[ "$output" == *"Another dot run holds the run lock (pid $HOLDER_PID)"* ]]
  [ "$(cat "$DOT_RUN_LOCK_DIR/pid")" = "$HOLDER_PID" ]
}

@test "a lock left by a dead process is taken over" {
  local dead_pid
  sleep 0 &
  dead_pid=$!
  wait "$dead_pid"
  mkdir -p "$DOT_RUN_LOCK_DIR"
  echo "$dead_pid" >"$DOT_RUN_LOCK_DIR/pid"

  (
    acquire_run_lock
    [ "$(cat "$DOT_RUN_LOCK_DIR/pid")" = "$$" ]
  )
}

@test "the same process keeps its own lock, as dot update does after exec" {
  (
    acquire_run_lock
    acquire_run_lock
    [ "$(cat "$DOT_RUN_LOCK_DIR/pid")" = "$$" ]
  )
}

@test "release leaves another process's lock alone" {
  mkdir -p "$DOT_RUN_LOCK_DIR"
  echo 1 >"$DOT_RUN_LOCK_DIR/pid"
  release_run_lock
  [ -d "$DOT_RUN_LOCK_DIR" ]
}
