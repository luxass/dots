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

  mkdir -p "$BACKUP_ROOT"

  while IFS= read -r -d '' source; do
    local target
    target="$(managed_target_for "$source")"

    if [[ -e "$target" || -L "$target" ]] && ! is_repo_path "$target" "$source"; then
      backup_path "$target" "$backup_dir"
      made_backup=1
    fi
  done < <(find "$HOME_DIR" \( -type f -o -type l \) -print0)

  if [[ "$made_backup" -eq 0 ]]; then
    rmdir "$backup_dir" 2>/dev/null || true
  else
    print_success "Conflicts backed up to $backup_dir"
  fi
}

ensure_stow() {
  ensure_homebrew

  if command_exists stow; then
    return 0
  fi

  print_info "Installing GNU Stow..."
  brew install stow
}

check_managed_links() {
  local verbose="${1:-false}"
  local failed=0

  while IFS= read -r -d '' source; do
    local target
    target="$(managed_target_for "$source")"

    if is_repo_path "$target" "$source"; then
      if [[ "$verbose" == "true" ]]; then
        print_success "${target#$HOME/}"
      fi
    else
      if [[ -e "$target" || -L "$target" ]]; then
        print_error "Bad link: ${target#$HOME/}"
      else
        print_error "Missing link: ${target#$HOME/}"
      fi
      failed=1
    fi
  done < <(find "$HOME_DIR" \( -type f -o -type l \) -print0)

  return "$failed"
}

_stow_dotfiles() {
  ensure_stow
  backup_conflicts
  print_info "Stowing files from $HOME_DIR to $HOME"
  stow --dotfiles -R -v -d "$DOTFILES_DIR" -t "$HOME" home
  print_success "Dotfiles stowed"
}

_unstow_dotfiles() {
  ensure_stow
  stow --dotfiles -D -v -d "$DOTFILES_DIR" -t "$HOME" home
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
  print_header "Stowing dotfiles"
  _stow_dotfiles
}

cmd_unstow() {
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
  print_header "Checking managed links"
  check_managed_links true
}
