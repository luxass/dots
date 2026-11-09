# shellcheck shell=bash
# Fish as the login shell, plus Fisher plugins from the tracked fish_plugins
# file. conf.d/fisher.fish points fisher_path outside the repo.

readonly FISH_PLUGINS_FILE="$HOME/.config/fish/fish_plugins"

fish_setup() {
  local fish login_shell

  fish="$(command -v fish 2>/dev/null)" || {
    print_error "Fish is not installed"
    return 1
  }

  if ! grep -qx "$fish" /etc/shells; then
    print_info "Adding $fish to /etc/shells"
    echo "$fish" | sudo tee -a /etc/shells >/dev/null || return 1
  fi

  login_shell="$(dscl . -read "$HOME" UserShell 2>/dev/null | awk '{ print $2 }')"
  if [[ "$login_shell" == "$fish" ]]; then
    print_success "Fish is the login shell"
  else
    print_info "Setting Fish as the login shell"
    chsh -s "$fish" || return 1
    print_success "Fish is the login shell; restart the terminal to use it"
  fi
}

# Fisher is a Fish function from Homebrew, not a command on PATH.
fish_has_fisher() {
  command_exists fish && fish -c 'functions -q fisher' 2>/dev/null
}

# fish_plugins_missing: plugins listed in fish_plugins that are not installed.
fish_plugins_missing() {
  comm -23 \
    <(grep -Ev '^[[:space:]]*(#|$)' "$FISH_PLUGINS_FILE" | sort -u) \
    <(fish -c 'fisher list' 2>/dev/null | sort -u)
}

fish_deps() {
  local missing

  [[ -f "$FISH_PLUGINS_FILE" ]] || return 0
  fish_has_fisher || {
    print_error "Fisher is missing; it comes from packages/bundle ('dot init')"
    return 1
  }

  missing="$(fish_plugins_missing)"
  if [[ -z "$missing" ]]; then
    print_verbose "Fish plugins are installed"
    return 0
  fi
  print_info "Installing Fish plugins: $(paste -sd ' ' - <<<"$missing")"
  fish -c 'fisher update' >/dev/null || {
    print_error "Failed to install Fish plugins"
    return 1
  }
  print_success "Fish plugins installed"
}

# Install missing plugins, update the rest, and remove unlisted ones.
fish_update_plugins() {
  [[ -f "$FISH_PLUGINS_FILE" ]] && fish_has_fisher || return 0
  print_info "Updating Fish plugins"
  fish -c 'fisher update' >/dev/null || {
    print_error "Failed to update Fish plugins"
    return 1
  }
}

fish_check() {
  local missing

  [[ -f "$FISH_PLUGINS_FILE" ]] || return 0
  if ! fish_has_fisher; then
    print_error "Fisher is missing; run 'dot init'"
    return 1
  fi

  missing="$(fish_plugins_missing)"
  if [[ -n "$missing" ]]; then
    print_error "Fish plugins not installed: $(paste -sd ' ' - <<<"$missing"); run 'dot stow'"
    return 1
  fi
  print_success "Fish plugins"
}
