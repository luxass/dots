# shellcheck shell=bash
# dot help: the command list (DOT_COMMAND_SUMMARIES in dot/lib/dot-main.sh)
# or one command's usage (cmd_<command>_usage in its file).

cmd_help_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot help [COMMAND]
EOF
}

cmd_help() {
  local command_name="${1:-}" handler summary

  if [[ -n "$command_name" ]]; then
    if ! handler="$(command_function "$command_name")" || ! declare -F "${handler}_usage" >/dev/null; then
      print_error "Unknown command: $command_name"
      return 1
    fi
    "${handler}_usage"
    return
  fi

  printf '%sdot%s %s - set up, update, and check this Mac from the dotfiles repository\n\n' "$BOLD" "$RESET" "$DOT_VERSION"
  printf '%sUSAGE%s\n' "$BOLD" "$RESET"
  printf '  dot [OPTIONS] COMMAND [ARGS]\n'
  printf '  dot COMMAND --help\n\n'
  printf '%sCOMMANDS%s\n' "$BOLD" "$RESET"
  for summary in "${DOT_COMMAND_SUMMARIES[@]}"; do
    printf '  %-16s %s\n' "${summary%%|*}" "${summary#*|}"
  done
  cat <<EOF

${BOLD}OPTIONS${RESET}
  -v, --verbose  Print extra diagnostics
  -y, --yes      Answer yes to confirmations
  -h, --help     Show this help
  --version      Show the version

${BOLD}EXAMPLES${RESET}
  dot init                       # set up a new Mac
  dot update                     # pull and update everything
  dot update --only rex,pi       # update two components
  dot init --dry-run             # show the plan
  dot doctor                     # check this Mac
  dot components                 # what dot manages
  dot package add ripgrep        # install and add to packages/bundle

${BOLD}PATHS${RESET}
  Repository  $(pretty_path "$DOTFILES_DIR")
  dot         $(pretty_path "$DOT_ROOT") (how it works: dot/README.md)
  Packages    $(pretty_path "$PACKAGES_DIR")
  Stow        $(pretty_path "$STOW_DIR") -> ~
EOF
}
