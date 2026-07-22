_count_init_tool() {
  local skip="$5"
  tool_is_skipped "$skip" || ((++TOTAL_STEPS))
}

_install_tool() {
  local name="$1"
  local check="$2"
  local installer="$3"
  local required="$4"
  local skip="$5"

  tool_is_skipped "$skip" && return 0

  print_step "$name"
  if [[ "$installer" != "-" ]]; then
    if "$installer"; then
      return 0
    elif [[ "$required" == "true" ]]; then
      return 1
    else
      print_warning "$name failed; continuing"
    fi
  elif [[ "$check" != "-" ]] && command_exists "$check"; then
    print_success "$name is installed"
  elif [[ "$required" == "true" ]]; then
    print_error "$name is missing"
    return 1
  else
    print_warning "$name is missing"
  fi
}

run_init_steps() {
  TOTAL_STEPS=0
  for_each_tool _count_init_tool

  CURRENT_STEP=0
  for_each_tool _install_tool
}

_doctor_check_tool() {
  local name="$1"
  local check="$2"
  local required="$4"
  local doctor="$6"

  [[ "$doctor" == "true" && "$check" != "-" ]] || return 0

  if command_exists "$check"; then
    print_success "$name"
  elif [[ "$required" == "true" ]]; then
    print_error "$name is missing"
    DOCTOR_TOOL_FAILED=1
  else
    print_warning "$name is missing"
  fi
}

_setup_fish_shell() {
  if ! command_exists fish; then
    print_warning "Fish is not installed"
    return 1
  fi

  local fish_path
  fish_path="$(command -v fish)"

  if ! grep -qx "$fish_path" /etc/shells; then
    print_info "Adding Fish to /etc/shells"
    echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
  fi

  if [[ "${SHELL:-}" != "$fish_path" ]]; then
    print_info "Setting Fish as the default shell"
    chsh -s "$fish_path"
    print_success "Default shell set to Fish; restart the terminal to use it"
  else
    print_success "Fish is already the default shell"
  fi

  if command_exists fisher; then
    print_info "Installing Fish plugins"
    fish -c "fisher install jhillyerd/plugin-git"
  fi
}

cmd_init() {
  print_header "Initializing dotfiles"
  run_init_steps
}

cmd_update() {
  print_header "Updating dotfiles"

  if git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local old_head new_head
    old_head="$(git -C "$DOTFILES_DIR" rev-parse HEAD)"

    print_info "Pulling latest repo changes"
    git -C "$DOTFILES_DIR" pull --ff-only

    new_head="$(git -C "$DOTFILES_DIR" rev-parse HEAD)"
    if [[ "$old_head" != "$new_head" && "${DOT_UPDATE_REEXECED:-false}" != "true" ]]; then
      print_info "Restarting dot update with latest code"
      DOT_UPDATE_REEXECED=true exec "$DOTFILES_DIR/dot" update "$@"
    fi
  fi

  print_info "Updating Homebrew"
  brew update
  _install_packages
  _stow_dotfiles

}

cmd_info() {
  print_header "Dotfiles"
  echo "Version:            $VERSION"
  echo "Dotfiles directory: $DOTFILES_DIR"
  echo "Home package:       $HOME_DIR"
  echo "Packages:           $PACKAGES_DIR"
  echo "Backups:            $BACKUP_ROOT"
  echo

  print_header "Runtime"
  printf "Homebrew:           "
  command_exists brew && command -v brew || echo "missing"
  printf "Vite+:              "
  command_exists vp && command -v vp || echo "missing"
  printf "Node.js:            "
  command_exists node && node --version || echo "missing"
  printf "npm:                "
  command_exists npm && npm --version || echo "missing"
  printf "Bun:                "
  command_exists bun && bun --version || echo "missing"
  printf "Fish:               "
  command_exists fish && fish --version || echo "missing"
  echo

  print_header "Git"
  if git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$DOTFILES_DIR" status --short --branch
    git -C "$DOTFILES_DIR" remote -v
  else
    print_warning "$DOTFILES_DIR is not a git repository"
  fi
}

cmd_doctor() {
  parse_verbose_args "$@" || return 1
  print_header "Running diagnostics"

  local failed=0

  print_verbose "Checking registered tool dependencies"
  DOCTOR_TOOL_FAILED=0
  for_each_tool _doctor_check_tool
  [[ "$DOCTOR_TOOL_FAILED" -eq 0 ]] || failed=1

  print_verbose "Checking repository layout and executable bits"
  [[ -d "$HOME_DIR" ]] || { print_error "Missing $HOME_DIR"; failed=1; }
  [[ -f "$BASE_BUNDLE" ]] || { print_error "Missing $BASE_BUNDLE"; failed=1; }
  [[ -x "$DOTFILES_DIR/dot" ]] || { print_error "dot is not executable"; failed=1; }
  [[ -x "$DOTFILES_DIR/.githooks/pre-push" ]] || { print_error "pre-push hook is not executable"; failed=1; }

  print_verbose "Checking Git hook configuration"
  if git_hooks_enabled; then
    print_success "Git hooks path"
  else
    print_warning "Git hooks path is not .githooks; run 'dot hooks'"
  fi

  print_verbose "Checking local Git identity configuration"
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    print_success "Git identity config"
  else
    print_warning "Missing ~/.gitconfig.local"
  fi

  print_verbose "Checking managed home symlinks"
  check_managed_links || failed=1
  check_agent_skills_link || failed=1

  print_verbose "Checking portable Codex preferences"
  check_codex_config || failed=1

  print_verbose "Checking shell PATH entries"
  if path_contains "$HOME/.local/bin"; then
    print_success "~/.local/bin is on PATH"
  else
    print_warning "~/.local/bin is not on PATH"
  fi

  print_verbose "Checking Vite+-managed runtime origins"
  check_runtime_origins || failed=1

  print_verbose "Checking package-manager policy files"
  check_package_manager_policy || failed=1

  print_verbose "Checking Homebrew bundle state"
  if ! brew_bundle_check "$BASE_BUNDLE"; then
    failed=1
  fi

  print_verbose "Running repository secret scan"
  if secret_scan; then
    print_error "Possible secrets found"
    failed=1
  else
    print_success "Secret scan passed"
  fi

  if [[ "$failed" -eq 0 ]]; then
    print_success "dotfiles look healthy"
  fi

  return "$failed"
}
