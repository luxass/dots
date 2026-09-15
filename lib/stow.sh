_stow_dotfiles() {
  ensure_stow
  print_verbose "Preparing to stow files from $HOME_DIR to $HOME"
  ensure_private_opencode_submodule
  ensure_private_pi_submodule
  ensure_agent_skills_link
  ensure_claude_skills_link
  prepare_opencode_plugins_target
  backup_conflicts
  print_info "Stowing files from $HOME_DIR to $HOME"
  print_verbose "Running GNU Stow in restow mode for package: home"
  stow --dotfiles -R -d "$DOTFILES_DIR" -t "$HOME" home
  link_private_opencode_plugins
  prune_private_opencode_plugins
  ensure_opencode_plugin_deps
  ensure_pi_extension_deps
  ensure_private_pi_package
  ensure_whisper_model
  ensure_cliproxyapi_config_link
  sync_codex_config || return 1
  print_success "Dotfiles stowed"
}

_unstow_dotfiles() {
  ensure_stow
  print_verbose "Preparing to unstow files from $HOME_DIR"
  unlink_private_opencode_plugins
  prune_private_opencode_plugins
  print_verbose "Running GNU Stow in delete mode for package: home"
  stow --dotfiles -D -d "$DOTFILES_DIR" -t "$HOME" home
  print_success "Dotfiles unstowed"
}

cmd_stow() {
  parse_verbose_args "$@" || return 1
  print_header "Stowing dotfiles"
  _stow_dotfiles
}

cmd_unstow() {
  parse_verbose_args "$@" || return 1
  print_header "Unstowing dotfiles"
  _unstow_dotfiles
}
