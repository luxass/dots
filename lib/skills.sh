readonly SKILLS_CLI_PACKAGE="${SKILLS_CLI_PACKAGE:-skills}"

cmd_skills_list() {
  if [[ "$#" -gt 0 ]]; then
    print_error "Usage: ${SCRIPT_NAME} skills list"
    return 1
  fi

  if ! command_exists pnpm; then
    print_error "pnpm is required to run the skills CLI"
    return 1
  fi

  sfw pnpm dlx "$SKILLS_CLI_PACKAGE" list --global --agent universal
}

cmd_skills_add() {
  local source="${1:-}"
  local list_only=false
  local -a extra_args=()

  if [[ -z "$source" ]]; then
    print_error "Usage: ${SCRIPT_NAME} skills add URL [skills options...]"
    return 1
  fi
  shift

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s|--skill)
        local skill_flag="$1"
        extra_args+=("$skill_flag")
        shift
        if [[ "$#" -eq 0 ]]; then
          print_error "$skill_flag requires at least one skill name"
          return 1
        fi
        if [[ "$1" == -* ]]; then
          print_error "$skill_flag requires at least one skill name"
          return 1
        fi
        while [[ "$#" -gt 0 && "$1" != -* ]]; do
          extra_args+=("$1")
          shift
        done
        ;;
      -l|--list)
        list_only=true
        extra_args+=("$1")
        shift
        ;;
      -y|--yes|--full-depth)
        extra_args+=("$1")
        shift
        ;;
      -a|--agent|--agent=*|-g|--global|--global=*|--all|--copy)
        print_error "dot skills add manages destination flags; do not pass '$1'"
        return 1
        ;;
      --)
        shift
        if [[ "$#" -gt 0 ]]; then
          print_error "Unexpected extra argument: $1"
          return 1
        fi
        ;;
      -*)
        print_error "Unsupported skills add option: $1"
        print_info "Supported extra options: --skill, --list, --yes, --full-depth"
        return 1
        ;;
      *)
        print_error "Unexpected extra argument: $1"
        print_info "Use --skill NAME to choose skills from a multi-skill source"
        return 1
        ;;
    esac
  done

  if ! command_exists pnpm; then
    print_error "pnpm is required to run the skills CLI"
    return 1
  fi

  if [[ "$list_only" != "true" ]]; then
    ensure_agent_skills_link
  fi

  sfw pnpm dlx "$SKILLS_CLI_PACKAGE" add "$source" --global --agent universal --copy "${extra_args[@]}"
}

cmd_skills_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} skills${RESET}

${BOLD}USAGE:${RESET}
  ${SCRIPT_NAME} skills add URL [skills options...]
  ${SCRIPT_NAME} skills list

${BOLD}COMMANDS:${RESET}
  add URL [OPTIONS]  Install shared global skills with 'pnpm dlx skills add --global --agent universal --copy'
  list               List installed shared global skills with the skills CLI
  help               Show this help

${BOLD}ADD OPTIONS:${RESET}
  --skill NAME...    Install specific skills from a multi-skill source
  --list             List skills available from the source without installing
  --yes              Skip skills CLI confirmation prompts
  --full-depth       Let the skills CLI search all subdirectories
EOF
}

cmd_skills() {
  local subcommand="${1:-help}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    add) cmd_skills_add "$@" ;;
    list) cmd_skills_list "$@" ;;
    help|-h|--help) cmd_skills_help ;;
    *) print_error "Unknown skills command: $subcommand"; cmd_skills_help; return 1 ;;
  esac
}
