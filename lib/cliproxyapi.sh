# CLIProxyAPI runner. Runs in the foreground in the current shell with the
# stowed config; not managed as a brew service.

ensure_cliproxyapi_config_link() {
  local brew_prefix etc_dir brew_conf
  local target="$HOME/.config/cliproxyapi/config.yaml"

  brew_prefix="$(brew --prefix 2>/dev/null)" || return 0
  etc_dir="$brew_prefix/etc"
  brew_conf="$etc_dir/cliproxyapi.conf"

  [[ -d "$etc_dir" ]] || return 0

  if [[ -L "$brew_conf" ]]; then
    if [[ "$(realpath "$brew_conf")" == "$(realpath "$target")" ]]; then
      return 0
    fi
    rm "$brew_conf"
  elif [[ -e "$brew_conf" ]]; then
    backup_path "$brew_conf" "$BACKUP_ROOT/$(timestamp)"
  fi

  ln -s "$target" "$brew_conf"
  print_success "Linked cliproxyapi brew config -> ~/.config/cliproxyapi/config.yaml"
}

check_cliproxyapi_config_link() {
  local brew_prefix brew_conf
  local target="$HOME/.config/cliproxyapi/config.yaml"

  brew_prefix="$(brew --prefix 2>/dev/null)" || return 0
  brew_conf="$brew_prefix/etc/cliproxyapi.conf"

  if [[ -L "$brew_conf" ]] && [[ "$(realpath "$brew_conf")" == "$(realpath "$target")" ]]; then
    print_success "CLIProxyAPI brew config link"
    return 0
  fi

  print_error "CLIProxyAPI brew config is not linked at $brew_conf"
  return 1
}

cmd_cliproxyapi_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} cliproxyapi${RESET} - Run CLIProxyAPI in the foreground

${BOLD}USAGE:${RESET}
  ${SCRIPT_NAME} cliproxyapi [EXTRA CLIProxyAPI FLAGS]

Runs ${BOLD}cliproxyapi${RESET} in the current shell using the stowed config at
~/.config/cliproxyapi/config.yaml (Ctrl+C to stop).

Extra flags are passed through, e.g.:
  ${SCRIPT_NAME} cliproxyapi -codex-login
  ${SCRIPT_NAME} cliproxyapi -claude-login -no-browser
EOF
}

cmd_cliproxyapi() {
  case "${1:-}" in
    help|-h|--help) cmd_cliproxyapi_help; return 0 ;;
  esac

  local config="$HOME/.config/cliproxyapi/config.yaml"

  if ! command -v cliproxyapi >/dev/null 2>&1; then
    print_error "cliproxyapi is not installed; run '${SCRIPT_NAME} package add cliproxyapi'"
    return 1
  fi

  if [[ ! -f "$config" ]]; then
    print_error "Missing $config; run '${SCRIPT_NAME} stow'"
    return 1
  fi

  mkdir -p "$HOME/.config/cliproxyapi/auth"
  print_info "Starting CLIProxyAPI with $config (Ctrl+C to stop)"
  exec cliproxyapi -config "$config" "$@"
}
