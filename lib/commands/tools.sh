# shellcheck shell=bash
# skills and lint: thin wrappers around other tools.

skills_help() {
  cat <<EOF
${BOLD}dot skills${RESET} - shared global Agent Skills

  add SOURCE [OPTIONS]   Install skills from a URL or source
  list                   List installed skills

Runs 'pnpm dlx $SKILLS_CLI_PACKAGE' through sfw, always with
--global --agent universal (and --copy for add), so skills land in
home/.agents/skills. Other options, such as --skill NAME, --list, and --yes,
are passed through.
EOF
}

cmd_skills() {
  local action="${1:-help}" arg
  [[ "$#" -gt 0 ]] && shift

  for arg in "$@"; do
    case "$arg" in
      -a | --agent | --agent=* | -g | --global | --global=* | --all | --copy)
        print_error "dot skills sets the destination itself; remove '$arg'"
        return 1
        ;;
    esac
  done

  case "$action" in
    add)
      [[ "$#" -gt 0 ]] || {
        print_error "Usage: dot skills add SOURCE [OPTIONS]"
        return 1
      }
      skills_prestow || return 1
      sfw pnpm dlx "$SKILLS_CLI_PACKAGE" add "$@" --global --agent universal --copy
      ;;
    list) sfw pnpm dlx "$SKILLS_CLI_PACKAGE" list "$@" --global --agent universal ;;
    help | -h | --help) skills_help ;;
    *)
      print_error "Unknown skills command: $action"
      skills_help
      return 1
      ;;
  esac
}

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
