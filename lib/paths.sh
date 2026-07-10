init_paths() {
  readonly DOTFILES_DIR
  readonly PACKAGES_DIR="${DOTFILES_DIR}/packages"
  readonly HOME_DIR="${DOTFILES_DIR}/home"
  readonly BASE_BUNDLE="${PACKAGES_DIR}/bundle"
  readonly FONTS_BUNDLE="${PACKAGES_DIR}/bundle.fonts"
  readonly WORK_BUNDLE="${PACKAGES_DIR}/bundle.work"
  readonly BACKUP_ROOT="${DOTFILES_DIR}/backups"
  readonly VP_HOME="${VP_HOME:-$HOME/.vite-plus}"
  readonly NODE_RUNTIME_VERSION="${NODE_RUNTIME_VERSION:-lts}"
  readonly VITE_PLUS_GLOBAL_PACKAGES=("sfw")

  CURRENT_STEP=0
  TOTAL_STEPS=0
  DOT_VERBOSE="${DOT_VERBOSE:-false}"
}
