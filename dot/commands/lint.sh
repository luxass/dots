# shellcheck shell=bash
# dot lint: shellcheck, shfmt, and the bats tests, at the versions pinned in .mise.toml.

cmd_lint_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot lint

Run shellcheck and shfmt over dot's shell code, then every *.bats test under
dot/, then the Pi extension tests (stow/pi/.pi/agent/extensions/*/test/) when
Node can run TypeScript. Style comes from .shellcheckrc and .editorconfig. The
pre-push hook and CI run this.
EOF
}

# lint_tool TOOL ARGS...: run a tool at the version pinned in .mise.toml.
# mise only puts those tools on PATH inside the repository in an activated
# shell, so run them through `mise exec` from the repository. That also covers
# Git hooks, GUI clients, and running dot from another directory.
lint_tool() {
  (cd "$DOTFILES_DIR" && mise exec -- "$@")
}

cmd_lint() {
  local files tests

  no_args "$@" || return 1
  command_exists mise || {
    print_error "mise is missing; it comes from packages/bundle ('dot init --only packages')"
    return 1
  }
  if ! (cd "$DOTFILES_DIR" && mise trust --show 2>/dev/null | grep -q ': trusted'); then
    print_error "mise does not trust $(pretty_path "$DOTFILES_DIR/.mise.toml"); run 'mise trust' in $(pretty_path "$DOTFILES_DIR")"
    return 1
  fi

  files=(
    "$DOT_ROOT/bin/dot"
    "$DOT_ROOT"/lib/*.sh
    "$DOT_ROOT"/lib/components/*.sh
    "$DOT_ROOT"/commands/*.sh
    "$DOT_ROOT"/tests/*.bash
    "$DOTFILES_DIR"/.githooks/*
  )
  tests=("$DOT_ROOT"/lib/*.bats "$DOT_ROOT"/lib/components/*.bats "$DOT_ROOT"/commands/*.bats)

  lint_tool shellcheck "${files[@]}" "${tests[@]}" || return 1
  lint_tool shfmt --diff "${files[@]}" "${tests[@]}" || {
    print_error "Formatting differs; run: mise exec -- shfmt --write dot .githooks"
    return 1
  }
  lint_tool bats "${tests[@]}" || {
    print_error "bats tests failed"
    return 1
  }
  print_success "Shell code is clean and tests pass"
  lint_pi_extensions
}

# lint_pi_extensions: run the Pi extension tests with Node's built-in test
# runner. They need a Node that strips TypeScript types (22.18 or newer), so
# without one this warns and skips instead of failing.
lint_pi_extensions() {
  local pi_tests output

  pi_tests=("$DOTFILES_DIR"/stow/pi/.pi/agent/extensions/*/test/*.test.ts)
  [[ -e "${pi_tests[0]}" ]] || return 0
  if ! command_exists node || ! node -e 'process.exit(process.features.typescript ? 0 : 1)' 2>/dev/null; then
    print_warning "Skipping Pi extension tests: they need Node 22.18 or newer"
    return 0
  fi
  if ! output="$(cd "$DOTFILES_DIR" && NODE_NO_WARNINGS=1 node --test "${pi_tests[@]}" 2>&1)"; then
    printf '%s\n' "$output" >&2
    print_error "Pi extension tests failed"
    return 1
  fi
  print_success "Pi extension tests pass ($(grep -E '^ℹ tests ' <<<"$output" | awk '{ print $3 }') tests)"
}
