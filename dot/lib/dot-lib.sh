# shellcheck shell=bash
# Load every dot library, component, and command in dependency order.
# Expects DOT_ROOT (dot/) and DOTFILES_DIR (the repository) from dot/bin/dot.

readonly DOT_VERSION="3.0.0"
readonly DOT_LIB_DIR="$DOT_ROOT/lib"
readonly DOT_COMMANDS_DIR="$DOT_ROOT/commands"

# shellcheck source=paths.sh
source "$DOT_LIB_DIR/paths.sh"
# shellcheck source=terminal-output.sh
source "$DOT_LIB_DIR/terminal-output.sh"
# shellcheck source=file-links.sh
source "$DOT_LIB_DIR/file-links.sh"
# shellcheck source=dotfiles-repo.sh
source "$DOT_LIB_DIR/dotfiles-repo.sh"
# shellcheck source=run-lock.sh
source "$DOT_LIB_DIR/run-lock.sh"
# shellcheck source=package-lists.sh
source "$DOT_LIB_DIR/package-lists.sh"
# shellcheck source=package-manager.sh
source "$DOT_LIB_DIR/package-manager.sh"
# shellcheck source=migrations.sh
source "$DOT_LIB_DIR/migrations.sh"
# shellcheck source=component-registry.sh
source "$DOT_LIB_DIR/component-registry.sh"
# shellcheck source=component-runner.sh
source "$DOT_LIB_DIR/component-runner.sh"
# shellcheck source=dot-main.sh
source "$DOT_LIB_DIR/dot-main.sh"

load_components || return 1

# Each dot/commands/<command>.sh defines cmd_<command> (dashes become _).
for dot_command_file in "$DOT_COMMANDS_DIR"/*.sh; do
  # shellcheck source=/dev/null
  source "$dot_command_file"
done
unset dot_command_file
