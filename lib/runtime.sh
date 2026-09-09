enable_cargo_path() {
  local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
  case ":$PATH:" in
    *":$cargo_home/bin:"*) ;;
    *) export PATH="$cargo_home/bin:$PATH" ;;
  esac
}

ensure_rustup() {
  enable_cargo_path

  if command_exists rustup; then
    print_success "rustup is installed"
    return 0
  fi

  print_info "Installing rustup..."

  if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
    enable_cargo_path
    hash -r 2>/dev/null || true
  else
    print_error "Failed to install rustup"
    return 1
  fi

  if command_exists rustup; then
    print_success "rustup installed"
  else
    print_error "rustup install completed, but rustup is not on PATH"
    return 1
  fi
}

enable_pnpm_path() {
  export PNPM_HOME
  case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) export PATH="$PNPM_HOME/bin:$PATH" ;;
  esac
}

enable_pnpm_path

remove_generated_pnpm_shell_config() {
  local fish_config="$HOME/.config/fish/config.fish"
  local temp_file

  [[ -f "$fish_config" ]] || return 0
  grep -qx '# pnpm' "$fish_config" || return 0

  temp_file="${fish_config}.dot.$$"
  awk '
    /^# pnpm$/ { generated = 1; next }
    generated && /^# pnpm end$/ { generated = 0; next }
    !generated { print }
  ' "$fish_config" > "$temp_file"
  mv "$temp_file" "$fish_config"
}

ensure_pnpm() {
  enable_pnpm_path

  local installer_shell pnpm_path pnpm_version pnpm_major
  pnpm_path="$(command -v pnpm 2>/dev/null || true)"
  if command_path_in_pnpm_home "$pnpm_path"; then
    pnpm_version="$(pnpm --version 2>/dev/null || true)"
    pnpm_major="${pnpm_version%%.*}"
    if [[ "$pnpm_major" =~ ^[0-9]+$ ]] && [[ "$pnpm_major" -ge 12 ]]; then
      print_success "pnpm $pnpm_version is installed"
      return 0
    fi
  fi

  if [[ -n "$pnpm_path" ]]; then
    print_warning "pnpm is not a standalone v12+ install from PNPM_HOME: $pnpm_path"
  fi

  print_info "Installing standalone pnpm ${PNPM_INSTALL_VERSION}..."
  installer_shell="$(command -v fish 2>/dev/null || true)"
  if [[ -z "$installer_shell" ]]; then
    print_error "Fish is required before installing standalone pnpm"
    return 1
  fi

  if curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION="$PNPM_INSTALL_VERSION" SHELL="$installer_shell" sh -; then
    remove_generated_pnpm_shell_config
    enable_pnpm_path
    hash -r 2>/dev/null || true
  else
    print_error "Failed to install pnpm"
    return 1
  fi

  pnpm_path="$(command -v pnpm 2>/dev/null || true)"
  if command_path_in_pnpm_home "$pnpm_path"; then
    print_success "pnpm installed"
  else
    print_error "pnpm install completed, but pnpm is not managed from PNPM_HOME"
    return 1
  fi
}

ensure_node_runtime() {
  ensure_pnpm

  print_info "Ensuring pnpm-managed Node.js $NODE_RUNTIME_VERSION"
  pnpm runtime set node "$NODE_RUNTIME_VERSION" -g -y
  enable_pnpm_path
  hash -r 2>/dev/null || true

  local node_path
  node_path="$(command -v node 2>/dev/null || true)"

  if command_path_in_pnpm_home "$node_path"; then
    print_success "Node.js is managed by pnpm"
  else
    print_error "pnpm Node.js setup did not expose a managed node command"
    return 1
  fi
}

ensure_pnpm_globals() {
  ensure_node_runtime

  local entry package command_name
  for entry in "${PNPM_GLOBAL_PACKAGES[@]}"; do
    package="${entry%%:*}"
    command_name="${entry#*:}"
    if [[ "$command_name" == "$entry" ]]; then
      command_name="$package"
    fi

    local command_path
    command_path="$(command -v "$command_name" 2>/dev/null || true)"
    if command_path_in_pnpm_home "$command_path"; then
      if [[ "$command_name" != "npm" ]] || [[ "$(npm --version)" == "${NPM_RUNTIME_VERSION}."* ]]; then
        print_success "$command_name is installed"
        continue
      fi
      print_warning "npm does not match the managed ${NPM_RUNTIME_VERSION}.x release"
    fi

    if [[ -n "$command_path" ]]; then
      print_warning "$command_name is not managed from PNPM_HOME: $command_path"
    fi

    print_info "Installing pnpm global: $package"
    if [[ "$package" == "sfw" ]]; then
      pnpm add -g "$package"
    elif [[ "$package" == "@opencode/cli@beta" ]]; then
      sfw pnpm add -g --allow-build=@opencode/cli "$package"
    else
      sfw pnpm add -g "$package"
    fi
    hash -r 2>/dev/null || true

    command_path="$(command -v "$command_name" 2>/dev/null || true)"
    if command_path_in_pnpm_home "$command_path"; then
      print_success "$command_name installed"
    else
      print_error "$package install completed, but $command_name is not managed from PNPM_HOME"
      return 1
    fi

  done
}

update_pnpm_if_available() {
  if ! command_exists pnpm; then
    print_warning "pnpm is missing; skipping its update check"
    return 0
  fi

  local current_version latest_version
  current_version="$(pnpm --version)"
  if ! latest_version="$(pnpm view "pnpm@${PNPM_UPDATE_TAG}" version 2>/dev/null)" || [[ -z "$latest_version" ]]; then
    print_warning "Could not check for a pnpm update"
    return 0
  fi

  if [[ "$current_version" == "$latest_version" ]]; then
    print_success "pnpm $current_version is current"
    return 0
  fi

  print_info "pnpm $latest_version is available (installed: $current_version)"
  if ! confirm "Update pnpm to $latest_version?" "n"; then
    print_info "Skipping pnpm update"
    return 0
  fi

  pnpm self-update "$latest_version" --yes
  hash -r 2>/dev/null || true

  current_version="$(pnpm --version)"
  if [[ "$current_version" == "$latest_version" ]]; then
    print_success "pnpm updated to $current_version"
  else
    print_error "pnpm update completed, but version $current_version is active"
    return 1
  fi
}

runtime_lookup_path() {
  local old_ifs="$IFS"
  local path_part
  local result=""

  IFS=:
  for path_part in $PATH; do
    if [[ -z "$result" ]]; then
      result="$path_part"
    else
      result="$result:$path_part"
    fi
  done
  IFS="$old_ifs"
  printf '%s\n' "$result"
}

command_path_in_pnpm_home() {
  local command_path="$1"
  [[ -n "$command_path" && "$command_path" == "$PNPM_HOME/bin/"* ]]
}

check_runtime_origins() {
  local failed=0
  local lookup_path command_name command_path

  lookup_path="$(runtime_lookup_path)"

  for command_name in pnpm node npm npx sfw pi opencode2; do
    command_path="$(PATH="$lookup_path" command -v "$command_name" 2>/dev/null || true)"

    if [[ -z "$command_path" ]]; then
      print_error "$command_name is missing"
      failed=1
    elif command_path_in_pnpm_home "$command_path"; then
      print_success "$command_name resolves from PNPM_HOME"
    else
      print_error "$command_name is not managed by pnpm: $command_path"
      failed=1
    fi
  done

  return "$failed"
}

check_file_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    print_error "Missing $path"
    return 1
  fi

  if grep -Eq "$pattern" "$path"; then
    print_success "$label"
    return 0
  fi

  print_error "$label is not configured in $path"
  return 1
}

check_package_manager_policy() {
  local failed=0

  check_file_contains "${HOME_DIR}/.npmrc" '^ignore-scripts=true$' "npm ignore-scripts policy" || failed=1
  check_file_contains "${HOME_DIR}/.npmrc" '^min-release-age=5$' "npm release-age policy" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^minimumReleaseAge: 7200$' "pnpm release-age policy" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^minimumReleaseAgeStrict: true$' "pnpm strict release-age policy" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" "^  - '@opencode/cli-\\*'$" "pnpm OpenCode CLI release-age exception" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" "^  - '@opencode/\\*'$" "pnpm OpenCode plugin release-age exception" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^dangerouslyAllowAllBuilds: false$' "pnpm build approval policy" || failed=1
  check_file_contains "${HOME_DIR}/.bunfig.toml" '^ignoreScripts = true$' "Bun ignoreScripts policy" || failed=1
  check_file_contains "${HOME_DIR}/.bunfig.toml" '^minimumReleaseAge = 432000$' "Bun release-age policy" || failed=1

  return "$failed"
}
