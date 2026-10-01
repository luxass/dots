# shellcheck shell=bash
# The dotfiles Git repository and its private submodules.

repo_git() { git -C "$DOTFILES_DIR" "$@"; }

repo_is_git() { repo_git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# submodule_paths: every submodule path declared in .gitmodules.
submodule_paths() {
  [[ -f "$DOTFILES_DIR/.gitmodules" ]] || return 0
  repo_git config --file .gitmodules --get-regexp '\.path$' | awk '{ print $2 }'
}

submodule_configured() {
  [[ -f "$DOTFILES_DIR/.gitmodules" ]] \
    && repo_git config --file .gitmodules --get "submodule.$1.path" >/dev/null 2>&1
}

# submodule_sync PATH: check PATH out at the commit the parent repo pins.
submodule_sync() {
  local path="$1"
  submodule_configured "$path" || return 0
  print_verbose "Syncing submodule $path to its pinned commit"
  repo_git submodule update --init --recursive -- "$path"
}
