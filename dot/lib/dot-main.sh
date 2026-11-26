# shellcheck shell=bash
# dot_main: global options and command dispatch. `dot <command>` runs
# cmd_<command> from dot/commands/<command>.sh. `dot <command> --help` runs
# cmd_<command>_usage from the same file.

# Every command and its one-line description, for `dot help`.
# Arrays are assigned first and marked readonly after: on Bash 3.2,
# `readonly NAME=(...)` inside a function (bats setup) makes a local.
DOT_COMMAND_SUMMARIES=(
  "init|Install everything on this Mac (every component's install step)"
  "update|Pull the repository, then update every component"
  "doctor|Check every component and report problems"
  "components|List components in run order"
  "info|Show paths, runtime versions, and repository status"
  "package|List, add, remove, or upgrade packages in the package lists"
  "check-packages|Report installed and missing packages from the package lists"
  "retry-failed|Retry packages that failed during init"
  "stow|Re-link the Stow packages into HOME"
  "unstow|Remove the Stow links and the shared skills links"
  "hooks|Point Git at .githooks and set up repository filters"
  "secret-scan|Scan tracked and unignored files for secrets"
  "lint|Run shellcheck, shfmt, and the bats tests"
  "benchmark-shell|Time Fish startup, interactive and non-interactive"
  "link|Put dot on PATH with a symlink in ~/.local/bin"
  "unlink|Remove the dot symlink that link created"
  "edit|Open the dotfiles repository in \$EDITOR"
  "help|Show help for dot or one command"
)
readonly DOT_COMMAND_SUMMARIES

# command_function NAME: print the function for a command (init -> cmd_init), or fail.
command_function() {
  local handler

  # CLI names use dashes. cmd_<command>_usage functions are not commands.
  [[ "$1" =~ ^[a-z][a-z-]*$ && "$1" != *-usage ]] || return 1
  handler="cmd_${1//-/_}"
  declare -F "$handler" >/dev/null || return 1
  printf '%s\n' "$handler"
}

dot_main() {
  local command handler

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

  command="${1:-help}"
  [[ "$#" -gt 0 ]] && shift
  if ! handler="$(command_function "$command")"; then
    print_error "Unknown command: $command"
    print_info "Run 'dot help' for the command list"
    return 1
  fi

  # Command help returns before any command side effects.
  if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    cmd_help "$command"
    return
  fi

  pnpm_export_path
  "$handler" "$@"
}
