# shellcheck shell=bash
# GitHub CLI: public preferences and extension sources, never authentication.

readonly GH_EXTENSIONS_FILE="$HOME_DIR/.config/gh/extensions.txt"

# Keep new authentication files local instead of letting Stow fold this directory.
gh_prestow() {
  mkdir -p "$HOME/.config/gh" || return 1
}

gh_extension_sources() {
  [[ -f "$GH_EXTENSIONS_FILE" ]] || return 0
  awk '{ sub(/#.*/, ""); gsub(/[[:space:]]/, ""); if (length) print }' "$GH_EXTENSIONS_FILE" | sort -u
}

gh_extensions_missing() {
  local registry installed sources

  registry="$(GH_FORCE_TTY='' NO_COLOR=1 gh extension list)" || return 1
  installed="$(awk -F '\t' 'NF >= 2 { print $2 }' <<<"$registry" | sort -u)" || return 1
  sources="$(gh_extension_sources)" || return 1
  comm -23 <(printf '%s\n' "$sources" | sort -u) <(printf '%s\n' "$installed" | sort -u)
}

gh_deps() {
  local missing source

  [[ -f "$GH_EXTENSIONS_FILE" ]] || return 0
  if ! command_exists gh || ! command_exists sfw; then
    print_error "GitHub CLI extension setup requires gh and sfw; run 'dot init'"
    return 1
  fi
  missing="$(gh_extensions_missing)" || {
    print_error "Could not read installed GitHub CLI extensions"
    return 1
  }
  [[ -n "$missing" ]] || return 0

  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    print_info "Installing GitHub CLI extension: $source"
    sfw gh extension install "$source" || {
      print_error "Failed to install GitHub CLI extension: $source"
      return 1
    }
  done <<<"$missing"
}

gh_update_extensions() {
  local sources source

  command_exists gh || return 0
  sources="$(gh_extension_sources)" || return 1
  [[ -n "$sources" ]] || return 0
  confirm "Update managed GitHub CLI extensions?" n || return 0
  gh_deps || return 1
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    sfw gh extension upgrade "${source##*/}" || {
      print_error "Failed to update GitHub CLI extension: $source"
      return 1
    }
  done <<<"$sources"
  print_success "GitHub CLI extensions updated"
}

gh_check() {
  local missing config_dir failed=0

  if ! command_exists gh; then
    print_error "GitHub CLI is missing; run 'dot init'"
    return 1
  fi
  config_dir="${GH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gh}"
  check_link "$config_dir/config.yml" "$HOME_DIR/.config/gh/config.yml" "GitHub CLI preferences" || failed=1
  missing="$(gh_extensions_missing)" || {
    print_error "Could not read installed GitHub CLI extensions"
    return 1
  }
  if [[ -n "$missing" ]]; then
    print_error "GitHub CLI extensions missing: $(paste -sd ' ' - <<<"$missing"); run 'dot stow'"
    failed=1
  else
    print_success "GitHub CLI extensions"
  fi
  return "$failed"
}
