# shellcheck shell=bash
# Terminal output and prompts. Colors are off when stdout is not a terminal
# or NO_COLOR is set.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m'
  readonly BLUE=$'\033[0;34m' CYAN=$'\033[0;36m' DIM=$'\033[2m'
  readonly BOLD=$'\033[1m' RESET=$'\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' DIM='' BOLD='' RESET=''
fi

DOT_VERBOSE="${DOT_VERBOSE:-false}"
DOT_YES="${DOT_YES:-false}"
STEP_CURRENT=0
STEP_TOTAL=0
# Warnings printed in this shell. The component runner compares it before and
# after each step to mark steps that succeeded with warnings. Subshells do not add to it.
DOT_WARNING_COUNT=0

print_header() { printf '\n%s==>%s %s%s%s\n' "$BOLD$BLUE" "$RESET" "$BOLD" "$1" "$RESET"; }
print_section() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"; }
print_success() { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
print_info() { printf '%sℹ%s %s\n' "$CYAN" "$RESET" "$1"; }
print_warning() {
  DOT_WARNING_COUNT=$((DOT_WARNING_COUNT + 1))
  printf '%s⚠%s %s\n' "$YELLOW" "$RESET" "$1" >&2
}
print_error() { printf '%s✗%s %s\n' "$RED" "$RESET" "$1" >&2; }

is_verbose() { [[ "$DOT_VERBOSE" == true ]]; }

print_verbose() {
  if is_verbose; then
    print_info "$1"
  fi
}

print_step() {
  STEP_CURRENT=$((STEP_CURRENT + 1))
  printf '\n%s[%d/%d]%s %s\n' "$BOLD" "$STEP_CURRENT" "$STEP_TOTAL" "$RESET" "$1"
}

# indent: prefix stdin lines with two spaces.
indent() { sed 's/^/  /'; }

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

# confirm PROMPT [y|n]: ask a yes/no question. --yes answers yes. Without a
# terminal on stdin, the default answer is used.
confirm() {
  local prompt="$1" default="${2:-n}" hint='[y/N]' reply=''
  [[ "$default" == y ]] && hint='[Y/n]'

  if [[ "$DOT_YES" == true ]]; then
    printf '%s %s yes\n' "$prompt" "$hint"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    printf '%s %s %s (no terminal)\n' "$prompt" "$hint" "$default"
    [[ "$default" == y ]]
    return
  fi

  read -r -p "$prompt $hint: " reply || true
  case "$reply" in
    [yY] | [yY][eE][sS]) return 0 ;;
    '') [[ "$default" == y ]] ;;
    *) return 1 ;;
  esac
}

# pretty_path PATH: shorten $HOME to ~ for display.
pretty_path() {
  # shellcheck disable=SC2088 # a literal ~ for display
  case "$1" in
    "$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}
