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

# preference_enabled KEY PROMPT [y|n]: read a boolean preference, asking once
# and saving the answer when it is unset. Non-interactive runs use the default
# without saving it, so the question is asked on the next interactive run.
preference_enabled() {
  local key="$1" prompt="$2" default="${3:-n}" value

  if value="$(prefs_get "$key")"; then
    [[ "$value" == true ]]
    return
  fi

  if [[ "$DOT_YES" == true || ! -t 0 ]]; then
    print_info "$key is unset; using default ($default)"
    [[ "$default" == y ]]
    return
  fi

  if confirm "$prompt" "$default"; then
    prefs_set "$key" true || print_warning "Could not save $key"
    return 0
  fi
  prefs_set "$key" false || print_warning "Could not save $key"
  return 1
}
