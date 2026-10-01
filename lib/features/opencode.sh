# shellcheck shell=bash
# OpenCode plugin dependencies, plus plugins from the private/opencode submodule
# linked into ~/.config/opencode/plugins/.

readonly OPENCODE_PLUGINS="$HOME/.config/opencode/plugins"
readonly OPENCODE_PRIVATE_PLUGINS="$PRIVATE_OPENCODE_DIR/plugins"

# Private plugins: top-level directories and .ts/.js files.
opencode_private_plugins() {
  local entry
  for entry in "$OPENCODE_PRIVATE_PLUGINS"/*; do
    if [[ -d "$entry" || "$entry" == *.ts || "$entry" == *.js ]]; then
      printf '%s\n' "$entry"
    fi
  done
}

# Links in the plugins directory that point into the private submodule.
opencode_private_links() {
  local link
  for link in "$OPENCODE_PLUGINS"/*; do
    if [[ -L "$link" && "$(readlink "$link")" == "$OPENCODE_PRIVATE_PLUGINS/"* ]]; then
      printf '%s\n' "$link"
    fi
  done
}

opencode_prestow() {
  # Keep the plugins directory real, so private plugins are not linked into the repo.
  if [[ -L "$OPENCODE_PLUGINS" ]] && same_path "$OPENCODE_PLUGINS" "$HOME_DIR/.config/opencode/plugins"; then
    rm "$OPENCODE_PLUGINS" || return 1
  fi
  mkdir -p "$OPENCODE_PLUGINS"
}

opencode_poststow() {
  local link plugin failed=0

  submodule_sync private/opencode || return 1
  while IFS= read -r link; do
    [[ -e "$link" ]] || rm "$link" || failed=1
  done < <(opencode_private_links)
  while IFS= read -r plugin; do
    ensure_link "$OPENCODE_PLUGINS/${plugin##*/}" "$plugin" || failed=1
  done < <(opencode_private_plugins)
  return "$failed"
}

opencode_unstow() {
  local link
  while IFS= read -r link; do
    rm "$link" || return 1
  done < <(opencode_private_links)
}

opencode_deps() {
  local failed=0
  pnpm_install_deps "$HOME/.config/opencode" "OpenCode plugin" || failed=1
  if [[ -n "$(opencode_private_plugins)" ]]; then
    pnpm_install_deps "$PRIVATE_OPENCODE_DIR" "private OpenCode plugin" || failed=1
  fi
  return "$failed"
}

# opencode_check_deps DIR LABEL
opencode_check_deps() {
  [[ -f "$1/package.json" ]] || return 0
  if [[ -d "$1/node_modules/@opencode/plugin" ]]; then
    print_success "$2 dependencies"
  else
    print_error "$2 dependencies are missing; run 'dot stow'"
    return 1
  fi
}

opencode_check() {
  local plugin link failed=0

  while IFS= read -r plugin; do
    check_link "$OPENCODE_PLUGINS/${plugin##*/}" "$plugin" "Private OpenCode plugin ${plugin##*/}" || failed=1
  done < <(opencode_private_plugins)
  while IFS= read -r link; do
    if [[ ! -e "$link" ]]; then
      print_error "Stale private OpenCode plugin link: ${link##*/}; run 'dot stow'"
      failed=1
    fi
  done < <(opencode_private_links)

  opencode_check_deps "$HOME/.config/opencode" "OpenCode plugin" || failed=1
  if [[ -n "$(opencode_private_plugins)" ]]; then
    opencode_check_deps "$PRIVATE_OPENCODE_DIR" "Private OpenCode plugin" || failed=1
  fi
  return "$failed"
}
