# CLIProxyAPI runner. Runs in the foreground in the current shell with the
# stowed config; not managed as a brew service.

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
