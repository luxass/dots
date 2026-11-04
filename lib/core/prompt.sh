# shellcheck shell=bash
# Interactive prompts. --yes answers yes; without a terminal the default is used.

# confirm PROMPT [y|n]
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

# Bundle choices need explicit answers, unlike ordinary confirmations.
preference_interactive() { [[ -t 0 && "$DOT_YES" != true ]]; }

preference_ask() {
  local reply
  while true; do
    read -r -p "$1 [y/n]: " reply || return 2
    case "$reply" in
      y | Y | yes | YES) return 0 ;;
      n | N | no | NO) return 1 ;;
      *) print_info "Answer yes or no" ;;
    esac
  done
}

# preference_enabled KEY PROMPT: 0=enabled, 1=disabled, 2=unresolved/error.
preference_enabled() {
  local key="$1" prompt="$2" value status
  if value="$(prefs_get "$key")"; then
    [[ "$value" == true ]]
    return
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] || return 2
  if ! preference_interactive; then
    print_error "$key is unset; set it explicitly with 'dot config set $key true' or false"
    return 2
  fi

  if preference_ask "$prompt"; then
    prefs_set "$key" true || return 2
    return 0
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] || return 2
  prefs_set "$key" false || return 2
  return 1
}
