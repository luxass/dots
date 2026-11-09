# shellcheck shell=bash
# Machine-local git-config preferences. Reads return 0=present, 1=absent,
# 2=invalid/unreadable. Keep storage and existing keys independent of features.

prefs_git() { git config --file "$PREFS_FILE" "$@"; }

prefs_validate() {
  [[ -e "$PREFS_FILE" || -L "$PREFS_FILE" ]] || return 0
  if [[ ! -f "$PREFS_FILE" || ! -r "$PREFS_FILE" ]] || ! prefs_git --list >/dev/null; then
    print_error "Cannot read preferences at $(pretty_path "$PREFS_FILE")"
    return 2
  fi
}

prefs_get() {
  local key="$1" status
  prefs_validate || return 2
  [[ -f "$PREFS_FILE" ]] || return 1
  if [[ "$key" == *.enabled ]]; then
    prefs_git --type=bool --get "$key" && return 0
  else
    prefs_git --get "$key" && return 0
  fi
  status=$?
  [[ "$status" -eq 1 ]] && return 1
  print_error "Cannot read preference '$key'"
  return 2
}

prefs_set() {
  local key="$1" value="$2"
  prefs_validate || return 2
  mkdir -p "$STATE_DIR" || return 2
  if [[ "$key" == *.enabled ]]; then
    prefs_git --type=bool "$key" "$value" || return 2
  else
    prefs_git "$key" "$value" || return 2
  fi
}

prefs_unset() {
  local status
  prefs_validate || return 2
  [[ -f "$PREFS_FILE" ]] || return 0
  prefs_git --unset-all "$1" && return 0
  status=$?
  [[ "$status" -eq 5 ]] && return 0
  return 2
}

prefs_list() {
  prefs_validate || return 2
  [[ -f "$PREFS_FILE" ]] || return 0
  prefs_git --list || return 2
}
