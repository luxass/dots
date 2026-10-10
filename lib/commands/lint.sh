# shellcheck shell=bash
# lint: delegate to the repo's pinned tools.

# lint_tool TOOL ARGS...: run a linter at the version pinned in .mise.toml.
# mise only puts those tools on PATH inside ~/dots in an activated shell, so
# run them through `mise exec` from the repo; that also covers Git hooks, GUI
# clients, and running dot from another directory.
lint_tool() {
  (cd "$DOTFILES_DIR" && mise exec -- "$@")
}

# lint: shellcheck and shfmt over dot's own shell code. Style comes from
# .shellcheckrc and .editorconfig.
cmd_lint() {
  local files

  no_args "$@" || return 1
  command_exists mise || {
    print_error "mise is missing; it comes from packages/bundle ('dot init')"
    return 1
  }
  if ! (cd "$DOTFILES_DIR" && mise trust --show 2>/dev/null | grep -q ': trusted'); then
    print_error "mise does not trust $(pretty_path "$DOTFILES_DIR/.mise.toml"); run 'mise trust' in $(pretty_path "$DOTFILES_DIR")"
    return 1
  fi

  files=("$DOTFILES_DIR/dot" "$DOTFILES_DIR"/lib/*/*.sh "$DOTFILES_DIR"/.githooks/*)
  lint_tool shellcheck "${files[@]}" || return 1
  lint_tool shfmt --diff "${files[@]}" || {
    print_error "Formatting differs; run: mise exec -- shfmt --write dot lib .githooks"
    return 1
  }
  print_success "Shell code is clean"
}
