# shellcheck shell=bash
# Local OpenCode plugin dependencies and native package-plugin updates.

opencode_prestow() {
  migrate_opencode_private_links
}

opencode_deps() {
  PNPM_CONFIG_MINIMUM_RELEASE_AGE=0 pnpm_install_deps "$HOME/.config/opencode" "OpenCode plugin"
}

opencode_update_plugins() {
  local prefix binary age

  command_exists brew || return 0
  prefix="$(brew --prefix opencode-v2 2>/dev/null)" || return 0
  binary="$prefix/bin/opencode"
  if [[ ! -x "$binary" ]]; then
    print_warning "OpenCode is missing; skipping plugin updates"
    return 0
  fi
  confirm "Update installed OpenCode package plugins?" n || return 0

  # Server plugins update in the persistent server, not this CLI process.
  age="$("$binary" service get env NPM_CONFIG_MIN_RELEASE_AGE)" || {
    print_error "Could not read OpenCode service release-age policy"
    return 1
  }
  if [[ "$age" != 0 ]]; then
    print_error "Close OpenCode sessions, then run: '$binary' service set env NPM_CONFIG_MIN_RELEASE_AGE 0"
    print_info "This stops the OpenCode background server and exempts only its installs from the age policy"
    return 1
  fi

  # CLI-only plugins install locally; keep their override scoped to this command.
  if ! (cd "$DOTFILES_DIR" && NPM_CONFIG_MIN_RELEASE_AGE=0 sfw "$binary" plugin update); then
    print_error "Failed to update OpenCode package plugins"
    return 1
  fi
  print_success "OpenCode package plugins updated"
}

opencode_check() {
  [[ -f "$HOME/.config/opencode/package.json" ]] || return 0
  if [[ -d "$HOME/.config/opencode/node_modules/@opencode/plugin" ]]; then
    print_success "OpenCode plugin dependencies"
  else
    print_error "OpenCode plugin dependencies are missing; run 'dot stow'"
    return 1
  fi
}
