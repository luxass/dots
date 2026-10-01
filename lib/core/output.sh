# shellcheck shell=bash
# Terminal output. Colors are off when stdout is not a terminal or NO_COLOR is set.

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

print_header() { printf '\n%s==>%s %s%s%s\n' "$BOLD$BLUE" "$RESET" "$BOLD" "$1" "$RESET"; }
print_section() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"; }
print_success() { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
print_info() { printf '%sℹ%s %s\n' "$CYAN" "$RESET" "$1"; }
print_warning() { printf '%s⚠%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
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

# pretty_path PATH: shorten $HOME to ~ for display.
pretty_path() {
  # shellcheck disable=SC2088 # a literal ~ for display
  case "$1" in
    "$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}
