init_paths() {
  readonly DOTFILES_DIR
  readonly PACKAGES_DIR="${DOTFILES_DIR}/packages"
  readonly HOME_DIR="${DOTFILES_DIR}/home"
  readonly BASE_BUNDLE="${PACKAGES_DIR}/bundle"
  readonly FONTS_BUNDLE="${PACKAGES_DIR}/bundle.fonts"
  readonly WORK_BUNDLE="${PACKAGES_DIR}/bundle.work"
  readonly PERSONAL_BUNDLE="${PACKAGES_DIR}/bundle.personal"
  readonly BACKUP_ROOT="${DOTFILES_DIR}/backups"
  readonly CODEX_DEFAULTS_FILE="${DOTFILES_DIR}/defaults/codex.toml"
  readonly PRIVATE_PI_DIR="${DOTFILES_DIR}/private/pi"
  readonly PRIVATE_OPENCODE_DIR="${DOTFILES_DIR}/private/opencode"
  readonly PRIVATE_OPENCODE_PLUGINS_DIR="${PRIVATE_OPENCODE_DIR}/plugins"
  readonly PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
  readonly PNPM_INSTALL_VERSION="${PNPM_INSTALL_VERSION:-12}"
  readonly PNPM_UPDATE_TAG="${PNPM_UPDATE_TAG:-latest-12}"
  readonly NODE_RUNTIME_VERSION="${NODE_RUNTIME_VERSION:-lts}"
  readonly NPM_RUNTIME_VERSION="${NPM_RUNTIME_VERSION:-12}"
  # Managed pnpm globals. OpenCode is installed through Homebrew.
  readonly PNPM_GLOBAL_PACKAGES=(
    "sfw:sfw"
    "npm@${NPM_RUNTIME_VERSION}:npm"
    "@earendil-works/pi-coding-agent:pi"
  )

  CURRENT_STEP=0
  TOTAL_STEPS=0
  DOT_VERBOSE="${DOT_VERBOSE:-false}"
}
