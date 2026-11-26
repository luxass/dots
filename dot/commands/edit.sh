# shellcheck shell=bash
# dot edit: open the dotfiles repository in $EDITOR.

cmd_edit_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot edit

Open $(pretty_path "$DOTFILES_DIR") in \$EDITOR (default: nvim).
EOF
}

cmd_edit() {
  local editor="${EDITOR:-nvim}"

  no_args "$@" || return 1
  if ! command_exists "$editor"; then
    print_error "Editor '$editor' not found; set EDITOR"
    return 1
  fi
  exec "$editor" "$DOTFILES_DIR"
}
