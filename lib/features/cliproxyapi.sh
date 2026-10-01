# shellcheck shell=bash
# CLIProxyAPI reads ~/.config/cliproxyapi/config.yaml. 'dot cliproxyapi' runs it
# in the foreground. The Homebrew service (brew services start cliproxyapi)
# reads $(brew --prefix)/etc/cliproxyapi.conf, linked here to the same file.
# auth/ holds OAuth credentials and is never tracked.

readonly CLIPROXYAPI_CONFIG="$HOME/.config/cliproxyapi/config.yaml"

cliproxyapi_poststow() {
  command_exists cliproxyapi || return 0
  ensure_link "$(brew --prefix)/etc/cliproxyapi.conf" "$CLIPROXYAPI_CONFIG"
}

cliproxyapi_check() {
  command_exists cliproxyapi || return 0
  check_link "$(brew --prefix)/etc/cliproxyapi.conf" "$CLIPROXYAPI_CONFIG" "CLIProxyAPI Homebrew config link"
}
