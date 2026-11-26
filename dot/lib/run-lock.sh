# shellcheck shell=bash
# Run lock: only one `dot init` or `dot update` runs at a time on this Mac.
# A directory is the lock, because mkdir is atomic and macOS has no flock.

DOT_RUN_LOCK_DIR="${DOT_RUN_LOCK_DIR:-$STATE_DIR/run.lock}"

# acquire_run_lock: take the run lock or fail. It is released when dot exits.
# `dot update` re-executes itself after a pull. exec keeps the PID, so the new
# process finds its own PID in the lock and keeps it.
acquire_run_lock() {
  local holder

  mkdir -p "$(dirname "$DOT_RUN_LOCK_DIR")" || return 1
  if ! mkdir "$DOT_RUN_LOCK_DIR" 2>/dev/null; then
    holder="$(cat "$DOT_RUN_LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ "$holder" == "$$" ]]; then
      trap release_run_lock EXIT
      return 0
    fi
    if [[ -z "$holder" ]] || kill -0 "$holder" 2>/dev/null; then
      print_error "Another dot run holds the run lock (pid ${holder:-unknown}): $(pretty_path "$DOT_RUN_LOCK_DIR")"
      print_info "If no dot run is active, remove that directory and try again"
      return 1
    fi
    print_warning "Removing a stale dot run lock left by pid $holder"
    rm -rf "$DOT_RUN_LOCK_DIR" || return 1
    if ! mkdir "$DOT_RUN_LOCK_DIR" 2>/dev/null; then
      print_error "Another dot run took the run lock: $(pretty_path "$DOT_RUN_LOCK_DIR")"
      return 1
    fi
  fi

  printf '%s\n' "$$" >"$DOT_RUN_LOCK_DIR/pid" || return 1
  trap release_run_lock EXIT
}

# release_run_lock: remove the run lock if this process holds it.
release_run_lock() {
  if [[ "$(cat "$DOT_RUN_LOCK_DIR/pid" 2>/dev/null || true)" == "$$" ]]; then
    rm -rf "$DOT_RUN_LOCK_DIR"
  fi
}
