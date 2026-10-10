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

# The skills CLI's global state was separate from our checked-in collection.
# Keep the original outside Git before clearing it. Never reinstall from it.
migrate_skills_inventory() (
  local path archive tmp dir name tracked
  umask 077
  skills_require_jq || return 1
  [[ -f "$SKILLS_LOCK" && -f "$SKILLS_LOCAL" ]] || {
    print_error "Project skill inventories are missing"
    return 1
  }
  jq -se 'all(.[]; .version == 1 and (.skills | type == "object"))' "$SKILLS_LOCK" "$SKILLS_LOCAL" >/dev/null || return 1

  for path in "${XDG_STATE_HOME:-$HOME/.local/state}/skills/.skill-lock.json" "$HOME/.agents/.skill-lock.json"; do
    if [[ -f "$path" ]]; then
      jq -e '.skills | type == "object"' "$path" >/dev/null || return 1
      # Old installers may have restored skills that Git deliberately removed.
      # Archive only untracked names recorded there and absent from both inventories.
      while IFS= read -r name; do
        [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ && "$name" != *..* ]] || continue
        dir="$SKILLS_DIR/$name"
        [[ -e "$dir" || -L "$dir" ]] || continue
        jq -se --arg name "$name" 'any(.[]; .skills | has($name))' "$SKILLS_LOCK" "$SKILLS_LOCAL" >/dev/null && continue
        tracked="$(repo_git ls-files -- "home/.agents/skills/$name")" || return 1
        [[ -z "$tracked" ]] || continue
        backup_path "$dir" || return 1
      done < <(jq -r '.skills | keys[] | ascii_downcase | gsub("[^a-z0-9._]"; "-") | sub("^[.-]+"; "") | sub("[.-]+$"; "")' "$path")
    fi
    if [[ -L "$path" ]] && [[ "$(readlink "$path")" == *home/.agents/.skill-lock.json ]]; then
      archive="$BACKUP_ROOT/$DOT_RUN_ID/${path#"$HOME"/}"
      if [[ -f "$path" ]]; then
        mkdir -p "$(dirname "$archive")" || return 1
        cp -pL "$path" "$archive.contents.json" || return 1
      fi
      backup_path "$path" || return 1
      continue
    fi
    [[ -f "$path" ]] || continue
    if jq -e '.skills | type == "object" and length == 0' "$path" >/dev/null; then
      continue
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/dot-skills-lock.XXXXXX")" || return 1
    if ! jq -e 'if (.skills | type == "object") then .skills = {} else error("Invalid global skill inventory") end' "$path" >"$tmp"; then
      rm -f "$tmp"
      return 1
    fi
    archive="$BACKUP_ROOT/$DOT_RUN_ID/${path#"$HOME"/}"
    if [[ -L "$path" ]]; then
      mkdir -p "$(dirname "$archive")" || {
        rm -f "$tmp"
        return 1
      }
      cp -pL "$path" "$archive.contents.json" || {
        rm -f "$tmp"
        return 1
      }
    fi
    backup_path "$path" || {
      rm -f "$tmp"
      return 1
    }
    mv "$tmp" "$path" || return 1
    print_info "Cleared obsolete global skill records; the original is in dot backups"
  done

  # Failed/reverted installs can leave trees containing only empty directories.
  # Archive those remnants, but never move actual skill content or tracked files.
  for dir in "$SKILLS_DIR"/*; do
    [[ -d "$dir" && ! -L "$dir" ]] || continue
    name="${dir##*/}"
    jq -se --arg name "$name" 'any(.[]; .skills | has($name))' "$SKILLS_LOCK" "$SKILLS_LOCAL" >/dev/null && continue
    [[ -z "$(find "$dir" \( -type f -o -type l \) -print)" ]] || continue
    tracked="$(repo_git ls-files -- "home/.agents/skills/$name")" || return 1
    [[ -z "$tracked" ]] || continue
    backup_path "$dir" || return 1
  done
)

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
