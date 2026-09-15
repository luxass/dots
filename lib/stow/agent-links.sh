readonly AGENT_SKILLS_DIR="${DOTFILES_DIR}/home/.agents/skills"
readonly HOME_AGENTS_DIR="$HOME/.agents"
readonly HOME_AGENT_SKILLS_DIR="$HOME_AGENTS_DIR/skills"
# Keep this relative so GNU Stow recognises ~/.agents/skills as an owned link.
readonly AGENT_SKILLS_LINK_TARGET="../${DOTFILES_DIR#$HOME/}/home/.agents/skills"

skills_directory_contains_only_managed_links() {
  local target_dir="$1"
  local source_dir="$2"
  local entry name expected

  while IFS= read -r -d '' entry; do
    [[ -L "$entry" ]] || return 1
    name="${entry##*/}"
    expected="$source_dir/$name"
    [[ -e "$expected" ]] || return 1
    [[ "$(realpath "$entry")" == "$(realpath "$expected")" ]] || return 1
  done < <(find "$target_dir" -mindepth 1 -maxdepth 1 -print0)

  return 0
}

ensure_agent_skills_parent_dir() {
  local source_agents_dir="${DOTFILES_DIR}/home/.agents"
  local source_resolved resolved

  mkdir -p "$source_agents_dir"
  source_resolved="$(realpath "$source_agents_dir")"

  if [[ -L "$HOME_AGENTS_DIR" ]]; then
    resolved="$(realpath "$HOME_AGENTS_DIR" 2>/dev/null || true)"
    if [[ "$resolved" == "$source_resolved" ]]; then
      rm "$HOME_AGENTS_DIR"
      mkdir -p "$HOME_AGENTS_DIR"
      print_info "Unfolded ~/.agents so ~/.agents/skills can be managed directly"
    else
      backup_path "$HOME_AGENTS_DIR" "$BACKUP_ROOT/$(timestamp)"
      mkdir -p "$HOME_AGENTS_DIR"
    fi
  elif [[ -e "$HOME_AGENTS_DIR" && ! -d "$HOME_AGENTS_DIR" ]]; then
    backup_path "$HOME_AGENTS_DIR" "$BACKUP_ROOT/$(timestamp)"
    mkdir -p "$HOME_AGENTS_DIR"
  else
    mkdir -p "$HOME_AGENTS_DIR"
  fi
}

ensure_agent_skills_link() {
  ensure_agent_skills_parent_dir
  mkdir -p "$AGENT_SKILLS_DIR"

  if [[ -L "$HOME_AGENT_SKILLS_DIR" ]]; then
    if [[ "$(realpath "$HOME_AGENT_SKILLS_DIR")" == "$(realpath "$AGENT_SKILLS_DIR")" ]]; then
      if [[ "$(readlink "$HOME_AGENT_SKILLS_DIR")" == "$AGENT_SKILLS_LINK_TARGET" ]]; then
        return 0
      fi
      rm "$HOME_AGENT_SKILLS_DIR"
    else
      backup_path "$HOME_AGENT_SKILLS_DIR" "$BACKUP_ROOT/$(timestamp)"
    fi
  elif [[ -e "$HOME_AGENT_SKILLS_DIR" ]]; then
    if [[ -d "$HOME_AGENT_SKILLS_DIR" ]] && skills_directory_contains_only_managed_links "$HOME_AGENT_SKILLS_DIR" "$AGENT_SKILLS_DIR"; then
      find "$HOME_AGENT_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type l -delete
      rmdir "$HOME_AGENT_SKILLS_DIR"
    else
      backup_path "$HOME_AGENT_SKILLS_DIR" "$BACKUP_ROOT/$(timestamp)"
    fi
  fi

  ln -s "$AGENT_SKILLS_LINK_TARGET" "$HOME_AGENT_SKILLS_DIR"
  print_success "Linked ~/.agents/skills -> home/.agents/skills"
}

ensure_claude_skills_link() {
  local claude_dir="$HOME/.claude"
  local claude_skills_dir="$claude_dir/skills"
  local link_target="$HOME_AGENTS_DIR/skills"

  ensure_agent_skills_link
  mkdir -p "$claude_dir"

  if [[ -L "$claude_skills_dir" ]]; then
    if [[ "$(realpath "$claude_skills_dir")" == "$(realpath "$link_target")" ]]; then
      return 0
    fi
    rm "$claude_skills_dir"
  elif [[ -e "$claude_skills_dir" ]]; then
    if [[ -d "$claude_skills_dir" ]] && skills_directory_contains_only_managed_links "$claude_skills_dir" "$AGENT_SKILLS_DIR"; then
      find "$claude_skills_dir" -mindepth 1 -maxdepth 1 -type l -delete
      rmdir "$claude_skills_dir"
    else
      backup_path "$claude_skills_dir" "$BACKUP_ROOT/$(timestamp)"
    fi
  fi

  ln -s "$link_target" "$claude_skills_dir"
  print_success "Linked ~/.claude/skills -> ~/.agents/skills"
}

check_claude_skills_link() {
  if [[ -L "$HOME/.claude/skills" ]] && [[ "$(realpath "$HOME/.claude/skills")" == "$(realpath "$AGENT_SKILLS_DIR")" ]]; then
    print_success "Claude skills link"
    return 0
  fi

  print_error "Claude skills are not linked at ~/.claude/skills"
  return 1
}

check_agent_skills_link() {
  if [[ -L "$HOME_AGENT_SKILLS_DIR" ]] && [[ "$(realpath "$HOME_AGENT_SKILLS_DIR")" == "$(realpath "$AGENT_SKILLS_DIR")" ]]; then
    print_success "Agent skills link"
    return 0
  fi

  print_error "Agent skills are not linked at ~/.agents/skills"
  return 1
}
