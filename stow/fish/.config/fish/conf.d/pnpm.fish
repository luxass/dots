# Standalone pnpm and pnpm-managed runtime binaries
set -gx PNPM_HOME "$XDG_DATA_HOME/pnpm"
fish_add_path "$PNPM_HOME/bin"
