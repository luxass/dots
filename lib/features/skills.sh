# shellcheck shell=bash
# Shared Agent Skills: ~/.agents/skills -> home/.agents/skills, and
# ~/.claude/skills -> ~/.agents/skills so Claude Code shares them.

# The ~/.agents/skills link value. It must be relative for GNU Stow to treat
# the link as its own, so climb to / when the repo is outside $HOME.
skills_link_value() {
  local target="$DOTFILES_DIR/home/.agents/skills" dir="$HOME/.agents" up=''

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

  # ~/.agents must be a real directory so ~/.agents/skills can be a link that
  # GNU Stow recognises as its own (relative, pointing into home/).
  if [[ -L "$agents" ]] && same_path "$agents" "$HOME_DIR/.agents"; then
    rm "$agents" || return 1
  elif [[ -L "$agents" || (-e "$agents" && ! -d "$agents") ]]; then
    backup_path "$agents" || return 1
  fi
  mkdir -p "$agents" "$HOME_DIR/.agents/skills" || return 1

  ensure_link "$agents/skills" "$(skills_link_value)" || return 1
  ensure_link "$HOME/.claude/skills" "$agents/skills"
}

skills_check() {
  local failed=0
  check_link "$HOME/.agents/skills" "$HOME_DIR/.agents/skills" "Agent skills link" || failed=1
  check_link "$HOME/.claude/skills" "$HOME_DIR/.agents/skills" "Claude skills link" || failed=1
  return "$failed"
}
