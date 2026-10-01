# shellcheck shell=bash
# Argument parsing, command dispatch, and feature hooks.
# `dot foo-bar` runs cmd_foo_bar, defined in lib/commands/.

command_exists() { command -v "$1" >/dev/null 2>&1; }

# no_args "$@": a command takes no arguments beyond the global flags.
no_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -v | --verbose) DOT_VERBOSE=true ;;
      -y | --yes) DOT_YES=true ;;
      *)
        print_error "Unexpected argument: $arg"
        return 1
        ;;
    esac
  done
}

# run_hook HOOK: call <feature>_<HOOK> for every feature that defines it.
# All features run; returns 1 if any of them failed.
run_hook() {
  local hook="$1" feature failed=0
  for feature in "${FEATURES[@]}"; do
    if declare -F "${feature}_$hook" >/dev/null; then
      "${feature}_$hook" || failed=1
    fi
  done
  return "$failed"
}

main() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -v | --verbose) DOT_VERBOSE=true ;;
      -y | --yes) DOT_YES=true ;;
      -h | --help)
        set -- help
        break
        ;;
      --version)
        printf 'dot %s\n' "$DOT_VERSION"
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        print_error "Unknown option: $1"
        return 1
        ;;
      *) break ;;
    esac
    shift
  done

  local command="${1:-help}"
  [[ "$#" -gt 0 ]] && shift

  local handler="cmd_${command//-/_}"
  if [[ "$command" == -* ]] || ! declare -F "$handler" >/dev/null; then
    print_error "Unknown command: $command"
    print_info "Run 'dot help' for the command list"
    return 1
  fi

  pnpm_export_path
  "$handler" "$@"
}
