readonly PI_PACKAGE_JSON="${HOME_DIR}/.pi/package.json"
readonly PI_SETTINGS_JSON="${HOME_DIR}/.pi/agent/settings.json"
readonly PLANNOTATOR_PACKAGE="@plannotator/pi-extension"
readonly POCOCK_SYNC_SKILL="${HOME_DIR}/.pi/agent/skills/sync-pocock-skills/SKILL.md"

require_pi_tooling() {
  local failed=0

  for tool in pi pnpm node; do
    if command_exists "$tool"; then
      continue
    fi
    print_error "$tool is required for Pi management"
    failed=1
  done

  return "$failed"
}

pi_package_version() {
  local package_name="$1"

  node -e '
    const fs = require("fs");
    const packagePath = process.argv[1];
    const packageName = process.argv[2];
    const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
    const version = pkg.dependencies?.[packageName] ?? pkg.devDependencies?.[packageName];
    if (version) console.log(version);
  ' "$PI_PACKAGE_JSON" "$package_name"
}

set_pi_package_version() {
  local version="$1"

  node -e '
    const fs = require("fs");
    const packagePath = process.argv[1];
    const version = process.argv[2];
    const packageNames = [
      "@earendil-works/pi-ai",
      "@earendil-works/pi-coding-agent",
      "@earendil-works/pi-tui",
    ];
    const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
    pkg.dependencies ??= {};
    for (const packageName of packageNames) {
      if (Object.hasOwn(pkg.dependencies, packageName)) {
        pkg.dependencies[packageName] = version;
      }
    }
    fs.writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`);
  ' "$PI_PACKAGE_JSON" "$version"
}

ensure_plannotator_share_disabled() {
  local env_line='export PLANNOTATOR_SHARE="disabled";'
  local zshenv="${HOME_DIR}/.zshenv"

  if grep -q '^export PLANNOTATOR_SHARE=' "$zshenv"; then
    print_success "PLANNOTATOR_SHARE is already configured"
    return 0
  fi

  {
    printf '\n'
    printf '# Plannotator sharing is opt-in for Pi sessions.\n'
    printf '%s\n' "$env_line"
  } >> "$zshenv"

  print_success "Disabled Plannotator sharing by default"
}

print_pi_settings_packages() {
  node -e '
    const fs = require("fs");
    const settingsPath = process.argv[1];
    if (!fs.existsSync(settingsPath)) {
      console.log("Settings packages: missing settings file");
      process.exit(0);
    }

    const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
    const keys = ["packages", "extensions"];
    let printed = false;
    for (const key of keys) {
      const value = settings[key];
      if (!value) continue;
      printed = true;
      console.log(`${key}:`);
      if (Array.isArray(value)) {
        for (const item of value) console.log(`  ${typeof item === "string" ? item : JSON.stringify(item)}`);
      } else {
        for (const [name, item] of Object.entries(value)) console.log(`  ${name}: ${typeof item === "string" ? item : JSON.stringify(item)}`);
      }
    }
    if (!printed) console.log("Settings packages: none");
  ' "$PI_SETTINGS_JSON"
}

run_pocock_skills_sync() {
  if [[ ! -f "$POCOCK_SYNC_SKILL" ]]; then
    print_warning "sync-pocock-skills is not installed; skipping skills sync"
    return 0
  fi

  print_info "Running headless Pi skills sync..."
  if (cd "$DOTFILES_DIR" && pi -p --no-skills --skill "$POCOCK_SYNC_SKILL" "/skill:sync-pocock-skills"); then
    print_success "Matt Pocock skills sync complete"
  else
    print_error "Matt Pocock skills sync failed"
    return 1
  fi
}

cmd_pi_status() {
  print_header "Pi status"

  if command_exists pi; then
    printf "Installed Pi:        "
    pi --version
  else
    echo "Installed Pi:        missing"
  fi

  if command_exists pnpm; then
    printf "Latest Pi npm:       "
    pnpm view @earendil-works/pi-coding-agent version 2>/dev/null || echo "unknown"
    printf "Latest Plannotator:  "
    pnpm view "$PLANNOTATOR_PACKAGE" version 2>/dev/null || echo "unknown"
  else
    echo "Latest Pi npm:       pnpm missing"
    echo "Latest Plannotator:  pnpm missing"
  fi

  if [[ -f "$PI_PACKAGE_JSON" ]]; then
    printf "Pinned Pi package:   "
    pi_package_version "@earendil-works/pi-coding-agent" || echo "unknown"
  else
    echo "Pinned Pi package:   missing $PI_PACKAGE_JSON"
  fi

  echo
  print_header "Configured Pi packages"
  if command_exists pi; then
    pi list || true
  else
    print_warning "pi is not installed"
  fi
  print_pi_settings_packages
}

cmd_pi_update() {
  local version="${1:-}"

  if [[ -z "$version" ]]; then
    print_error "Usage: dot pi update VERSION"
    return 1
  fi

  require_pi_tooling || return 1

  if [[ ! -f "$PI_PACKAGE_JSON" ]]; then
    print_error "Missing $PI_PACKAGE_JSON"
    return 1
  fi

  print_header "Updating Pi to $version"
  set_pi_package_version "$version"

  print_info "Refreshing Pi lockfile"
  (cd "${HOME_DIR}/.pi" && pnpm install --lockfile-only --ignore-scripts --config.minimumReleaseAge=0)

  print_info "Updating Pi and configured packages"
  if (cd "$DOTFILES_DIR" && pi update); then
    print_success "Pi and configured packages updated"
  else
    print_error "Failed to update Pi and configured packages"
    return 1
  fi

  local installed_version
  installed_version="$(pi --version)"
  if [[ "$installed_version" != "$version" ]]; then
    print_error "Pi version is $installed_version; expected $version"
    return 1
  fi
  print_success "Pi version verified: $installed_version"

  run_pocock_skills_sync
  cmd_doctor
}

cmd_pi_extension_install() {
  local name="${1:-}"
  local version="${2:-}"
  local source

  if [[ -z "$name" || -z "$version" ]]; then
    print_error "Usage: dot pi extension install NAME VERSION"
    return 1
  fi

  require_pi_tooling || return 1

  case "$name" in
    plannotator)
      source="npm:${PLANNOTATOR_PACKAGE}@${version}"
      ensure_plannotator_share_disabled
      ;;
    *)
      print_error "Unknown managed Pi extension: $name"
      return 1
      ;;
  esac

  print_header "Installing Pi extension: $name $version"
  print_info "Installing $source"
  if (
    cd "$DOTFILES_DIR" &&
      PLANNOTATOR_SHARE=disabled \
      NPM_CONFIG_IGNORE_SCRIPTS=true \
      NPM_CONFIG_MIN_RELEASE_AGE=0 \
      pi install "$source"
  ); then
    print_success "$name installed"
  else
    print_error "Failed to install $name"
    return 1
  fi

  cmd_doctor
}

cmd_pi_extension() {
  local subcommand="${1:-help}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    install) cmd_pi_extension_install "$@" ;;
    help|-h|--help) cmd_pi_help ;;
    *) print_error "Unknown pi extension command: $subcommand"; cmd_pi_help; return 1 ;;
  esac
}

cmd_pi_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} pi${RESET}

${BOLD}USAGE:${RESET}
  ${SCRIPT_NAME} pi status
  ${SCRIPT_NAME} pi update VERSION
  ${SCRIPT_NAME} pi extension install plannotator VERSION

${BOLD}COMMANDS:${RESET}
  status                         Show installed, latest, and pinned Pi state
  update VERSION                 Update tracked Pi pins, run 'pi update', verify version, and run doctor
  extension install NAME VERSION Install a managed pinned Pi extension
EOF
}

cmd_pi() {
  local subcommand="${1:-status}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    status) cmd_pi_status "$@" ;;
    update) cmd_pi_update "$@" ;;
    extension) cmd_pi_extension "$@" ;;
    help|-h|--help) cmd_pi_help ;;
    *) print_error "Unknown pi command: $subcommand"; cmd_pi_help; return 1 ;;
  esac
}
