# shellcheck shell=bash
# Skills use the repo's inventories; lint delegates to pinned tools.

skills_help() {
  cat <<EOF
${BOLD}dot skills${RESET} - tracked shared Agent Skills

  add SOURCE [OPTIONS]   Import remote skills (--skill NAME, --list, --yes)
  list [--json]          List external and locally maintained skills
  update [NAME...]       Upgrade external imports only (--yes)
  remove NAME...         Remove skills and their inventory entries (--yes)
  migrate               Archive and clear obsolete global inventories

Mutations run $SKILLS_CLI_PACKAGE through sfw in a temporary project and
publish only skill files and inventories after success. Commit or stash skill
changes first. The shared global links stay unchanged; global CLI state is
not used. Locally maintained skills are never overwritten by imports.
EOF
}

cmd_skills() {
  local action="${1:-help}" arg names=0 first=true
  [[ "$#" -gt 0 ]] && shift

  case "$action" in
    help | -h | --help)
      skills_help
      return
      ;;
    list)
      [[ "$#" -eq 0 || ("$#" -eq 1 && "$1" == --json) ]] || {
        print_error "Usage: dot skills list [--json]"
        return 1
      }
      skills_list "$@"
      return
      ;;
    migrate)
      no_args "$@" && migrate_skills_inventory
      return
      ;;
    add | update | remove) ;;
    *)
      print_error "Unknown skills command: $action"
      skills_help
      return 1
      ;;
  esac

  skills_require_jq || return 1
  for arg in "$@"; do
    if [[ "$action" == add && "$first" == true ]]; then
      [[ "$arg" != -* ]] || {
        print_error "Usage: dot skills add SOURCE [OPTIONS]"
        return 1
      }
      first=false
      names=$((names + 1))
      continue
    fi
    case "$arg" in
      -y | --yes) ;;
      -s | --skill | -l | --list | --full-depth)
        [[ "$action" == add ]] || {
          print_error "Unsupported $action option: $arg"
          return 1
        }
        ;;
      -*)
        print_error "Unsupported skills option: $arg; dot controls scope and destinations"
        return 1
        ;;
      *)
        names=$((names + 1))
        if [[ "$action" != add ]]; then
          if [[ ! "$arg" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || [[ "$arg" == *..* ]]; then
            print_error "Invalid skill name: $arg"
            return 1
          fi
          if ! jq -se --arg name "$arg" 'any(.[]; .skills | has($name))' "$SKILLS_LOCK" "$SKILLS_LOCAL" >/dev/null; then
            print_error "Unknown skill: $arg"
            return 1
          fi
          if [[ "$action" == update ]] && jq -e --arg name "$arg" '.skills | has($name)' "$SKILLS_LOCAL" >/dev/null; then
            print_error "'$arg' is locally maintained; merge upstream changes manually"
            return 1
          fi
        fi
        ;;
    esac
  done
  if [[ "$action" != update && "$names" -eq 0 ]]; then
    print_error "Usage: dot skills $action $([[ "$action" == add ]] && printf SOURCE || printf NAME) [OPTIONS]"
    return 1
  fi
  migrate_skills_inventory || return 1
  skills_mutate "$action" "$@"
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
