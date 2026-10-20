# shellcheck shell=bash
# Cua Driver: signed macOS installation, native updates, and read-only checks.

cua_export_path() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
}

cua_offer_permissions() {
  print_info "macOS permissions require your approval: cua-driver permissions grant"
  confirm "Open Cua Driver's macOS permission setup now? Approve the dialogs yourself." n || return 0
  cua-driver permissions grant || {
    print_error "Cua Driver permission setup did not complete; run 'cua-driver permissions grant' yourself"
    return 1
  }
}

cua_setup() {
  local tmp failed=0

  cua_export_path
  if command_exists cua-driver; then
    print_success "Cua Driver is already installed"
    cua_offer_permissions || return 1
    return 0
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/dot-cua.XXXXXX")" || return 1
  print_info "Installing Cua Driver (stable, signed macOS app)"
  if ! curl --proto '=https' --tlsv1.2 -fsSL "$CUA_DRIVER_INSTALL_URL" -o "$tmp/install.sh"; then
    print_error "Failed to download the Cua Driver installer"
    failed=1
  elif ! /bin/bash "$tmp/install.sh" --bin-dir "$HOME/.local/bin" --no-modify-path --channel stable; then
    print_error "Failed to install Cua Driver"
    failed=1
  fi
  rm -rf "$tmp"
  [[ "$failed" -eq 0 ]] || return 1
  hash -r

  if ! command_exists cua-driver || [[ ! -d "$CUA_DRIVER_APP" ]]; then
    print_error "Cua Driver installation is incomplete; expected the CLI and $(pretty_path "$CUA_DRIVER_APP")"
    return 1
  fi
  print_success "Cua Driver installed"
  cua_offer_permissions || return 1
}

cua_update() {
  local state available daemon_running=false

  cua_export_path
  if ! command_exists cua-driver; then
    print_warning "Cua Driver is missing; run 'dot init'"
    return 0
  fi
  if ! command_exists jq; then
    print_error "Cua Driver update checks require jq"
    return 1
  fi
  state="$(cua-driver check-update --json)" || {
    print_error "Could not check for a Cua Driver update"
    return 1
  }
  available="$(jq -er '.update_available | if type == "boolean" then tostring else error("Invalid Cua update state") end' <<<"$state")" || {
    print_error "Invalid Cua Driver update response"
    return 1
  }
  if [[ "$available" == false ]]; then
    print_success "Cua Driver is current"
    return 0
  fi

  if cua-driver status >/dev/null 2>&1; then
    daemon_running=true
    print_warning "Updating Cua Driver stops its daemon and interrupts connected computer-use sessions"
    confirm "Stop the Cua Driver daemon and update? Reconnect Pi afterward." n || return 0
  else
    confirm "Update Cua Driver using its native installer?" n || return 0
  fi
  if [[ "$daemon_running" == true ]]; then
    cua-driver stop || {
      print_error "Could not stop the Cua Driver daemon; update canceled"
      return 1
    }
    if cua-driver status >/dev/null 2>&1; then
      print_error "Cua Driver daemon is still running or restarted; close computer-use sessions before retrying"
      return 1
    fi
  fi
  CUA_DRIVER_RS_NO_MODIFY_PATH=1 cua-driver update --apply || {
    print_error "Cua Driver update failed; inspect 'cua-driver --version' before retrying"
    return 1
  }
  hash -r
  cua-driver --version || return 1
  print_success "Cua Driver updated"
  print_info "Reconnect Pi's computer server after updating"
  cua_offer_permissions || return 1
}

cua_check() {
  local permissions permission label failed=0

  cua_export_path
  if ! command_exists cua-driver; then
    print_error "Cua Driver is missing; run 'dot init'"
    return 1
  fi
  cua-driver --version || return 1
  if [[ ! -d "$CUA_DRIVER_APP" ]]; then
    print_error "Cua Driver signed app is missing: $(pretty_path "$CUA_DRIVER_APP")"
    failed=1
  elif ! codesign --verify --deep --strict "$CUA_DRIVER_APP" >/dev/null 2>&1; then
    print_error "Cua Driver app signature is invalid"
    failed=1
  else
    print_success "Cua Driver signed app"
  fi

  # Neither status command starts a daemon or opens an OS permission prompt.
  if ! cua-driver status >/dev/null 2>&1; then
    print_warning "Cua Driver daemon is stopped or unreachable; connect Pi's computer server to start it"
    print_warning "macOS permissions are unknown while the daemon is unavailable"
    return "$failed"
  fi
  print_success "Cua Driver daemon is running"
  if ! command_exists jq; then
    print_error "Cua Driver permission checks require jq"
    return 1
  fi
  permissions="$(cua-driver permissions status --json)" || {
    print_error "Could not read Cua Driver permissions"
    return 1
  }
  for permission in accessibility screen_recording; do
    case "$permission" in
      accessibility) label="Accessibility" ;;
      screen_recording) label="Screen Recording" ;;
    esac
    if jq -e --arg permission "$permission" '.[$permission] == true' <<<"$permissions" >/dev/null; then
      print_success "Cua Driver $label permission"
    else
      print_error "Cua Driver $label permission is missing or unknown; run 'cua-driver permissions grant' yourself"
      failed=1
    fi
  done
  return "$failed"
}
