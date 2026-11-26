# shellcheck shell=bash
# dot info: paths, runtime versions, and repository status. Read-only.

cmd_info_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot info

Show dot's paths, the installed runtime versions, and the repository status.
EOF
}

# info_row LABEL COMMAND...: print a label and the command's first output line.
info_row() {
  local label="$1" value
  shift
  if command_exists "$1"; then
    value="$("$@" 2>/dev/null | head -n 1)"
  else
    value="${DIM}missing${RESET}"
  fi
  printf '  %-12s %s\n' "$label" "$value"
}

cmd_info() {
  no_args "$@" || return 1

  print_section "dot $DOT_VERSION"
  printf '  %-12s %s\n' Repository "$(pretty_path "$DOTFILES_DIR")" \
    dot "$(pretty_path "$DOT_ROOT")" \
    State "$(pretty_path "$STATE_DIR")" \
    PNPM_HOME "$(pretty_path "$PNPM_HOME")"

  print_section "Runtimes"
  info_row Homebrew brew --version
  info_row pnpm pnpm --version
  info_row Node.js node --version
  info_row npm npm --version
  info_row Bun bun --version
  info_row Fish fish --version
  info_row Pi pi --version

  print_section "Repository"
  if repo_is_git; then
    repo_git status --short --branch
  else
    print_warning "$DOTFILES_DIR is not a Git repository"
  fi
}
