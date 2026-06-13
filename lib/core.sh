readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[0;33m'
readonly BLUE=$'\033[0;34m'
readonly CYAN=$'\033[0;36m'
readonly RESET=$'\033[0m'
readonly BOLD=$'\033[1m'

print_header() {
  echo -e "\n${BOLD}${BLUE}==>${RESET} ${BOLD}$1${RESET}"
}

print_success() {
  echo -e "${GREEN}✓${RESET} $1"
}

print_error() {
  echo -e "${RED}✗${RESET} $1" >&2
}

print_warning() {
  echo -e "${YELLOW}⚠${RESET} $1"
}

print_info() {
  echo -e "${CYAN}ℹ${RESET} $1"
}

print_step() {
  ((++CURRENT_STEP))
  echo -e "\n${BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}]${RESET} $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-n}"
  local response

  if [[ "$default" == "y" ]]; then
    prompt="$prompt [Y/n]: "
  else
    prompt="$prompt [y/N]: "
  fi

  read -r -p "$prompt" response

  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    [nN][oO]|[nN]) return 1 ;;
    "")
      [[ "$default" == "y" ]]
      ;;
    *) return 1 ;;
  esac
}

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

path_contains() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}
