# shellcheck shell=bash
# One-time cleanups for older setups. Delete an entry once every machine has run it.

# Preferences used to be key=value lines; they are now git-config format.
# A legacy file has assignments but no [section] headers.
migrate_legacy_prefs() {
  local tmp line key

  if [[ ! -f "$PREFS_FILE" ]] || grep -q '^[[:space:]]*\[' "$PREFS_FILE" || ! grep -q '=' "$PREFS_FILE"; then
    return 0
  fi

  tmp="$(mktemp "$PREFS_FILE.XXXXXX")" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* && "$line" != \#* ]] || continue
    key="${line%%=*}"
    # Git needs a section and a variable name that starts with a letter.
    if [[ ! "$key" =~ ^[A-Za-z0-9.-]+\.[A-Za-z][A-Za-z0-9-]*$ ]]; then
      print_warning "Dropping preference '$key': not a valid key"
      continue
    fi
    if ! git config --file "$tmp" "$key" "${line#*=}"; then
      rm -f "$tmp"
      return 1
    fi
  done <"$PREFS_FILE"
  mv "$tmp" "$PREFS_FILE" || return 1
  print_info "Migrated $(pretty_path "$PREFS_FILE") to git-config format"
}

# Homebrew packages replaced by another entry in a Brewfile, as old:new.
readonly BREW_PACKAGE_REPLACEMENTS=(
  "opencode:anomalyco/tap/opencode-v2"
)

migrate_brew_replacements() {
  local mapping old new
  for mapping in "${BREW_PACKAGE_REPLACEMENTS[@]}"; do
    old="${mapping%%:*}"
    new="${mapping#*:}"
    if brew list --formula "$old" >/dev/null 2>&1; then
      print_info "Removing Homebrew formula $old (replaced by $new)"
      brew uninstall --formula "$old" || return 1
    elif brew list --cask "$old" >/dev/null 2>&1; then
      print_info "Removing Homebrew cask $old (replaced by $new)"
      brew uninstall --cask "$old" || return 1
    fi
  done
}

# OpenCode used to be a pnpm global; it now comes from Homebrew.
migrate_pnpm_opencode() {
  local path
  path="$(command -v opencode 2>/dev/null || true)"
  [[ "$path" == "$PNPM_HOME/bin/"* ]] || return 0

  print_info "Removing the legacy pnpm OpenCode install"
  if sfw pnpm remove -g @opencode/cli; then
    hash -r
  else
    print_warning "Could not remove it; run 'sfw pnpm remove -g @opencode/cli'"
  fi
}
