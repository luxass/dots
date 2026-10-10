# shellcheck shell=bash
# Project-scoped skill inventory; agents consume the collection through global links.

# Relative links let GNU Stow recognise the shared directory as its own.
skills_link_value() {
  local target="$SKILLS_DIR" dir="$HOME/.agents" up=''

  if [[ "$DOTFILES_DIR" == "$HOME"/* ]]; then
    printf '../%s\n' "${target#"$HOME"/}"
    return
  fi
  while [[ "$dir" != / ]]; do
    up+='../'
    dir="$(dirname "$dir")"
  done
  printf '%s%s\n' "$up" "${target#/}"
}

skills_prestow() {
  local agents="$HOME/.agents"

  if [[ -L "$agents" ]] && same_path "$agents" "$HOME_DIR/.agents"; then
    rm "$agents" || return 1
  elif [[ -L "$agents" || (-e "$agents" && ! -d "$agents") ]]; then
    backup_path "$agents" || return 1
  fi
  mkdir -p "$agents" "$SKILLS_DIR" || return 1
  migrate_skills_inventory || return 1
  ensure_link "$agents/skills" "$(skills_link_value)" || return 1
  ensure_link "$HOME/.claude/skills" "$agents/skills"
}

skills_require_jq() {
  command_exists jq && return 0
  print_error "jq is missing; install the base Homebrew bundle with 'dot init'"
  return 1
}

# Both inventories classify every skill exactly once. The external lock stays in
# the upstream CLI's native format; the local inventory is never passed to it.
skills_inventory_validate() {
  local dir="$1" lock="$2" maintained="$3" name path failed=0

  skills_require_jq || return 1
  if [[ ! -d "$dir" || -L "$dir" || ! -f "$lock" || -L "$lock" || ! -f "$maintained" || -L "$maintained" ]]; then
    print_error "Skill files and inventories must be real directories/files in the repository"
    return 1
  fi
  if ! jq -e '
    def name: type == "string" and test("^[a-z0-9][a-z0-9._-]*$") and (contains("..") | not);
    def remote: type == "string" and (test("[[:space:]]") | not) and
      (test("^[^/:[:space:]]+/[^/:[:space:]]+$") or test("^(https?://|ssh://|git://|git@)")) and
      (test("https?://[^/]*@|^(ssh|git)://[^/]*:[^/]*@") | not);
    .version == 1 and (.skills | type == "object") and
    all(.skills | to_entries[];
      (.key | name) and (.value | type == "object") and
      (.value.source | remote) and
      (.value.sourceType | IN("github", "gitlab", "git")) and
      (.value.skillPath | type == "string" and (. == "SKILL.md" or endswith("/SKILL.md")) and
        (test("[[:space:]]|\\\\") | not) and (startswith("/") | not) and
        (split("/") | all(. != ".."))) and
      (.value.computedHash | type == "string" and test("^[0-9a-f]{64}$")) and
      ((.value.sourceUrl // .value.source) | remote) and
      ((.value.ref // "") | type == "string" and (test("[[:space:]]") | not)))
  ' "$lock" >/dev/null; then
    print_error "Invalid external skill inventory: $(pretty_path "$lock")"
    return 1
  fi
  if ! jq -e '
    .version == 1 and (.skills | type == "object") and
    all(.skills | to_entries[];
      (.key | test("^[a-z0-9][a-z0-9._-]*$") and (contains("..") | not)) and
      (.value | type == "string" and length > 0))
  ' "$maintained" >/dev/null; then
    print_error "Invalid local skill inventory: $(pretty_path "$maintained")"
    return 1
  fi
  if ! jq -e --slurpfile local "$maintained" '
    .skills | keys | all(.[]; $local[0].skills[.] == null)
  ' "$lock" >/dev/null; then
    print_error "A skill is classified as both external and locally maintained"
    return 1
  fi

  while IFS= read -r name; do
    path="$dir/$name"
    if [[ ! -d "$path" || -L "$path" || ! -f "$path/SKILL.md" || -L "$path/SKILL.md" ]]; then
      print_error "Inventoried skill '$name' is missing or linked instead of copied"
      failed=1
    fi
  done < <(jq -r '.skills | keys[]' "$lock" "$maintained")

  for path in "$dir"/*; do
    [[ -e "$path" || -L "$path" ]] || continue
    name="${path##*/}"
    if ! jq -se --arg name "$name" 'any(.[]; .skills | has($name))' "$lock" "$maintained" >/dev/null; then
      print_error "Unclassified skill '$name'; use 'dot skills add' or register it in skills-local.json"
      failed=1
    fi
  done
  return "$failed"
}

skills_require_clean() {
  local changes
  changes="$(repo_git status --porcelain --untracked-files=all -- home/.agents/skills skills-lock.json skills-local.json)" || return 1
  [[ -z "$changes" ]] && return 0
  print_error "Skill files or inventories have uncommitted changes; commit or stash them first"
  return 1
}

skills_list() {
  skills_inventory_validate "$SKILLS_DIR" "$SKILLS_LOCK" "$SKILLS_LOCAL" || return 1
  if [[ "${1:-}" == --json ]]; then
    jq -n --slurpfile external "$SKILLS_LOCK" --slurpfile local "$SKILLS_LOCAL" \
      '{external: $external[0].skills, local: $local[0].skills}'
    return
  fi
  {
    printf 'NAME\tKIND\tSOURCE\n'
    jq -r '.skills | to_entries[] | [.key, "external", .value.source] | @tsv' "$SKILLS_LOCK"
    jq -r '.skills | keys[] | [., "local", "locally maintained"] | @tsv' "$SKILLS_LOCAL"
  } | column -t -s $'\t'
}

# Prepare everything on the repo's filesystem before replacing live paths. On
# any failure or signal, restore the backed-up collection and both inventories.
skills_publish() (
  local workspace="$1" staging dir_backup lock_backup local_backup
  local committed=false
  local DOT_RUN_ID="${DOT_RUN_ID}-skills-$$"

  staging="$(mktemp -d "$DOTFILES_DIR/.skills-publish.XXXXXX")" || return 1
  dir_backup="$BACKUP_ROOT/$DOT_RUN_ID/${SKILLS_DIR#"$HOME"/}"
  lock_backup="$BACKUP_ROOT/$DOT_RUN_ID/${SKILLS_LOCK#"$HOME"/}"
  local_backup="$BACKUP_ROOT/$DOT_RUN_ID/${SKILLS_LOCAL#"$HOME"/}"
  trap '
    if [[ "$committed" != true ]]; then
      if [[ -d "$dir_backup" ]]; then rm -rf "$SKILLS_DIR"; mv "$dir_backup" "$SKILLS_DIR" || print_error "Restore skills from $(pretty_path "$dir_backup")"; fi
      if [[ -f "$lock_backup" ]]; then rm -f "$SKILLS_LOCK"; mv "$lock_backup" "$SKILLS_LOCK" || print_error "Restore inventory from $(pretty_path "$lock_backup")"; fi
      if [[ -f "$local_backup" ]]; then rm -f "$SKILLS_LOCAL"; mv "$local_backup" "$SKILLS_LOCAL" || print_error "Restore inventory from $(pretty_path "$local_backup")"; fi
    fi
    rm -rf "$staging"
  ' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  cp -R "$workspace/.agents/skills" "$staging/skills" || return 1
  cp "$workspace/skills-lock.json" "$staging/skills-lock.json" || return 1
  cp "$workspace/skills-local.json" "$staging/skills-local.json" || return 1
  backup_path "$SKILLS_DIR" || return 1
  backup_path "$SKILLS_LOCK" || return 1
  backup_path "$SKILLS_LOCAL" || return 1
  mv "$staging/skills" "$SKILLS_DIR" || return 1
  mv "$staging/skills-lock.json" "$SKILLS_LOCK" || return 1
  mv "$staging/skills-local.json" "$SKILLS_LOCAL" || return 1
  committed=true
)

# Mutations operate only on a disposable project. Even update's automatically
# detected agent mirrors stay there, and prompt state never uses the global lock.
skills_mutate() (
  local action="$1" workspace operation_lock name path preview=false arg
  shift

  skills_require_jq || return 1
  if ! command_exists sfw || ! command_exists pnpm; then
    print_error "Socket Firewall and pnpm are required; run 'dot init'"
    return 1
  fi
  for arg in "$@"; do
    [[ "$arg" == --list || "$arg" == -l ]] && preview=true
  done
  [[ "$preview" == true ]] || skills_require_clean || return 1
  skills_inventory_validate "$SKILLS_DIR" "$SKILLS_LOCK" "$SKILLS_LOCAL" || return 1

  operation_lock="$STATE_DIR/skills-operation.lock"
  mkdir -p "$STATE_DIR" || return 1
  if ! mkdir "$operation_lock" 2>/dev/null; then
    print_error "Another skill operation is active; if interrupted, remove $(pretty_path "$operation_lock")"
    return 1
  fi
  workspace=''
  trap '[[ -z "$workspace" ]] || rm -rf "$workspace"; rmdir "$operation_lock"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  workspace="$(mktemp -d "${TMPDIR:-/tmp}/dot-skills.XXXXXX")" || return 1
  mkdir -p "$workspace/.agents" "$workspace/original" "$workspace/state" || return 1
  cp -R "$SKILLS_DIR" "$workspace/.agents/skills" || return 1
  cp -R "$SKILLS_DIR" "$workspace/original/skills" || return 1
  cp "$SKILLS_LOCK" "$workspace/skills-lock.json" || return 1
  cp "$SKILLS_LOCK" "$workspace/original/skills-lock.json" || return 1
  cp "$SKILLS_LOCAL" "$workspace/skills-local.json" || return 1
  cp "$SKILLS_LOCAL" "$workspace/original/skills-local.json" || return 1

  # Do not misinterpret caller-relative sources in the scratch project.
  if [[ "$action" == add && ("$1" == ./* || "$1" == ../* || "$1" == /* || "$1" == . || "$1" == ..) ]]; then
    print_error "Local skills belong in home/.agents/skills and skills-local.json; add accepts remote Git sources"
    return 1
  fi
  if [[ "$DOT_YES" == true ]]; then
    set -- "$@" --yes
  fi
  (
    cd "$workspace" || return 1
    case "$action" in
      add) XDG_STATE_HOME="$workspace/state" sfw pnpm dlx "$SKILLS_CLI_PACKAGE" add "$@" --agent universal --copy ;;
      update) XDG_STATE_HOME="$workspace/state" sfw pnpm dlx "$SKILLS_CLI_PACKAGE" update "$@" --project --yes ;;
      remove) XDG_STATE_HOME="$workspace/state" sfw pnpm dlx "$SKILLS_CLI_PACKAGE" remove "$@" ;;
    esac
  ) || return 1
  [[ "$preview" != true ]] || return 0
  if [[ "$action" == update ]] && ! jq -e --slurpfile before "$workspace/original/skills-lock.json" '
    (.skills | keys) == ($before[0].skills | keys) and
    all(.skills | to_entries[]; .value.source == $before[0].skills[.key].source and
      .value.sourceType == $before[0].skills[.key].sourceType and
      (.value.sourceUrl // .value.source) == ($before[0].skills[.key].sourceUrl // $before[0].skills[.key].source) and
      .value.ref == $before[0].skills[.key].ref)
  ' "$workspace/skills-lock.json" >/dev/null; then
    print_error "Update changed the selected skills or their upstreams; nothing was published"
    return 1
  fi

  # Only explicit removals may change locally maintained content.
  while IFS= read -r name; do
    path="$workspace/.agents/skills/$name"
    if [[ "$action" == remove && ! -e "$path" && ! -L "$path" ]]; then
      jq --arg name "$name" 'del(.skills[$name])' "$workspace/skills-local.json" >"$workspace/local.next" || return 1
      mv "$workspace/local.next" "$workspace/skills-local.json" || return 1
    elif ! diff -qr "$SKILLS_DIR/$name" "$path" >/dev/null; then
      print_error "Refusing to overwrite locally maintained skill '$name'"
      return 1
    fi
  done < <(jq -r '.skills | keys[]' "$SKILLS_LOCAL")
  skills_inventory_validate "$workspace/.agents/skills" "$workspace/skills-lock.json" "$workspace/skills-local.json" || return 1
  if [[ -n "$(find "$workspace/.agents/skills" -type l -print)" ]]; then
    print_error "Refusing to publish skill content containing symlinks"
    return 1
  fi

  # Recheck after the potentially long download, including changes made by
  # another process. Never publish over edits made while the CLI was running.
  skills_require_clean || return 1
  if ! diff -qr "$SKILLS_DIR" "$workspace/original/skills" >/dev/null \
    || ! cmp -s "$SKILLS_LOCK" "$workspace/original/skills-lock.json" \
    || ! cmp -s "$SKILLS_LOCAL" "$workspace/original/skills-local.json"; then
    print_error "Skills changed during this operation; nothing was published"
    return 1
  fi
  if diff -qr "$SKILLS_DIR" "$workspace/.agents/skills" >/dev/null \
    && cmp -s "$SKILLS_LOCK" "$workspace/skills-lock.json" \
    && cmp -s "$SKILLS_LOCAL" "$workspace/skills-local.json"; then
    print_success "Skills are already current"
    return 0
  fi
  skills_publish "$workspace" || return 1
  print_success "Skill files and inventories updated; review the Git diff"
)

skills_check() {
  local failed=0 path
  check_link "$HOME/.agents/skills" "$SKILLS_DIR" "Agent skills link" || failed=1
  check_link "$HOME/.claude/skills" "$SKILLS_DIR" "Claude skills link" || failed=1
  if skills_inventory_validate "$SKILLS_DIR" "$SKILLS_LOCK" "$SKILLS_LOCAL"; then
    print_success "External and locally maintained skill inventories match the collection"
  else
    failed=1
  fi
  command_exists jq || return 1
  for path in "${XDG_STATE_HOME:-$HOME/.local/state}/skills/.skill-lock.json" "$HOME/.agents/.skill-lock.json"; do
    [[ -f "$path" ]] || continue
    if ! jq -e '.skills | type == "object" and length == 0' "$path" >/dev/null; then
      print_error "Legacy global inventory remains at $(pretty_path "$path"); run 'dot skills migrate'"
      failed=1
    fi
  done
  return "$failed"
}
