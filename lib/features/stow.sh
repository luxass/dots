# shellcheck shell=bash
# GNU Stow: links home/ into $HOME, plus the dot CLI link in ~/.local/bin.

stow_require() {
  command_exists stow && return 0
  homebrew_require || return 1
  print_info "Installing GNU Stow"
  brew install stow
}

# stow_sources: NUL-separated repo-relative paths that should be linked, i.e.
# every file under home/ that is tracked or untracked but not ignored by Git.
stow_sources() {
  repo_git ls-files -z --cached --others --exclude-standard -- home \
    | tr '\0' '\n' | grep -vx 'home/.stow-local-ignore' | tr '\n' '\0'
}

# stow_target REL: where GNU Stow --dotfiles links home/REL (dot-x becomes .x).
stow_target() {
  local rel="/${1#home/}"
  rel="${rel//\/dot-//.}"
  printf '%s%s\n' "$HOME" "$rel"
}

# Move aside anything in $HOME that would block GNU Stow.
stow_backup_conflicts() {
  local rel source target
  while IFS= read -r -d '' rel; do
    source="$DOTFILES_DIR/$rel"
    [[ -e "$source" || -L "$source" ]] || continue
    target="$(stow_target "$rel")"
    if [[ -e "$target" || -L "$target" ]] && ! same_path "$target" "$source"; then
      backup_path "$target" || return 1
    fi
  done < <(stow_sources)
}

stow_apply() {
  stow_require || return 1
  run_hook prestow || return 1
  stow_backup_conflicts || return 1

  print_info "Linking $(pretty_path "$HOME_DIR") into ~"
  if ! stow --dotfiles --restow --dir "$DOTFILES_DIR" --target "$HOME" home; then
    print_error "GNU Stow failed"
    return 1
  fi

  if ! run_hook poststow; then
    print_error "Dotfiles are linked, but some follow-up steps failed"
    return 1
  fi
  print_success "Dotfiles linked"
}

stow_remove() {
  stow_require || return 1
  run_hook unstow || return 1
  stow --dotfiles --delete --dir "$DOTFILES_DIR" --target "$HOME" home || return 1
  print_success "Dotfiles unlinked"
}

stow_poststow() {
  ensure_link "$HOME/.local/bin/dot" "$DOTFILES_DIR/dot"
}

stow_check() {
  local rel source target total=0 broken=0 failed=0

  while IFS= read -r -d '' rel; do
    source="$DOTFILES_DIR/$rel"
    [[ -e "$source" || -L "$source" ]] || continue
    total=$((total + 1))
    target="$(stow_target "$rel")"
    same_path "$target" "$source" && continue

    broken=$((broken + 1))
    if [[ -e "$target" || -L "$target" ]]; then
      print_error "Blocked by another file: $(pretty_path "$target")"
    else
      print_error "Missing link: $(pretty_path "$target")"
    fi
  done < <(stow_sources)

  if [[ "$broken" -eq 0 ]]; then
    print_success "Managed links ($total checked)"
  else
    print_error "$broken of $total managed links are broken; run 'dot stow'"
    failed=1
  fi

  check_link "$HOME/.local/bin/dot" "$DOTFILES_DIR/dot" "dot CLI link" || failed=1
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) print_warning "$(pretty_path "$HOME/.local/bin") is not on PATH" ;;
  esac
  return "$failed"
}
