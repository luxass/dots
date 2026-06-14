is_repo_path() {
  local target="$1"
  local source="$2"

  [[ -e "$target" ]] && [[ "$(realpath "$target")" == "$(realpath "$source")" ]]
}

stow_target_rel() {
  local rel="$1"

  case "$rel" in
    dot-*) printf '.%s\n' "${rel#dot-}" ;;
    */dot-*) printf '%s/.%s\n' "${rel%/dot-*}" "${rel##*/dot-}" ;;
    *) printf '%s\n' "$rel" ;;
  esac
}

managed_target_for() {
  local source="$1"
  local rel
  rel="$(stow_target_rel "${source#$HOME_DIR/}")"
  printf '%s/%s\n' "$HOME" "$rel"
}

find_managed_sources() {
  find "$HOME_DIR" \
    \( \
      -path "$HOME_DIR/.config/opencode/node_modules" -o \
      -path "$HOME_DIR/.pi/node_modules" -o \
      -path "$HOME_DIR/.pi/agent/bin" -o \
      -path "$HOME_DIR/.pi/agent/cache" -o \
      -path "$HOME_DIR/.pi/agent/logs" -o \
      -path "$HOME_DIR/.pi/agent/node_modules" -o \
      -path "$HOME_DIR/.pi/agent/npm" -o \
      -path "$HOME_DIR/.pi/agent/packages" -o \
      -path "$HOME_DIR/.pi/agent/sessions" -o \
      -path "$HOME_DIR/.pi/agent/mcp-oauth" -o \
      -path "$HOME_DIR/.pi/agent/extensions/*/node_modules" -o \
      -path "$HOME_DIR/.pi/todos" \
    \) -prune -o \
    \( -type f -o -type l \) \
    ! -name auth.json \
    ! -name trust.json \
    ! -name package-lock.json \
    ! -name mcp-cache.json \
    ! -name mcp-npx-cache.json \
    ! -name mcp-auth.json \
    -print0
}

backup_path() {
  local target="$1"
  local backup_dir="$2"
  local rel="${target#$HOME/}"
  local dest="$backup_dir/$rel"

  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
  print_info "Backed up $target -> $dest"
}

backup_conflicts() {
  local backup_dir="$BACKUP_ROOT/$(timestamp)"
  local made_backup=0

  print_verbose "Checking for files that would conflict with managed links"
  mkdir -p "$BACKUP_ROOT"

  while IFS= read -r -d '' source; do
    local target
    target="$(managed_target_for "$source")"

    if [[ -e "$target" || -L "$target" ]] && ! is_repo_path "$target" "$source"; then
      backup_path "$target" "$backup_dir"
      made_backup=1
    fi
  done < <(find_managed_sources)

  if [[ "$made_backup" -eq 0 ]]; then
    rmdir "$backup_dir" 2>/dev/null || true
    print_verbose "No link conflicts found"
  else
    print_success "Conflicts backed up to $backup_dir"
  fi
}

ensure_stow() {
  print_verbose "Checking GNU Stow availability"
  ensure_homebrew

  if command_exists stow; then
    print_verbose "GNU Stow is available"
    return 0
  fi

  print_info "Installing GNU Stow..."
  brew install stow
}

check_managed_links() {
  local verbose="${1:-${DOT_VERBOSE:-false}}"
  local failed=0
  local total=0
  local failed_count=0

  if [[ "$verbose" == "true" ]]; then
    print_info "Scanning managed sources in $HOME_DIR"
    print_info "Pruning generated runtime directories from the managed-link scan"
  fi

  while IFS= read -r -d '' source; do
    local target
    ((++total))
    target="$(managed_target_for "$source")"

    if ! is_repo_path "$target" "$source"; then
      if [[ -e "$target" || -L "$target" ]]; then
        print_error "Bad link: ${target#$HOME/}"
      else
        print_error "Missing link: ${target#$HOME/}"
      fi
      failed=1
      ((++failed_count))
    fi
  done < <(find_managed_sources)

  if [[ "$failed" -eq 0 ]]; then
    print_success "Managed links are healthy ($total checked)"
  else
    print_error "Managed links failed ($failed_count of $total checked)"
  fi

  return "$failed"
}

_stow_dotfiles() {
  ensure_stow
  print_verbose "Preparing to stow files from $HOME_DIR to $HOME"
  backup_conflicts
  print_info "Stowing files from $HOME_DIR to $HOME"
  print_verbose "Running GNU Stow in restow mode for package: home"
  stow --dotfiles -R -d "$DOTFILES_DIR" -t "$HOME" home
  print_success "Dotfiles stowed"
}

_unstow_dotfiles() {
  ensure_stow
  print_verbose "Preparing to unstow files from $HOME_DIR"
  print_verbose "Running GNU Stow in delete mode for package: home"
  stow --dotfiles -D -d "$DOTFILES_DIR" -t "$HOME" home
  print_success "Dotfiles unstowed"
}

_link_dot() {
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$DOTFILES_DIR/dot" "$HOME/.local/bin/dot"
  print_success "Linked dot -> $HOME/.local/bin/dot"
}

_unlink_dot() {
  if [[ -L "$HOME/.local/bin/dot" ]]; then
    rm "$HOME/.local/bin/dot"
    print_success "Removed $HOME/.local/bin/dot"
  else
    print_info "No dot link found at $HOME/.local/bin/dot"
  fi
}

cmd_stow() {
  parse_verbose_args "$@" || return 1
  print_header "Stowing dotfiles"
  _stow_dotfiles
}

cmd_unstow() {
  parse_verbose_args "$@" || return 1
  print_header "Unstowing dotfiles"
  _unstow_dotfiles
}

cmd_link() {
  print_header "Linking dot CLI"
  _link_dot
}

cmd_unlink() {
  print_header "Unlinking dot CLI"
  _unlink_dot
}

cmd_links() {
  parse_verbose_args "$@" || return 1
  print_header "Checking managed links"
  check_managed_links
}
