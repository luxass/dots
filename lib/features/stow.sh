# shellcheck shell=bash
# Native GNU Stow packages: each package mirrors its paths under HOME.

stow_require() {
  command_exists stow && return 0
  homebrew_require || return 1
  print_info "Installing GNU Stow"
  brew install stow
}

# Deployment files only; skip the shared ignore file and source byproducts.
stow_sources() {
  local package
  for package in "${STOW_PACKAGES[@]}"; do
    find "$STOW_DIR/$package" \
      \( -name .stow-local-ignore -o -name node_modules -o -name .DS_Store \
      -o -path "$STOW_DIR/$package/.config/git/local.conf" \
      -o -path "$STOW_DIR/$package/.config/git/extras" \) -prune -o \
      \( -type f -o -type l \) -print0 || return 1
  done
}

# Map an absolute package source to its --dotfiles target in HOME.
stow_target() {
  local rel="${1#"$STOW_DIR"/}"
  rel="/${rel#*/}"
  rel="${rel//\/dot-//.}"
  printf '%s%s\n' "$HOME" "$rel"
}

stow_run() {
  stow --dotfiles --no-folding --dir "$STOW_DIR" --target "$HOME" \
    "$@" "${STOW_PACKAGES[@]}"
}

# Move aside files and old source links that would block native Stow.
stow_backup_conflicts() {
  local source target
  while IFS= read -r -d '' source; do
    target="$(stow_target "$source")"
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == /* ]] && same_path "$target" "$source"; then
      # Stow cannot own absolute links, even when they point to the right file.
      backup_path "$target" || return 1
    elif [[ -e "$target" || -L "$target" ]] && ! same_path "$target" "$source"; then
      backup_path "$target" || return 1
    fi
  done < <(stow_sources)
}

stow_apply() {
  stow_require || return 1
  run_hook prestow || return 1
  stow_backup_conflicts || return 1

  print_info "Linking Stow packages: ${STOW_PACKAGES[*]}"
  if ! stow_run --restow; then
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
  stow_run --delete || return 1
  print_success "Dotfiles unlinked"
}

stow_check() {
  local plan failed=0

  command_exists stow || {
    print_error "GNU Stow is missing; run 'dot init'"
    return 1
  }
  # Ask upstream Stow what it would change, rather than rebuilding its rules.
  if ! plan="$(stow_run --simulate --stow --verbose=1 2>&1)"; then
    print_error "GNU Stow reports conflicts; run 'dot --verbose doctor' for details"
    print_verbose "$plan"
    failed=1
  elif grep -Eq '^(LINK|UNLINK|MKDIR|RMDIR):' <<<"$plan"; then
    print_error "GNU Stow would change managed links; run 'dot stow'"
    print_verbose "$plan"
    failed=1
  else
    print_success "Stow package links (${#STOW_PACKAGES[@]} packages)"
  fi

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) print_warning "$(pretty_path "$HOME/.local/bin") is not on PATH" ;;
  esac
  return "$failed"
}
