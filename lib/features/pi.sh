# shellcheck shell=bash
# Pi: public extension dependencies in ~/.pi and updates.

# Only public preferences and customizations belong in the checkout.
pi_prestow() {
  local entry name

  local_config_dir .pi || return 1
  local_config_dir .pi/agent || return 1
  for entry in "$LEGACY_HOME_DIR/.pi/agent"/* "$LEGACY_HOME_DIR/.pi/agent"/.[!.]* "$LEGACY_HOME_DIR/.pi/agent"/..?*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name="${entry##*/}"
    case "$name" in
      settings.json | mcp.json | cloak.json | AGENTS.md | voice-settings.json | package.json | tsconfig.json | themes | extensions) continue ;;
    esac
    local_state_move ".pi/agent/$name" || return 1
  done
  local_state_move .pi/todos || return 1
  if [[ -e "$LEGACY_HOME_DIR/.pi/.pi/todos" || -L "$LEGACY_HOME_DIR/.pi/.pi/todos" ]]; then
    local_config_dir .pi/.pi || return 1
    local_state_move .pi/.pi/todos || return 1
  fi
  return 0
}

pi_deps() {
  pnpm_install_deps "$HOME/.pi" "Pi extension"
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
  NPM_CONFIG_MIN_RELEASE_AGE=0 PNPM_CONFIG_MINIMUM_RELEASE_AGE=0 sfw pi update --extensions || {
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
  return "$failed"
}
