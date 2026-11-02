# shellcheck shell=bash
# GNU Stow: links home/ into $HOME.

stow_require() {
  command_exists stow && return 0
  homebrew_require || return 1
  print_info "Installing GNU Stow"
  brew install stow
}

# NUL-separated existing, tracked files. Shared skills have their own link hooks.
stow_sources() {
  local rel
  repo_git ls-files -z --cached -- home | while IFS= read -r -d '' rel; do
    case "$rel" in
      home/.stow-local-ignore | home/.agents/skills/* | home/.agents/.skill-lock.json) continue ;;
    esac
    [[ -f "$DOTFILES_DIR/$rel" || -L "$DOTFILES_DIR/$rel" ]] || continue
    printf '%s\0' "$rel"
  done
}

# Default-deny filter: allow tracked files and the directories needed to reach them.
stow_ignore_pattern() {
  local rel path parent node candidate escaped character allowed='(?!)'
  stow_sources | {
    while IFS= read -r -d '' rel; do
      path="${rel#home/}"
      while [[ -n "$path" ]]; do
        node="${path##*/}"
        if [[ "$path" == */* ]]; then
          parent="${path%/*}"
        else
          parent=''
        fi
        # Stow checks a node before applying --dotfiles to its name, but its
        # parent directories already have their adjusted target names.
        candidate="/$parent"
        candidate="${candidate//\/dot-//.}"
        candidate="${candidate#/}"
        candidate="${candidate:+$candidate/}$node"
        # Quote literal paths, including spaces and regex punctuation.
        escaped="$candidate"
        for character in "\\" . '[' ']' '(' ')' '{' '}' '*' + '?' '^' '$' '|'; do
          escaped="${escaped//"$character"/\\$character}"
        done
        allowed="$allowed|$escaped"
        path="$parent"
      done
    done
    printf '\\A(?!(?:%s)\\z)(?s:.*)' "$allowed"
  }
}

# Use the same inventory and filter for stowing and unstowing.
stow_run() {
  local action="$1" ignore
  ignore="$(stow_ignore_pattern)" || {
    print_error "Could not read the tracked Stow inventory"
    return 1
  }
  stow --dotfiles --no-folding "--$action" --ignore="$ignore" \
    --dir "$DOTFILES_DIR" --target "$HOME" home
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

  print_info "Linking $(pretty_path "$HOME_DIR") into ~"
  if ! stow_run restow; then
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
  stow_run delete || return 1
  print_success "Dotfiles unlinked"
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

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) print_warning "$(pretty_path "$HOME/.local/bin") is not on PATH" ;;
  esac
  return "$failed"
}
