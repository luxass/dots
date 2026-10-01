# shellcheck shell=bash
# Pi: extension dependencies in ~/.pi, the private/pi package, and updates.

pi_poststow() {
  submodule_sync private/pi
}

pi_deps() {
  local failed=0
  pnpm_install_deps "$HOME/.pi" "Pi extension" || failed=1

  # The private package loads in place from the submodule (a local-path install).
  if command_exists pi && [[ -d "$PRIVATE_PI_DIR/extensions" ]] && ! pi list 2>/dev/null | grep -q 'private/pi'; then
    print_info "Installing the private Pi package"
    if ! pi install "$PRIVATE_PI_DIR" >/dev/null; then
      print_error "Failed to install the private Pi package; run 'pi install $PRIVATE_PI_DIR'"
      failed=1
    fi
  fi
  return "$failed"
}

# Pi's camelCase pnpm flag doesn't override pnpm 12's release-age policy, so
# both updates set the supported env override for that one command.
pi_update_self() {
  if ! command_exists pi; then
    print_warning "Pi is missing; skipping its update"
    return 0
  fi
  PNPM_CONFIG_MINIMUM_RELEASE_AGE=0 sfw pi update --self || {
    print_error "Failed to update Pi"
    return 1
  }
}

pi_update_extensions() {
  command_exists pi || return 0
  confirm "Update installed Pi extension packages?" n || return 0
  PNPM_CONFIG_MINIMUM_RELEASE_AGE=0 sfw pi update --extensions || {
    print_error "Failed to update Pi extensions"
    return 1
  }
  print_success "Pi extensions updated"
}

pi_check() {
  local failed=0

  if [[ -f "$HOME/.pi/package.json" ]]; then
    if [[ -d "$HOME/.pi/node_modules/@earendil-works/pi-coding-agent" ]]; then
      print_success "Pi extension dependencies"
    else
      print_error "Pi extension dependencies are missing; run 'dot stow'"
      failed=1
    fi
  fi

  if command_exists pi && [[ -d "$PRIVATE_PI_DIR/extensions" ]]; then
    if pi list 2>/dev/null | grep -q 'private/pi'; then
      print_success "Private Pi package"
    else
      print_error "Private Pi package is not installed; run 'dot stow'"
      failed=1
    fi
  fi
  return "$failed"
}
