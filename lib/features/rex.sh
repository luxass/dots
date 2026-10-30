# shellcheck shell=bash
# Rex configuration only. Install and update the app separately.

rex_cli() {
  if [[ -n "${REX_BIN_DIR:-}" && -x "${REX_BIN_DIR}/rex" ]]; then
    printf '%s\n' "${REX_BIN_DIR}/rex"
  elif [[ -x "$REX_BUNDLED_CLI" ]]; then
    printf '%s\n' "$REX_BUNDLED_CLI"
  else
    return 1
  fi
}

# Rex generates IDs when it imports themes. Resolve names locally, not in Git.
rex_theme_id() {
  local name="$1" appearance="$2"

  defaults export "$REX_DEFAULTS_DOMAIN" - 2>/dev/null \
    | plutil -extract 'Workspace\.customThemes' raw -o - - 2>/dev/null \
    | base64 -D \
    | jq -er --arg name "$name" --arg appearance "$appearance" '
      [.[] | select(.name == $name and .appearance == $appearance)
        | select(.id | type == "string" and startswith("custom-"))]
      | sort_by(.createdAt // 0) | last | .id // empty
    '
}

rex_themes_ready() {
  local key type value appearance failed=0

  command_exists jq || {
    print_error "Rex theme selection requires jq; run 'dot init'"
    return 1
  }
  while read -r key type value || [[ -n "$key" ]]; do
    [[ "$type" == theme ]] || continue
    case "$key" in
      Workspace.darkThemeID) appearance=dark ;;
      Workspace.lightThemeID) appearance=light ;;
      *)
        print_error "The Rex theme type is only valid for lightThemeID and darkThemeID"
        return 1
        ;;
    esac
    if ! rex_theme_id "$value" "$appearance" >/dev/null; then
      print_warning "Import $(pretty_path "$HOME/.config/rex/themes/$value") once in Rex"
      failed=1
    fi
  done <"$REX_SETTINGS_FILE"
  return "$failed"
}

# Back up existing app preferences before writing the first changed setting.
# The backup stays outside Git because preferences can contain private state.
rex_apply_settings() {
  local key type value current expected changed=0 backup

  [[ -f "$REX_SETTINGS_FILE" ]] || {
    print_error "Rex app preferences file is missing"
    return 1
  }
  if ! rex_themes_ready; then
    print_warning "Rex app preferences are unchanged until both themes are imported"
    return 0
  fi
  while read -r key type value || [[ -n "$key" ]]; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
      Workspace.*) ;;
      *)
        print_error "Invalid Rex preference key: $key"
        return 1
        ;;
    esac
    case "$type" in
      string | int | float | bool | theme) ;;
      *)
        print_error "Invalid Rex preference type: $type"
        return 1
        ;;
    esac
    [[ -n "$value" ]] || {
      print_error "Rex preference $key has no value"
      return 1
    }
    if [[ "$type" == theme ]]; then
      case "$key" in
        Workspace.darkThemeID) expected=dark ;;
        Workspace.lightThemeID) expected=light ;;
        *) return 1 ;;
      esac
      value="$(rex_theme_id "$value" "$expected")" || return 1
      type=string
    fi
    expected="$value"
    if [[ "$type" == bool ]]; then
      case "$value" in
        true) expected=1 ;;
        false) expected=0 ;;
        *)
          print_error "Invalid boolean for Rex preference $key"
          return 1
          ;;
      esac
    fi
    current="$(defaults read "$REX_DEFAULTS_DOMAIN" "$key" 2>/dev/null || true)"
    [[ "$current" == "$expected" ]] && continue

    if [[ "$changed" -eq 0 ]] && defaults read "$REX_DEFAULTS_DOMAIN" >/dev/null 2>&1; then
      backup="$BACKUP_ROOT/$DOT_RUN_ID/rex-preferences.plist"
      mkdir -p "$(dirname "$backup")" || return 1
      defaults export "$REX_DEFAULTS_DOMAIN" "$backup" >/dev/null || return 1
      print_info "Backed up Rex preferences to $(pretty_path "$backup")"
    fi
    defaults write "$REX_DEFAULTS_DOMAIN" "$key" "-$type" "$value" || {
      print_error "Failed to write Rex preference $key"
      return 1
    }
    changed=$((changed + 1))
  done <"$REX_SETTINGS_FILE"

  if [[ "$changed" -gt 0 ]]; then
    print_info "Wrote $changed Rex preferences; relaunch Rex to apply them"
  else
    print_success "Rex app preferences are up to date"
  fi
}

rex_poststow() {
  local cli

  if [[ ! -d "$REX_APP_PATH" ]]; then
    print_info "Rex is optional and is not installed; its configuration is linked for later"
    print_info "Install Rex: $REX_INSTALLATION_URL"
    if confirm "Want to use Rex? Open its installation guide?" n; then
      open "$REX_INSTALLATION_URL" || print_warning "Could not open the guide; use the link above"
    fi
    return 0
  fi
  if ! cli="$(rex_cli)"; then
    print_warning "Launch Rex once to install its CLI, then run 'dot stow'"
    return 0
  fi
  "$cli" --autostart=false config check >/dev/null || {
    print_error "Rex configuration is invalid; run 'rex config check'"
    return 1
  }
  rex_apply_settings || return 1
  if "$cli" --autostart=false server status >/dev/null 2>&1; then
    "$cli" --autostart=false config reload >/dev/null || return 1
    print_success "Rex configuration reloaded"
  fi
  print_info "Rex follows macOS after both themes are imported and app preferences are applied"
}

rex_check() {
  local cli

  if [[ ! -d "$REX_APP_PATH" ]]; then
    print_warning "Rex is optional and is not installed. Installation guide: $REX_INSTALLATION_URL"
    return 0
  fi
  if ! cli="$(rex_cli)"; then
    print_error "Rex CLI is missing; launch Rex once, then run 'dot stow'"
    return 1
  fi
  "$cli" --autostart=false config check >/dev/null || {
    print_error "Rex configuration is invalid; run 'rex config check'"
    return 1
  }
  rex_themes_ready || return 1
  print_success "Rex CLI, configuration, and imported theme pair"
}
