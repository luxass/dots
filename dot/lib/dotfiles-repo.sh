# shellcheck shell=bash
# The dotfiles Git repository.

repo_git() { git -C "$DOTFILES_DIR" "$@"; }

repo_is_git() { repo_git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
