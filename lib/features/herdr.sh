# shellcheck shell=bash
# Herdr plugins: source declarations are public; installations stay local.

readonly HERDR_PLUGINS_FILE="$HOME_DIR/.config/herdr/plugins.txt"

herdr_plugin_sources() {
  [[ -f "$HERDR_PLUGINS_FILE" ]] || return 0
  awk '{ sub(/#.*/, ""); gsub(/[[:space:]]/, ""); if (length) print }' "$HERDR_PLUGINS_FILE" | sort -u
}

# Print declared GitHub sources absent from Herdr's user-wide registry.
# Disabled plugins count as installed; do not silently re-enable them.
herdr_plugins_missing() {
  local registry installed sources

  registry="$(herdr plugin list --json)" || return 1
  installed="$(jq -r '
    .result.plugins | if type != "array" then error("Invalid Herdr plugin list") else . end
    | .[] | select(.source.kind == "github") | .source
    | [.owner, .repo, (.subdir // "")] | map(select(. != "")) | join("/")
  ' <<<"$registry")" || return 1
  sources="$(herdr_plugin_sources)" || return 1
  comm -23 <(printf '%s\n' "$sources" | sort -u) <(printf '%s\n' "$installed" | sort -u)
}

herdr_deps() {
  local missing source

  [[ -f "$HERDR_PLUGINS_FILE" ]] || return 0
  if ! command_exists herdr || ! command_exists jq || ! command_exists sfw; then
    print_error "Herdr plugin setup requires herdr, jq, and sfw; run 'dot init'"
    return 1
  fi
  missing="$(herdr_plugins_missing)" || {
    print_error "Could not read Herdr's installed plugins"
    return 1
  }
  [[ -n "$missing" ]] || return 0

  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    print_info "Installing Herdr plugin: $source"
    sfw herdr plugin install "$source" --yes || {
      print_error "Failed to install Herdr plugin: $source"
      return 1
    }
  done <<<"$missing"
}

herdr_update_plugins() {
  local sources source

  command_exists herdr || return 0
  sources="$(herdr_plugin_sources)" || return 1
  [[ -n "$sources" ]] || return 0
  confirm "Update managed Herdr plugins?" n || return 0
  herdr_deps || return 1
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    sfw herdr plugin update "$source" --yes || {
      print_error "Failed to update Herdr plugin: $source"
      return 1
    }
  done <<<"$sources"
  print_success "Herdr plugins updated"
}

herdr_check() {
  local missing

  [[ -f "$HERDR_PLUGINS_FILE" ]] || return 0
  if ! command_exists herdr || ! command_exists jq; then
    print_error "Herdr plugin checks require herdr and jq; run 'dot init'"
    return 1
  fi
  missing="$(herdr_plugins_missing)" || {
    print_error "Could not read Herdr's installed plugins"
    return 1
  }
  if [[ -n "$missing" ]]; then
    print_error "Herdr plugins missing: $(paste -sd ' ' - <<<"$missing"); run 'dot stow'"
    return 1
  fi
  herdr config check >/dev/null || {
    print_error "Herdr configuration is invalid; run 'herdr config check'"
    return 1
  }
  print_success "Herdr plugins and configuration"
}
