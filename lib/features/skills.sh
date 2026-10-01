# shellcheck shell=bash
# Shared Agent Skills: ~/.agents/skills -> home/.agents/skills, and
# ~/.claude/skills -> ~/.agents/skills so Claude Code shares them.

skills_prestow() {
  local agents="$HOME/.agents"

  # ~/.agents must be a real directory so ~/.agents/skills can be a link that
  # GNU Stow recognises as its own (relative, pointing into home/).
  if [[ -L "$agents" ]] && same_path "$agents" "$HOME_DIR/.agents"; then
    rm "$agents" || return 1
  elif [[ -L "$agents" || (-e "$agents" && ! -d "$agents") ]]; then
    backup_path "$agents" || return 1
  fi
  mkdir -p "$agents" "$HOME_DIR/.agents/skills" || return 1

  ensure_link "$agents/skills" "../${DOTFILES_DIR#"$HOME"/}/home/.agents/skills" || return 1
  ensure_link "$HOME/.claude/skills" "$agents/skills"
}

skills_check() {
  local failed=0
  check_link "$HOME/.agents/skills" "$HOME_DIR/.agents/skills" "Agent skills link" || failed=1
  check_link "$HOME/.claude/skills" "$HOME_DIR/.agents/skills" "Claude skills link" || failed=1
  return "$failed"
}
