ensure_private_pi_package() {
  local private_dir="$PRIVATE_PI_DIR"

  command_exists pi || return 0
  [[ -d "$private_dir/extensions" ]] || return 0

  if pi list 2>/dev/null | grep -q "private/pi"; then
    print_verbose "Private Pi package is installed"
    return 0
  fi

  print_info "Installing private Pi package"
  if pi install "$private_dir" >/dev/null 2>&1; then
    print_success "Private Pi package installed"
  else
    print_warning "Failed to install private Pi package (run 'pi install $private_dir')"
  fi
}

ensure_private_pi_submodule() {
  local private_dir="$PRIVATE_PI_DIR"

  if [[ ! -f "$DOTFILES_DIR/.gitmodules" ]] || ! git -C "$DOTFILES_DIR" config -f .gitmodules --get submodule.private/pi.path >/dev/null 2>&1; then
    return 0
  fi

  if [[ -d "$private_dir/.git" || -f "$private_dir/.git" ]]; then
    print_verbose "Private Pi submodule is available"
  else
    print_info "Initializing private Pi submodule"
  fi

  git -C "$DOTFILES_DIR" submodule update --init --recursive private/pi
}

ensure_pi_extension_deps() {
  local home_pi="$HOME/.pi"

  # Transitive postinstalls flagged by the default-deny build policy.
  # Approve them explicitly (recorded in pnpm-workspace.yaml) like the
  # global --allow-build precedent in lib/runtime.sh.
  if command_exists pnpm; then
    local dir
    for dir in "$home_pi" "$HOME_DIR/.pi"; do
      if [[ -f "$dir/package.json" ]]; then
        (cd "$dir" && pnpm approve-builds @google/genai protobufjs >/dev/null 2>&1) || true
      fi
    done
  fi

  if [[ -f "$home_pi/package.json" ]]; then
    stow_install_pnpm_deps "$home_pi" "Pi plugin"
  elif [[ -f "$HOME_DIR/.pi/package.json" ]]; then
    stow_install_pnpm_deps "$HOME_DIR/.pi" "Pi plugin"
  fi
}

check_pi_extension_deps() {
  local failed=0
  local home_pi="$HOME/.pi"

  if [[ -f "$home_pi/package.json" ]]; then
    if [[ -d "$home_pi/node_modules/@earendil-works/pi-coding-agent" ]]; then
      print_success "Pi extension dependencies"
    else
      print_error "Pi extension dependencies missing in $home_pi (run 'dot stow')"
      failed=1
    fi
  fi

  if command_exists pi; then
    if pi list 2>/dev/null | grep -qE "luxass/pi-private|private/pi"; then
      print_success "Private Pi extensions installed"
    else
      print_error "Private Pi extensions missing (run 'pi install git:github.com/luxass/pi-private')"
      failed=1
    fi
  fi

  return "$failed"
}
