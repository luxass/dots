# shellcheck shell=bash
# dot stow and dot unstow: link or unlink the Stow packages.

cmd_stow_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot stow

Re-link the Stow packages in $(pretty_path "$STOW_DIR") into HOME (the stow
component's install step). Files that block Stow move to the dot backup
directory first. Plugins, skills links, and app configuration belong to their
components: run 'dot init --only <component>' for those.
EOF
}

cmd_unstow_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot unstow

Remove the Stow links and the shared skills links from HOME.
EOF
}

cmd_stow() {
  no_args "$@" || return 1
  print_header "Linking dotfiles"
  stow_apply
}

cmd_unstow() {
  no_args "$@" || return 1
  print_header "Unlinking dotfiles"
  skills_remove_links || return 1
  stow_remove
}
