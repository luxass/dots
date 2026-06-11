# spec https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
export XDG_CACHE_HOME="$HOME/.cache";
export XDG_CONFIG_HOME="$HOME/.config";
export XDG_DATA_HOME="$HOME/.local/share";
export EDITOR="nvim";

# node env variables
# https://nodejs.org/api/repl.html#environment-variable-options

# default is ~/.node_repl_history
export NODE_REPL_HISTORY="$HOME/.node_history";

# default is 1000
export NODE_REPL_HISTORY_SIZE="32768";

# default is sloppy, meaning it matches web browsers.
export NODE_REPL_MODE="sloppy";

export MANPAGER="less -X";

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
