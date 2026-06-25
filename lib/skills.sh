readonly AGENT_SKILLS_DIR="${DOTFILES_DIR}/home/.agents/skills"
readonly HOME_AGENTS_DIR="$HOME/.agents"
readonly HOME_AGENT_SKILLS_DIR="$HOME_AGENTS_DIR/skills"
# Keep this relative so GNU Stow recognises ~/.agents/skills as an owned link.
readonly AGENT_SKILLS_LINK_TARGET="../${DOTFILES_DIR#$HOME/}/home/.agents/skills"
readonly SKILLS_CLI_PACKAGE="${SKILLS_CLI_PACKAGE:-skills}"

skills_directory_contains_only_managed_links() {
  local target_dir="$1"
  local source_dir="$2"
  local entry name expected

  while IFS= read -r -d '' entry; do
    [[ -L "$entry" ]] || return 1
    name="${entry##*/}"
    expected="$source_dir/$name"
    [[ -e "$expected" ]] || return 1
    [[ "$(realpath "$entry")" == "$(realpath "$expected")" ]] || return 1
  done < <(find "$target_dir" -mindepth 1 -maxdepth 1 -print0)

  return 0
}

ensure_agent_skills_parent_dir() {
  local source_agents_dir="${DOTFILES_DIR}/home/.agents"
  local source_resolved resolved

  mkdir -p "$source_agents_dir"
  source_resolved="$(realpath "$source_agents_dir")"

  if [[ -L "$HOME_AGENTS_DIR" ]]; then
    resolved="$(realpath "$HOME_AGENTS_DIR" 2>/dev/null || true)"
    if [[ "$resolved" == "$source_resolved" ]]; then
      rm "$HOME_AGENTS_DIR"
      mkdir -p "$HOME_AGENTS_DIR"
      print_info "Unfolded ~/.agents so ~/.agents/skills can be managed directly"
    else
      backup_path "$HOME_AGENTS_DIR" "$BACKUP_ROOT/$(timestamp)"
      mkdir -p "$HOME_AGENTS_DIR"
    fi
  elif [[ -e "$HOME_AGENTS_DIR" && ! -d "$HOME_AGENTS_DIR" ]]; then
    backup_path "$HOME_AGENTS_DIR" "$BACKUP_ROOT/$(timestamp)"
    mkdir -p "$HOME_AGENTS_DIR"
  else
    mkdir -p "$HOME_AGENTS_DIR"
  fi
}

ensure_agent_skills_link() {
  ensure_agent_skills_parent_dir
  mkdir -p "$AGENT_SKILLS_DIR"

  if [[ -L "$HOME_AGENT_SKILLS_DIR" ]]; then
    if [[ "$(realpath "$HOME_AGENT_SKILLS_DIR")" == "$(realpath "$AGENT_SKILLS_DIR")" ]]; then
      if [[ "$(readlink "$HOME_AGENT_SKILLS_DIR")" == "$AGENT_SKILLS_LINK_TARGET" ]]; then
        return 0
      fi
      rm "$HOME_AGENT_SKILLS_DIR"
    else
      backup_path "$HOME_AGENT_SKILLS_DIR" "$BACKUP_ROOT/$(timestamp)"
    fi
  elif [[ -e "$HOME_AGENT_SKILLS_DIR" ]]; then
    if [[ -d "$HOME_AGENT_SKILLS_DIR" ]] && skills_directory_contains_only_managed_links "$HOME_AGENT_SKILLS_DIR" "$AGENT_SKILLS_DIR"; then
      find "$HOME_AGENT_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type l -delete
      rmdir "$HOME_AGENT_SKILLS_DIR"
    else
      backup_path "$HOME_AGENT_SKILLS_DIR" "$BACKUP_ROOT/$(timestamp)"
    fi
  fi

  ln -s "$AGENT_SKILLS_LINK_TARGET" "$HOME_AGENT_SKILLS_DIR"
  print_success "Linked ~/.agents/skills -> home/.agents/skills"
}

check_agent_skills_link() {
  if [[ -L "$HOME_AGENT_SKILLS_DIR" ]] && [[ "$(realpath "$HOME_AGENT_SKILLS_DIR")" == "$(realpath "$AGENT_SKILLS_DIR")" ]]; then
    print_success "Agent skills link"
    return 0
  fi

  print_error "Agent skills are not linked at ~/.agents/skills"
  return 1
}

cmd_skills_list() {
  if [[ "$#" -gt 0 ]]; then
    print_error "Usage: ${SCRIPT_NAME} skills list"
    return 1
  fi

  if ! command_exists pnpm; then
    print_error "pnpm is required to run the skills CLI"
    return 1
  fi
  if ! command_exists sfw; then
    print_error "Socket Firewall (sfw) is required to run the skills CLI"
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
  if ! command_exists sfw; then
    print_error "Socket Firewall (sfw) is required to run the skills CLI"
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
  add URL [OPTIONS]  Install shared global skills with 'sfw pnpm dlx skills add --global --agent universal --copy'
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
