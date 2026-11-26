# shellcheck shell=bash
# Native skills CLI: share global skill files and its global lock with the repo.
# These links belong to this component, not to GNU Stow's file inventory.
define_component skills required "Shared agent skills"

# Keep shared-skills links relative when the repository lives under HOME.
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

skills_link() {
  local agents="$HOME/.agents"

  # Keep HOME local while the native skills CLI writes to shared/agents/.
  if [[ -L "$agents" || (-e "$agents" && ! -d "$agents") ]]; then
    backup_path "$agents" || return 1
  fi
  mkdir -p "$agents" "$SKILLS_DIR" || return 1
  ensure_link "$agents/skills" "$(skills_link_value "$SKILLS_DIR")" || return 1
  ensure_link "$agents/.skill-lock.json" "$(skills_link_value "$SKILLS_LOCK")" || return 1
  ensure_link "$SKILLS_STATE_LOCK" "$SKILLS_LOCK" || return 1
  ensure_link "$HOME/.claude/skills" "$agents/skills"
}

# skills_remove_links: remove only the links that skills_link created. `dot unstow` runs it.
skills_remove_links() {
  if [[ -L "$SKILLS_STATE_LOCK" ]] && same_path "$SKILLS_STATE_LOCK" "$SKILLS_LOCK"; then
    rm "$SKILLS_STATE_LOCK" || return 1
  fi
  if [[ -L "$HOME/.claude/skills" ]] && same_path "$HOME/.claude/skills" "$SKILLS_DIR"; then
    rm "$HOME/.claude/skills" || return 1
  fi
  if [[ -L "$HOME/.agents/skills" ]] && same_path "$HOME/.agents/skills" "$SKILLS_DIR"; then
    rm "$HOME/.agents/skills" || return 1
  fi
  if [[ -L "$HOME/.agents/.skill-lock.json" ]] && same_path "$HOME/.agents/.skill-lock.json" "$SKILLS_LOCK"; then
    rm "$HOME/.agents/.skill-lock.json" || return 1
  fi
  return 0
}

skills_check() {
  local failed=0
  check_link "$HOME/.agents/skills" "$SKILLS_DIR" "Agent skills link" "dot init --only skills" || failed=1
  check_link "$HOME/.claude/skills" "$SKILLS_DIR" "Claude skills link" "dot init --only skills" || failed=1
  check_link "$HOME/.agents/.skill-lock.json" "$SKILLS_LOCK" "Skills fallback lock link" "dot init --only skills" || failed=1
  check_link "$SKILLS_STATE_LOCK" "$SKILLS_LOCK" "Skills XDG lock link" "dot init --only skills" || failed=1

  command_exists jq || {
    print_error "jq is missing; install it with 'dot init --only packages'"
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

component_skills_install() { skills_link; }

component_skills_check() { skills_check; }
