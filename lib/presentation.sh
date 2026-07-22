cmd_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME}${RESET} - Dotfiles management tool
Version: ${VERSION}

${BOLD}USAGE:${RESET}
  ${SCRIPT_NAME} [GLOBAL OPTIONS] COMMAND [ARGS]

${BOLD}GLOBAL OPTIONS:${RESET}
  -v, --verbose    Print progress and decision-point diagnostics
  -h, --help       Show this help
  --version        Show version

${BOLD}COMMANDS:${RESET}
  init             Initialize Homebrew packages, Stow links, and dot CLI
  update           Pull repo changes, update packages, and restow
  doctor           Run diagnostics
  info             Show repository paths, runtime tools, and git status
  hooks            Install repository Git hooks
  secret-scan      Scan repository for secrets
  package          Package management commands
  skills           Manage shared global Agent Skills
  codex            Synchronize portable Codex preferences
  config           Manage local-only preferences
  git-identity     Create or update ~/.gitconfig.local
  stow             Create symlinks using GNU Stow
  unstow           Remove symlinks using GNU Stow
  help             Show this help

${BOLD}CONFIGURATION:${RESET}
  Dotfiles directory: ${DOTFILES_DIR}
  Packages directory: ${PACKAGES_DIR}
  Home directory:     ${HOME_DIR}
EOF
}
