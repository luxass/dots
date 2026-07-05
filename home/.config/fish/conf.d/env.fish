# XDG base directories
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"

# Node REPL behavior
set -gx NODE_REPL_HISTORY "$HOME/.node_history"
set -gx NODE_REPL_HISTORY_SIZE 32768
set -gx NODE_REPL_MODE sloppy

# Managed runtime locations
set -gx VP_HOME "$HOME/.vite-plus"
set -gx GOPATH "$HOME/go"
