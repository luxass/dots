# shellcheck shell=bash
# doctor and info: read-only diagnostics.

cmd_doctor() {
  local feature failed=0

  no_args "$@" || return 1
  print_header "Running diagnostics"

  for feature in "${FEATURES[@]}"; do
    declare -F "${feature}_check" >/dev/null || continue
    print_section "$feature"
    "${feature}_check" || failed=1
  done

  echo
  if [[ "$failed" -eq 0 ]]; then
    print_success "Everything looks healthy"
  else
    print_error "Some checks failed"
  fi
  return "$failed"
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
