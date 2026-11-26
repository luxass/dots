# shellcheck shell=bash
# GitHub CLI: public preferences and extension sources, never authentication.
# Stow links config.yml with --no-folding, so ~/.config/gh stays a real
# directory and authentication files stay local.
define_component gh optional "GitHub CLI extensions"

readonly GH_EXTENSIONS_FILE="$STOW_DIR/gh/.config/gh/extensions.txt"

gh_extension_sources() { sources_file_entries "$GH_EXTENSIONS_FILE"; }

gh_extensions_missing() {
  local registry installed sources

  registry="$(GH_FORCE_TTY='' NO_COLOR=1 gh extension list)" || return 1
  installed="$(awk -F '\t' 'NF >= 2 { print $2 }' <<<"$registry" | sort -u)" || return 1
  sources="$(gh_extension_sources)" || return 1
  comm -23 <(printf '%s\n' "$sources" | sort -u) <(printf '%s\n' "$installed" | sort -u)
}

gh_install_extensions() {
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
  check_link "$config_dir/config.yml" "$STOW_DIR/gh/.config/gh/config.yml" "GitHub CLI preferences" || failed=1
  missing="$(gh_extensions_missing)" || {
    print_error "Could not read installed GitHub CLI extensions"
    return 1
  }
  if [[ -n "$missing" ]]; then
    print_error "GitHub CLI extensions missing: $(paste -sd ' ' - <<<"$missing"); run 'dot init --only gh'"
    failed=1
  else
    print_success "GitHub CLI extensions"
  fi
  return "$failed"
}

component_gh_install() { gh_install_extensions; }

component_gh_update() {
  gh_install_extensions || return 1
  gh_update_extensions
}

component_gh_check() { gh_check; }
