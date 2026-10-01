# shellcheck shell=bash
# Machine-local preferences, stored in git-config format at $PREFS_FILE.
# Keys look like packages.brew.fonts.enabled; *.enabled keys are booleans.

prefs_git() { git config --file "$PREFS_FILE" "$@"; }

prefs_get() {
  local key="$1"
  [[ -f "$PREFS_FILE" ]] || return 1
  migrate_legacy_prefs || return 1
  if [[ "$key" == *.enabled ]]; then
    prefs_git --type=bool --get "$key"
  else
    prefs_git --get "$key"
  fi
}

prefs_set() {
  local key="$1" value="$2"
  mkdir -p "$STATE_DIR" || return 1
  migrate_legacy_prefs || return 1
  if [[ "$key" == *.enabled ]]; then
    prefs_git --type=bool "$key" "$value"
  else
    prefs_git "$key" "$value"
  fi
}

prefs_unset() {
  [[ -f "$PREFS_FILE" ]] || return 0
  migrate_legacy_prefs || return 1
  # Exit status 5 means the key was not set.
  prefs_git --unset-all "$1" || [[ "$?" -eq 5 ]]
}

prefs_list() {
  [[ -f "$PREFS_FILE" ]] || return 0
  migrate_legacy_prefs || return 1
  prefs_git --list
}
