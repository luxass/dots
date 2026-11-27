# shellcheck shell=bash
# Rex: one-time app install from the appcast, plus configuration.
# Updates belong to the app's own updater; dot never launches or restarts Rex.
# install offers the app only when it is missing, then configures Rex.
# update only configures: it reloads init.lua and writes app preferences.
define_component rex optional "Rex"

rex_cli() {
  if [[ -n "${REX_BIN_DIR:-}" && -x "${REX_BIN_DIR}/rex" ]]; then
    printf '%s\n' "${REX_BIN_DIR}/rex"
  elif [[ -x "$REX_BUNDLED_CLI" ]]; then
    printf '%s\n' "$REX_BUNDLED_CLI"
  else
    return 1
  fi
}

# Print each installed Rex app, one path per line, regardless of its name.
rex_installed_apps() {
  local app

  for app in /Applications/*.app "$HOME"/Applications/*.app; do
    [[ -d "$app" ]] || continue
    [[ "$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist" 2>/dev/null)" == "$REX_BUNDLE_ID" ]] || continue
    printf '%s\n' "$app"
  done
}

# Launch Services returns an empty result when no Rex app is running.
rex_app_running() {
  local app

  app="$(lsappinfo find "bundleID=$REX_BUNDLE_ID" 2>/dev/null)" || return 1
  [[ -n "$app" ]]
}

# Print "BUILD URL" for the newest appcast entry with a download.
rex_latest_release() {
  local appcast release build url

  appcast="$(curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 10 --max-time 30 "$REX_APPCAST_URL")" || return 1
  release="$(awk '
    /<sparkle:version>/ { gsub(/.*<sparkle:version>|<\/sparkle:version>.*/, ""); build = $0 }
    /<enclosure / && build != "" {
      match($0, /url="[^"]+"/)
      url = substr($0, RSTART + 5, RLENGTH - 6)
      if (best == "" || build + 0 > best + 0) { best = build; best_url = url }
      build = ""
    }
    END { if (best != "") print best, best_url }
  ' <<<"$appcast")" || return 1
  read -r build url <<<"$release"
  # Only accept a numeric build from the expected download location.
  [[ "$build" =~ ^[0-9]+$ && "$url" == "$REX_DOWNLOAD_PREFIX"*.dmg ]] || return 1
  printf '%s %s\n' "$build" "$url"
}

# rex_verify_app APP: Superlogical's signed, notarized Rex bundle.
rex_verify_app() {
  local app="$1" details

  codesign --verify --deep --strict "$app" 2>/dev/null || return 1
  details="$(codesign -dv "$app" 2>&1)" || return 1
  grep -qxF "TeamIdentifier=$REX_TEAM_ID" <<<"$details" || return 1
  grep -qxF "Identifier=$REX_BUNDLE_ID" <<<"$details" || return 1
  spctl --assess --type execute "$app" 2>/dev/null
}

# rex_install_dmg URL DEST: copy the verified app from the disk image to DEST.
rex_install_dmg() {
  local url="$1" dest="$2" work app status=1

  [[ ! -e "$dest" && ! -L "$dest" ]] || {
    print_error "$(pretty_path "$dest") already exists; not replacing it"
    return 1
  }
  work="$(mktemp -d "${TMPDIR:-/tmp}/dot-rex.XXXXXX")" || return 1

  print_info "Downloading ${url##*/}"
  if ! curl --proto '=https' --tlsv1.2 -fL --progress-bar -o "$work/rex.dmg" "$url"; then
    print_error "Failed to download Rex"
  elif ! hdiutil attach -nobrowse -readonly -noautoopen -quiet -mountpoint "$work/mount" "$work/rex.dmg"; then
    print_error "Failed to open the Rex disk image"
  else
    app="$work/mount/${dest##*/}"
    if [[ ! -d "$app" ]]; then
      print_error "The Rex disk image has no ${dest##*/}"
    elif ! rex_verify_app "$app"; then
      print_error "Rex failed signature, notarization, or team checks; not installing"
    elif ditto "$app" "$dest.new" && mv "$dest.new" "$dest"; then
      status=0
    else
      print_error "Failed to copy Rex to $(pretty_path "$dest")"
    fi
    hdiutil detach -quiet "$work/mount" || print_warning "Could not detach the Rex disk image"
  fi

  rm -rf "$work" "$dest.new"
  return "$status"
}

# Install Rex when it is missing. Existing installs update themselves.
rex_install() {
  local apps app release build url

  apps="$(rex_installed_apps)"
  if [[ -n "$apps" ]]; then
    read -r app <<<"$apps"
    print_success "Rex is installed (build $(defaults read "$app/Contents/Info" CFBundleVersion 2>/dev/null || echo unknown))"
    return 0
  fi
  confirm "Install Rex (Bleeding Edge) from Superlogical?" y || {
    print_info "Skipping Rex. Installation guide: $REX_INSTALLATION_URL"
    return 0
  }
  release="$(rex_latest_release)" || {
    print_error "Could not read the Rex appcast"
    return 1
  }
  read -r build url <<<"$release"
  print_info "Installing Rex build $build"
  rex_install_dmg "$url" "$REX_INSTALL_PATH" || return 1
  print_success "Rex build $build installed"
  print_info "Launch Rex once to install its CLI, then run 'dot update --only rex'"
}

# Rex generates IDs when it imports themes. Resolve names locally, not in Git.
rex_theme_id() {
  local name="$1" appearance="$2"

  defaults export "$REX_DEFAULTS_DOMAIN" - 2>/dev/null \
    | plutil -extract 'Workspace\.customThemes' raw -o - - 2>/dev/null \
    | base64 -D \
    | jq -er --arg name "$name" --arg appearance "$appearance" '
      [.[] | select(.name == $name and .appearance == $appearance)
        | select(.id | type == "string" and startswith("custom-"))]
      | sort_by(.createdAt // 0) | last | .id // empty
    '
}

# rex_theme_appearance KEY: the appearance a theme preference selects.
rex_theme_appearance() {
  case "$1" in
    Workspace.darkThemeID) printf 'dark\n' ;;
    Workspace.lightThemeID) printf 'light\n' ;;
    *)
      print_error "The Rex theme type is only valid for lightThemeID and darkThemeID"
      return 1
      ;;
  esac
}

# Print "NAME APPEARANCE" for each tracked theme that is not imported yet.
rex_missing_themes() {
  local key type value appearance

  command_exists jq || {
    print_error "Rex theme selection requires jq; run 'dot init --only packages'"
    return 1
  }
  while read -r key type value || [[ -n "$key" ]]; do
    [[ "$type" == theme ]] || continue
    appearance="$(rex_theme_appearance "$key")" || return 1
    rex_theme_id "$value" "$appearance" >/dev/null || printf '%s %s\n' "$value" "$appearance"
  done <"$REX_SETTINGS_FILE"
}

rex_themes_ready() {
  local missing name appearance

  missing="$(rex_missing_themes)" || return 1
  [[ -z "$missing" ]] && return 0
  while read -r name appearance; do
    print_warning "Rex theme $name is not imported; run 'dot update --only rex' while Rex is running"
  done <<<"$missing"
  return 1
}

# Import missing themes through the init.lua import_* actions. Needs the
# running app with Remote Control on; the app writes the import asynchronously.
rex_import_themes() {
  local cli="$1" missing name appearance action tries

  missing="$(rex_missing_themes)" || return 1
  [[ -n "$missing" ]] || return 0
  if ! rex_app_running; then
    print_warning "Launch Rex, then run 'dot update --only rex' to import its themes"
    return 0
  fi
  if [[ "$(defaults read "$REX_DEFAULTS_DOMAIN" rex.client.remoteControl 2>/dev/null || true)" != 1 ]]; then
    print_warning "Rex Remote Control is off; cannot import themes from dot"
    return 0
  fi

  while read -r name appearance; do
    action="import_${name//-/_}"
    if ! "$cli" --autostart=false 'do' "$action" >/dev/null 2>&1; then
      print_warning "Could not import $name; run its Import action from the Rex palette"
      continue
    fi
    tries=0
    while ! rex_theme_id "$name" "$appearance" >/dev/null && [[ "$tries" -lt 10 ]]; do
      sleep 1
      tries=$((tries + 1))
    done
    if rex_theme_id "$name" "$appearance" >/dev/null; then
      print_success "Imported Rex theme $name"
    else
      print_warning "Rex did not report $name as imported yet; run 'dot update --only rex' again"
    fi
  done <<<"$missing"
}

# Back up app preferences once per run, before the first changed setting.
# The backup stays outside Git because preferences can contain private state.
REX_PREFS_BACKED_UP=false

rex_backup_prefs() {
  local backup

  [[ "$REX_PREFS_BACKED_UP" == true ]] && return 0
  REX_PREFS_BACKED_UP=true
  defaults read "$REX_DEFAULTS_DOMAIN" >/dev/null 2>&1 || return 0
  backup="$BACKUP_ROOT/$DOT_RUN_ID/rex-preferences.plist"
  mkdir -p "$(dirname "$backup")" || return 1
  defaults export "$REX_DEFAULTS_DOMAIN" "$backup" >/dev/null || return 1
  print_info "Backed up Rex preferences to $(pretty_path "$backup")"
}

# rex_apply_settings plain|theme: validate every entry, then write the plain
# preferences or the theme selections. Unimported themes are skipped.
rex_apply_settings() {
  local kind="$1" key type value current expected changed=0 skipped=0

  [[ -f "$REX_SETTINGS_FILE" ]] || {
    print_error "Rex app preferences file is missing"
    return 1
  }
  while read -r key type value || [[ -n "$key" ]]; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    # Any key is allowed. Only its syntax is checked, so a typo such as "-x"
    # cannot reach defaults write as an option.
    if [[ ! "$key" =~ ^[A-Za-z][A-Za-z0-9._-]*$ ]]; then
      print_error "Invalid Rex preference key: $key"
      return 1
    fi
    case "$type" in
      string | int | float | bool | theme) ;;
      *)
        print_error "Invalid Rex preference type: $type"
        return 1
        ;;
    esac
    [[ -n "$value" ]] || {
      print_error "Rex preference $key has no value"
      return 1
    }
    if [[ "$type" == theme ]]; then
      expected="$(rex_theme_appearance "$key")" || return 1
      [[ "$kind" == theme ]] || continue
      if ! value="$(rex_theme_id "$value" "$expected")"; then
        skipped=$((skipped + 1))
        continue
      fi
      type=string
    elif [[ "$kind" == theme ]]; then
      continue
    fi
    expected="$value"
    if [[ "$type" == bool ]]; then
      case "$value" in
        true) expected=1 ;;
        false) expected=0 ;;
        *)
          print_error "Invalid boolean for Rex preference $key"
          return 1
          ;;
      esac
    fi
    current="$(defaults read "$REX_DEFAULTS_DOMAIN" "$key" 2>/dev/null || true)"
    [[ "$current" == "$expected" ]] && continue

    rex_backup_prefs || return 1
    defaults write "$REX_DEFAULTS_DOMAIN" "$key" "-$type" "$value" || {
      print_error "Failed to write Rex preference $key"
      return 1
    }
    changed=$((changed + 1))
  done <"$REX_SETTINGS_FILE"

  if [[ "$changed" -gt 0 ]]; then
    print_info "Wrote $changed Rex $kind preferences; relaunch Rex to apply them"
  elif [[ "$skipped" -eq 0 ]]; then
    print_success "Rex $kind preferences are up to date"
  fi
  if [[ "$skipped" -gt 0 ]]; then
    print_warning "Skipped $skipped Rex theme selections until their themes are imported"
  fi
}

rex_terminfo_ready() {
  "$1" --autostart=false terminfo status --json 2>/dev/null \
    | jq -e '.conclusion | type == "string" and startswith("Ready")' >/dev/null
}

# The Rex skill stub that `rex skill setup` writes into the shared skills folder.
readonly REX_SKILL_FILE="$SKILLS_DIR/rex/SKILL.md"
# Agents load the Rex skill only when asked, for example with /skill:rex,
# instead of on their own for every Rex-related prompt.
readonly REX_SKILL_MODEL_LINE="disable-model-invocation: true"

# rex_skill_hide_from_models: add REX_SKILL_MODEL_LINE to the Rex skill's front
# matter. `rex skill setup` writes the stub without it, so run this after every
# setup. A file without front matter is left alone.
rex_skill_hide_from_models() {
  local tmp

  [[ -f "$REX_SKILL_FILE" ]] || return 0
  grep -qxF "$REX_SKILL_MODEL_LINE" "$REX_SKILL_FILE" && return 0
  [[ "$(head -n 1 "$REX_SKILL_FILE")" == --- ]] || return 0

  tmp="$(mktemp "${TMPDIR:-/tmp}/dot-rex-skill.XXXXXX")" || return 1
  # Insert the line before the closing --- of the front matter.
  if ! awk -v line="$REX_SKILL_MODEL_LINE" '
    NR > 1 && !done && $0 == "---" { print line; done = 1 }
    { print }
  ' "$REX_SKILL_FILE" >"$tmp" || ! cat "$tmp" >"$REX_SKILL_FILE"; then
    rm -f "$tmp"
    print_error "Could not update $(pretty_path "$REX_SKILL_FILE")"
    return 1
  fi
  rm -f "$tmp"
  print_success "Rex skill now loads only when asked ($REX_SKILL_MODEL_LINE)"
}

# rex_skill_current_without_model_line CLI: Rex reports the stub as current
# once REX_SKILL_MODEL_LINE is removed. Rex calls any stub it did not write
# outdated, so ask it about a copy without the line, in a temporary HOME.
rex_skill_current_without_model_line() {
  local cli="$1" sandbox state

  [[ -f "$REX_SKILL_FILE" ]] || return 1
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/dot-rex-skill.XXXXXX")" || return 1
  if ! mkdir -p "$sandbox/.agents/skills/rex" \
    || ! grep -vxF "$REX_SKILL_MODEL_LINE" "$REX_SKILL_FILE" >"$sandbox/.agents/skills/rex/SKILL.md"; then
    rm -rf "$sandbox"
    return 1
  fi
  state="$(HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/.config" "$cli" --autostart=false skill status --json 2>/dev/null \
    | jq -r 'first(.harnesses[] | select(.id == "pi") | .items[] | select(.kind == "skill") | .state) // empty' || true)"
  rm -rf "$sandbox"
  [[ "$state" == current ]]
}

# Print agent skill or hook items that are not current. Unsupported hooks
# (agents without hook support) are fine. A skill that is outdated only
# because of REX_SKILL_MODEL_LINE counts as current.
rex_agents_pending() {
  local cli="$1" pending

  pending="$("$cli" --autostart=false skill status --json \
    | jq -r '[.harnesses[] | select(.detected) | .id as $agent | .items[]
      | select(.state != "current" and .state != "unsupported")
      | "\($agent) \(.kind) \(.state)"] | .[]')" || return 1
  if [[ "$pending" == *" skill outdated"* ]] \
    && grep -qxF "$REX_SKILL_MODEL_LINE" "$REX_SKILL_FILE" 2>/dev/null \
    && rex_skill_current_without_model_line "$cli"; then
    pending="$(grep -v ' skill outdated$' <<<"$pending" || true)"
  fi
  if [[ -n "$pending" ]]; then
    printf '%s\n' "$pending"
  fi
}

# Install the xterm-rex terminfo entry. Rex writes it to ~/.terminfo, writes
# an ssh guard to ~/.config/rex/ssh_config (local, not in Git), and adds one
# Include line to ~/.ssh/config so hosts without the entry get xterm-256color.
rex_setup_terminfo() {
  local cli="$1"

  if rex_terminfo_ready "$cli"; then
    print_success "Rex terminfo is set up"
    return 0
  fi
  confirm "Install Rex terminfo (xterm-rex) and add an Include line to ~/.ssh/config?" y || {
    print_info "Skipping Rex terminfo; run 'rex terminfo setup' later"
    return 0
  }
  "$cli" --autostart=false terminfo setup >/dev/null || {
    print_error "rex terminfo setup failed; run it yourself to see why"
    return 1
  }
  if rex_terminfo_ready "$cli"; then
    print_success "Installed Rex terminfo (xterm-rex) and its ssh guard"
  else
    print_warning "Rex terminfo is installed but not ready; run 'rex terminfo status'"
  fi
}

# Install Rex's agent skill and session hooks. The skill lands in the shared
# skills folder and the Claude hook in the tracked ~/.claude/settings.json, so
# run it only when something is missing or outdated, then review the diff.
rex_setup_agents() {
  local cli="$1" pending

  rex_skill_hide_from_models || return 1
  pending="$(rex_agents_pending "$cli")" || {
    print_warning "Could not read Rex agent setup; run 'rex skill status'"
    return 0
  }
  if [[ -z "$pending" ]]; then
    print_success "Rex agent skill and hooks are set up"
    return 0
  fi
  print_info "Rex agent setup needed: $(paste -sd ',' - <<<"$pending" | sed 's/,/, /g')"
  confirm "Install Rex's agent skill and hooks? Tracked files may change; review them before committing." y || {
    print_info "Skipping Rex agent setup; run 'rex skill setup' later"
    return 0
  }
  "$cli" --autostart=false skill setup >/dev/null || {
    print_error "rex skill setup failed; run it yourself to see why"
    return 1
  }
  rex_skill_hide_from_models || return 1
  print_success "Rex agent skill and hooks are set up"
}

# rex_configure: check and reload init.lua, write app preferences, import
# themes, and offer terminfo and agent setup.
rex_configure() {
  local cli

  if [[ -z "$(rex_installed_apps)" ]]; then
    print_info "Rex is not installed; run 'dot init --only rex' to install it"
    return 0
  fi
  if ! cli="$(rex_cli)"; then
    print_warning "Launch Rex once to install its CLI, then run 'dot update --only rex'"
    return 0
  fi
  "$cli" --autostart=false config check >/dev/null || {
    print_error "Rex configuration is invalid; run 'rex config check'"
    return 1
  }
  # Reload first so the theme import actions in init.lua exist.
  if "$cli" --autostart=false server status >/dev/null 2>&1; then
    "$cli" --autostart=false config reload >/dev/null || return 1
    print_success "Rex configuration reloaded"
  fi
  # Plain preferences turn on Remote Control, which the theme import needs.
  rex_apply_settings plain || return 1
  rex_import_themes "$cli" || return 1
  rex_apply_settings theme || return 1
  rex_setup_terminfo "$cli" || return 1
  rex_setup_agents "$cli" || return 1
}

rex_check() {
  local apps cli

  apps="$(rex_installed_apps)"
  if [[ -z "$apps" ]]; then
    print_warning "Rex is not installed; run 'dot init --only rex' to install it"
    return 0
  fi
  if [[ "$apps" == *$'\n'* ]]; then
    print_warning "Multiple copies of Rex are installed:"
    printf '%s\n' "$apps" >&2
  fi
  if ! cli="$(rex_cli)"; then
    print_error "Rex CLI is missing; launch Rex once, then run 'dot update --only rex'"
    return 1
  fi
  "$cli" --autostart=false config check >/dev/null || {
    print_error "Rex configuration is invalid; run 'rex config check'"
    return 1
  }
  rex_themes_ready || return 1
  print_success "Rex CLI, configuration, and imported theme pair"

  # Optional setup the user may decline: warn, never fail.
  if rex_terminfo_ready "$cli"; then
    print_success "Rex terminfo"
  else
    print_warning "Rex terminfo is not set up; run 'dot update --only rex' or 'rex terminfo setup'"
  fi
  local pending
  if ! pending="$(rex_agents_pending "$cli")"; then
    print_warning "Could not read Rex agent setup; run 'rex skill status'"
  elif [[ -n "$pending" ]]; then
    print_warning "Rex agent setup is incomplete: $(paste -sd ',' - <<<"$pending" | sed 's/,/, /g'); run 'dot update --only rex'"
  else
    print_success "Rex agent skill and hooks"
  fi
  if grep -qxF "$REX_SKILL_MODEL_LINE" "$REX_SKILL_FILE" 2>/dev/null; then
    print_success "Rex skill loads only when asked"
  else
    print_warning "Rex skill can load on its own; run 'dot update --only rex'"
  fi
}

component_rex_install() {
  rex_install || return 1
  rex_configure
}

component_rex_update() { rex_configure; }

component_rex_check() { rex_check; }
