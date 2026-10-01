# shellcheck shell=bash
# rustup, installed with the official installer.

rust_export_path() {
  local bin="${CARGO_HOME:-$HOME/.cargo}/bin"
  case ":$PATH:" in
    *":$bin:"*) ;;
    *) export PATH="$bin:$PATH" ;;
  esac
}

rust_setup() {
  rust_export_path
  if command_exists rustup; then
    print_success "rustup"
    return 0
  fi

  print_info "Installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || return 1
  hash -r
  command_exists rustup || {
    print_error "rustup installed, but it is not on PATH"
    return 1
  }
  print_success "rustup installed"
}

rust_check() {
  rust_export_path
  if command_exists rustup; then
    print_success "rustup"
  else
    print_warning "rustup is missing; run 'dot init'"
  fi
}
