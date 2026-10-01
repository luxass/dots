# shellcheck shell=bash
# Repository paths, managed versions, and feature order. Constants only.

readonly HOME_DIR="$DOTFILES_DIR/home"
readonly PACKAGES_DIR="$DOTFILES_DIR/packages"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dot"
readonly PREFS_FILE="$STATE_DIR/preferences"
readonly BACKUP_ROOT="$STATE_DIR/backups"

readonly PRIVATE_PI_DIR="$DOTFILES_DIR/private/pi"
readonly PRIVATE_OPENCODE_DIR="$DOTFILES_DIR/private/opencode"

# Homebrew bundle groups. base is always installed; the others are opt-in per
# machine through the packages.brew.<group>.enabled preference.
readonly BUNDLE_GROUPS=(base fonts work personal)

PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
readonly PNPM_HOME
readonly PNPM_INSTALL_VERSION="${PNPM_INSTALL_VERSION:-12}"
readonly PNPM_UPDATE_TAG="${PNPM_UPDATE_TAG:-latest-12}"
readonly NODE_RUNTIME_VERSION="${NODE_RUNTIME_VERSION:-lts}"
readonly NPM_RUNTIME_VERSION="${NPM_RUNTIME_VERSION:-12}"
# Managed pnpm globals as package:command. OpenCode is installed through Homebrew.
readonly PNPM_GLOBAL_PACKAGES=(
  "sfw:sfw"
  "npm@${NPM_RUNTIME_VERSION}:npm"
  "@earendil-works/pi-coding-agent:pi"
)
readonly SKILLS_CLI_PACKAGE="${SKILLS_CLI_PACKAGE:-skills}"

# Features in run order. lib/features/<name>.sh may define any of these hooks:
#   <name>_prestow   before GNU Stow links home/
#   <name>_poststow  after GNU Stow links home/
#   <name>_deps      install dependencies (runs once pnpm exists)
#   <name>_unstow    before GNU Stow removes links
#   <name>_check     doctor diagnostics; return 1 on failure
# Removing a feature means deleting its file and its entry here.
readonly FEATURES=(homebrew stow skills fish pnpm rust git pi opencode cliproxyapi)
