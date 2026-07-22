dispatch_command() {
  local command="$1"
  shift

  case "$command" in
    --version) echo "${SCRIPT_NAME} version ${VERSION}" ;;
    -h|--help|help) cmd_help ;;
    init) cmd_init "$@" ;;
    update) cmd_update "$@" ;;
    doctor) cmd_doctor "$@" ;;
    info) cmd_info "$@" ;;
    hooks) cmd_hooks "$@" ;;
    secret-scan) cmd_secret_scan "$@" ;;
    package) cmd_package "$@" ;;
    skills) cmd_skills "$@" ;;
    codex) cmd_codex "$@" ;;
    config) cmd_config "$@" ;;
    git-identity) cmd_git_identity "$@" ;;
    stow) cmd_stow "$@" ;;
    unstow) cmd_unstow "$@" ;;
    *) print_error "Unknown command: $command"; cmd_help; return 1 ;;
  esac
}

main() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -v|--verbose)
        DOT_VERBOSE=true
        shift
        ;;
      --)
        shift
        break
        ;;
      *) break ;;
    esac
  done

  local command="${1:-help}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  dispatch_command "$command" "$@"
}
