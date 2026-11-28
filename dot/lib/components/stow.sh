# shellcheck shell=bash
# Native GNU Stow packages: each package mirrors its paths under HOME.
# `dot stow` runs the same relink. `dot unstow` removes the links.
define_component stow required "Stow packages"

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
  stow_backup_conflicts || return 1

  print_info "Linking Stow packages: ${STOW_PACKAGES[*]}"
  if ! stow_run --restow; then
    print_error "GNU Stow failed"
    return 1
  fi
  stow_remove_dead_links || return 1
  print_success "Dotfiles linked"
}

# stow_remove_dead_links: remove links into the Stow packages whose file no
# longer exists. Restow removes these only inside folders a package still has,
# so removing a whole package or folder (for example stow/herdr) leaves them.
# Links that dot link and the skills component own are left to those steps.
stow_remove_dead_links() {
  local link value target

  while IFS= read -r link; do
    [[ -n "$link" ]] || continue
    value="$(readlink "$link")" || continue
    case "$value" in
      /*) target="$value" ;;
      *) target="$(dirname "$link")/$value" ;;
    esac
    [[ "$(lexical_path "$target")" == "$STOW_DIR"/* ]] || continue
    rm "$link" || return 1
    print_info "Removed dead link $(pretty_path "$link")"
  done < <(stow_broken_links)
}

stow_remove() {
  stow_require || return 1
  stow_run --delete || return 1
  print_success "Dotfiles unlinked"
}

# stow_uncommitted_changes: print `git status --short` lines for the Stow
# packages. An installer that edits its configuration writes through the link
# into the repository. Untracked files count too, because Stow links them into HOME.
stow_uncommitted_changes() {
  repo_is_git || return 0
  repo_git status --short --untracked-files=all -- stow
}

# stow_link_directories: print the HOME directories that hold links dot makes:
# the parents of every Stow target, plus the dot and shared skills links.
stow_link_directories() {
  local source target
  {
    while IFS= read -r -d '' source; do
      target="$(stow_target "$source")"
      printf '%s\n' "${target%/*}"
    done < <(stow_sources)
    printf '%s\n' "$HOME/.local/bin" "$HOME/.agents" "$HOME/.claude" "${SKILLS_STATE_LOCK%/*}"
  } | sort -u
}

# stow_broken_links: print links in those directories, and one level below
# them, that point into the repository at a file that no longer exists. A
# rename or deletion in the repository leaves these behind, and GNU Stow's
# simulate mode does not report them.
stow_broken_links() {
  local dir link dirs=()

  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      dirs+=("$dir")
    fi
  done < <(stow_link_directories)
  [[ "${#dirs[@]}" -gt 0 ]] || return 0

  while IFS= read -r -d '' link; do
    [[ -e "$link" ]] && continue
    if link_points_into_repo "$link"; then
      printf '%s\n' "$link"
    fi
  done < <(find "${dirs[@]}" -maxdepth 2 -name node_modules -prune -o -type l -print0 2>/dev/null) | sort -u
}

# broken_link_fix LINK: print the command that replaces or removes a broken link.
broken_link_fix() {
  case "$1" in
    "$HOME/.local/bin/dot") printf 'dot link\n' ;;
    "$HOME/.agents/skills" | "$HOME/.agents/.skill-lock.json" | "$HOME/.claude/skills" | "$SKILLS_STATE_LOCK")
      printf 'dot init --only skills\n'
      ;;
    # dot stow removes dead links into the Stow packages (stow_remove_dead_links).
    *) printf 'dot stow\n' ;;
  esac
}

# stow_check_working_tree: warn about uncommitted package changes and broken
# links into the repository. Warnings only: neither stops dot from working.
stow_check_working_tree() {
  local changes broken link

  changes="$(stow_uncommitted_changes)" || changes=""
  if [[ -n "$changes" ]]; then
    print_warning "Uncommitted changes in Stow packages; review them before an installer's edit lands in Git:"
    indent <<<"$changes" >&2
  else
    print_success "No uncommitted changes in Stow packages"
  fi

  broken="$(stow_broken_links)" || broken=""
  if [[ -n "$broken" ]]; then
    print_warning "Links into the repository point at missing files:"
    while IFS= read -r link; do
      printf '  %s (fix: %s)\n' "$(pretty_path "$link")" "$(broken_link_fix "$link")" >&2
    done <<<"$broken"
  else
    print_success "No broken links into the repository"
  fi
}

component_stow_install() { stow_apply; }

component_stow_check() {
  stow_check || return 1
  stow_check_working_tree
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
