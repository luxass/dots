prepare_opencode_plugins_target() {
  local target source
  target="$HOME/.config/opencode/plugins"
  source="$HOME_DIR/.config/opencode/plugins"

  if [[ -L "$target" ]] && [[ "$(realpath "$target")" == "$(realpath "$source")" ]]; then
    rm "$target"
    mkdir -p "$target"
  fi
}

ensure_private_opencode_submodule() {
  local private_dir
  private_dir="$PRIVATE_OPENCODE_DIR"

  if [[ ! -f "$DOTFILES_DIR/.gitmodules" ]] || ! git -C "$DOTFILES_DIR" config -f .gitmodules --get submodule.private/opencode.path >/dev/null 2>&1; then
    return 0
  fi

  if [[ -d "$private_dir/.git" || -f "$private_dir/.git" ]]; then
    print_verbose "Private OpenCode submodule is available"
  else
    print_info "Initializing private OpenCode submodule"
  fi

  git -C "$DOTFILES_DIR" submodule update --init --recursive private/opencode
}

find_private_opencode_entries() {
  local plugins_dir
  plugins_dir="$PRIVATE_OPENCODE_PLUGINS_DIR"

  [[ -d "$plugins_dir" ]] || return 0

  find "$plugins_dir" -maxdepth 1 \
    \( -type f \( -name '*.js' -o -name '*.ts' \) -o \
       -type d ! -path "$plugins_dir" \) \
    -print0
}

link_private_opencode_plugins() {
  local target_dir plugin target
  target_dir="$HOME/.config/opencode/plugins"

  [[ -d "$PRIVATE_OPENCODE_PLUGINS_DIR" ]] || return 0
  mkdir -p "$target_dir"

  while IFS= read -r -d '' plugin; do
    target="$target_dir/$(basename "$plugin")"

    if [[ -e "$target" || -L "$target" ]] && ! is_repo_path "$target" "$plugin"; then
      backup_path "$target" "$BACKUP_ROOT/$(timestamp)"
    fi

    ln -sfn "$plugin" "$target"
  done < <(find_private_opencode_entries)

  print_success "Private OpenCode plugins linked"
}

unlink_private_opencode_plugins() {
  local target_dir plugin target
  target_dir="$HOME/.config/opencode/plugins"

  [[ -d "$PRIVATE_OPENCODE_PLUGINS_DIR" && -d "$target_dir" ]] || return 0

  while IFS= read -r -d '' plugin; do
    target="$target_dir/$(basename "$plugin")"
    if [[ -L "$target" ]] && [[ "$(realpath "$target")" == "$(realpath "$plugin")" ]]; then
      rm "$target"
    fi
  done < <(find_private_opencode_entries)
}

prune_private_opencode_plugins() {
  local plugins_dir target_dir entry link_target base
  plugins_dir="$PRIVATE_OPENCODE_PLUGINS_DIR"
  target_dir="$HOME/.config/opencode/plugins"

  [[ -d "$target_dir" ]] || return 0

  while IFS= read -r -d '' entry; do
    link_target="$(readlink "$entry")"
    case "$link_target" in
      *private/opencode/plugins*)
        base="$(basename "$entry")"
        if [[ ! -d "$plugins_dir" || ! -e "$plugins_dir/$base" ]]; then
          rm "$entry"
          print_info "Removed stale private OpenCode plugin: $base"
        fi
        ;;
    esac
  done < <(find "$target_dir" -maxdepth 1 -type l -print0)
}

private_opencode_has_plugins() {
  local entry

  while IFS= read -r -d '' entry; do
    return 0
  done < <(find_private_opencode_entries)

  return 1
}

ensure_opencode_plugin_deps() {
  local home_opencode="$HOME/.config/opencode"
  local private_dir
  private_dir="$PRIVATE_OPENCODE_DIR"

  if [[ -f "$home_opencode/package.json" ]]; then
    stow_install_pnpm_deps "$home_opencode" "OpenCode plugin"
  elif [[ -f "$HOME_DIR/.config/opencode/package.json" ]]; then
    stow_install_pnpm_deps "$HOME_DIR/.config/opencode" "OpenCode plugin"
  fi

  if private_opencode_has_plugins && [[ -f "$private_dir/package.json" ]]; then
    stow_install_pnpm_deps "$private_dir" "private OpenCode plugin"
  else
    print_verbose "No private OpenCode plugins; skipping private dependencies"
  fi
}

check_opencode_plugins() {
  local failed=0
  local target_dir private_dir home_opencode
  target_dir="$HOME/.config/opencode/plugins"
  private_dir="$PRIVATE_OPENCODE_DIR"
  home_opencode="$HOME/.config/opencode"

  if private_opencode_has_plugins; then
    if [[ ! -d "$target_dir" ]]; then
      print_error "Private OpenCode plugin target is missing: $target_dir (run 'dot stow')"
      failed=1
    else
      local plugin target
      while IFS= read -r -d '' plugin; do
        target="$target_dir/$(basename "$plugin")"
        if ! is_repo_path "$target" "$plugin"; then
          print_error "Private OpenCode plugin is not linked: $(basename "$plugin")"
          failed=1
        fi
      done < <(find_private_opencode_entries)
    fi
  fi

  if [[ -d "$target_dir" ]]; then
    local entry link_target
    while IFS= read -r -d '' entry; do
      link_target="$(readlink "$entry")"
      case "$link_target" in
        *private/opencode/plugins*)
          if [[ ! -e "$entry" ]]; then
            print_error "Stale private OpenCode plugin link: $(basename "$entry") (run 'dot stow')"
            failed=1
          fi
          ;;
      esac
    done < <(find "$target_dir" -maxdepth 1 -type l -print0)
  fi

  if [[ -f "$home_opencode/package.json" ]]; then
    if [[ -d "$home_opencode/node_modules/@opencode/plugin" ]]; then
      print_success "OpenCode plugin dependencies"
    else
      print_error "OpenCode plugin dependencies missing in $home_opencode (run 'dot stow')"
      failed=1
    fi
  fi

  if private_opencode_has_plugins && [[ -f "$private_dir/package.json" ]]; then
    if [[ -d "$private_dir/node_modules/@opencode/plugin" ]]; then
      print_success "Private OpenCode plugin dependencies"
    else
      print_error "Private OpenCode plugin dependencies missing in $private_dir (run 'dot stow')"
      failed=1
    fi
  fi

  return "$failed"
}
