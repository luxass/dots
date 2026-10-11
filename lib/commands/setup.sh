# shellcheck shell=bash
# init, update, stow, and unstow: the commands that change the machine.

# run_steps STEP...: run "required|Name|function" steps with [n/N] progress.
# A failed required step stops the run; a failed optional step is reported
# and the run continues.
run_steps() {
  local step level name fn warnings=0
  STEP_CURRENT=0
  STEP_TOTAL="$#"

  for step in "$@"; do
    IFS='|' read -r level name fn <<<"$step"
    print_step "$name"
    "$fn" && continue
    if [[ "$level" == required ]]; then
      print_error "$name failed; stopping"
      return 1
    fi
    print_warning "$name failed; continuing"
    warnings=$((warnings + 1))
  done

  if [[ "$warnings" -gt 0 ]]; then
    print_warning "Finished with $warnings failed optional step(s); run 'dot doctor'"
    return 1
  fi
  print_success "Done"
}

install_deps() { run_hook deps; }

cmd_init() {
  no_args "$@" || return 1
  print_header "Setting up dotfiles"
  # Dotfiles are linked before pnpm is installed so its install policy applies.
  run_steps \
    "required|Homebrew|homebrew_require" \
    "optional|Homebrew packages|packages_install" \
    "required|Link dotfiles|stow_apply" \
    "optional|Fish shell|fish_setup" \
    "required|pnpm, Node.js, and globals|pnpm_setup" \
    "optional|Rust|rust_setup" \
    "optional|Plugin dependencies|install_deps" \
    "optional|Git hooks and identity|git_setup"
}

# Pull the repo and restart with the new code when it changed.
update_repo() {
  local before

  repo_is_git || return 0
  before="$(repo_git rev-parse HEAD)"
  print_info "Pulling latest changes"
  repo_git pull --ff-only || return 1

  if [[ "$(repo_git rev-parse HEAD)" != "$before" && "${DOT_UPDATE_REEXECED:-}" != true ]]; then
    print_info "Restarting with the updated dot"
    DOT_VERBOSE="$DOT_VERBOSE" DOT_YES="$DOT_YES" DOT_UPDATE_REEXECED=true \
      exec "$DOTFILES_DIR/dot" update
  fi
}

cmd_update() {
  local failed=0

  no_args "$@" || return 1
  print_header "Updating dotfiles"
  update_repo || return 1
  homebrew_require || return 1

  print_section "Runtimes"
  pnpm_update || failed=1
  pi_update_self || failed=1

  print_section "Homebrew"
  brew update || failed=1
  homebrew_upgrade || failed=1
  packages_install || failed=1

  print_section "Dotfiles"
  stow_apply || failed=1
  fish_update_plugins || failed=1
  install_deps || failed=1
  pi_update_extensions || failed=1
  opencode_update_plugins || failed=1

  if [[ "$failed" -eq 0 ]]; then
    print_success "Update complete"
  else
    print_warning "Update finished with errors; run 'dot doctor'"
  fi
  return "$failed"
}

cmd_stow() {
  no_args "$@" || return 1
  print_header "Linking dotfiles"
  stow_apply && install_deps
}

cmd_unstow() {
  no_args "$@" || return 1
  print_header "Unlinking dotfiles"
  stow_remove
}
