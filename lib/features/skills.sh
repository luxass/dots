# shellcheck shell=bash
# Native skills CLI: share global skill files and its global lock with the repo.

# Relative links let GNU Stow recognise the ~/.agents links as its own.
skills_link_value() {
  local target="$1" dir="$HOME/.agents" up=''

  if [[ "$DOTFILES_DIR" == "$HOME"/* ]]; then
    printf '../%s\n' "${target#"$HOME"/}"
    return
  fi
  while [[ "$dir" != / ]]; do
    up+='../'
    dir="$(dirname "$dir")"
  done
  printf '%s%s\n' "$up" "${target#/}"
}

skills_prestow() {
  local agents="$HOME/.agents"

  # ~/.agents must be a real directory so Stow owns its individual links.
  if [[ -L "$agents" ]] && same_path "$agents" "$HOME_DIR/.agents"; then
    rm "$agents" || return 1
  elif [[ -L "$agents" || (-e "$agents" && ! -d "$agents") ]]; then
    backup_path "$agents" || return 1
  fi
  mkdir -p "$agents" "$SKILLS_DIR" || return 1
  ensure_link "$agents/skills" "$(skills_link_value "$SKILLS_DIR")" || return 1
  ensure_link "$agents/.skill-lock.json" "$(skills_link_value "$SKILLS_LOCK")" || return 1
  ensure_link "$SKILLS_STATE_LOCK" "$SKILLS_LOCK" || return 1
  ensure_link "$HOME/.claude/skills" "$agents/skills"
}

# The XDG and Claude links are outside Stow's tracked home/ paths.
skills_unstow() {
  if [[ -L "$SKILLS_STATE_LOCK" ]] && same_path "$SKILLS_STATE_LOCK" "$SKILLS_LOCK"; then
    rm "$SKILLS_STATE_LOCK" || return 1
  fi
  if [[ -L "$HOME/.claude/skills" ]] && same_path "$HOME/.claude/skills" "$SKILLS_DIR"; then
    rm "$HOME/.claude/skills" || return 1
  fi
  return 0
}

skills_check() {
  local failed=0
  check_link "$HOME/.agents/skills" "$SKILLS_DIR" "Agent skills link" || failed=1
  check_link "$HOME/.claude/skills" "$SKILLS_DIR" "Claude skills link" || failed=1
  check_link "$HOME/.agents/.skill-lock.json" "$SKILLS_LOCK" "Skills fallback lock link" || failed=1
  check_link "$SKILLS_STATE_LOCK" "$SKILLS_LOCK" "Skills XDG lock link" || failed=1

  command_exists jq || {
    print_error "jq is missing; install the base Homebrew bundle with 'dot init'"
    return 1
  }
  if jq -e '.version == 3 and (.skills | type == "object")' "$SKILLS_LOCK" >/dev/null; then
    print_success "Native global skills lock"
    if jq -e '.skills | length == 0' "$SKILLS_LOCK" >/dev/null; then
      print_info "No upstreams recorded yet; re-add external imports with 'sfw pnpx skills add SOURCE -g'"
    fi
  else
    print_error "Invalid global skills lock at $(pretty_path "$SKILLS_LOCK")"
    failed=1
  fi
  return "$failed"
}
