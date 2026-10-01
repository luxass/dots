# shellcheck shell=bash
# Fish as the login shell, with plugins from the tracked fish_plugins file.

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

  if command_exists fisher && [[ -f "$HOME/.config/fish/fish_plugins" ]]; then
    print_info "Installing Fish plugins from fish_plugins"
    fish -c 'fisher update' || return 1
  fi
}
