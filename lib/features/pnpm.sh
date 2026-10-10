# shellcheck shell=bash
# Standalone pnpm, pnpm-managed Node.js, pnpm globals, and package-manager policy.

pnpm_export_path() {
  export PNPM_HOME
  case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) export PATH="$PNPM_HOME/bin:$PATH" ;;
  esac
}

in_pnpm_home() { [[ -n "$1" && "$1" == "$PNPM_HOME/bin/"* ]]; }

# The pnpm installer appends a "# pnpm" block to config.fish, which is a
# tracked file. Fish already gets PNPM_HOME from conf.d, so drop the block.
pnpm_remove_installer_block() {
  local config="$HOME/.config/fish/config.fish" tmp
  [[ -f "$config" ]] && grep -qx '# pnpm' "$config" || return 0

  tmp="$(mktemp "$config.XXXXXX")" || return 1
  awk '
    /^# pnpm$/ { skip = 1; next }
    skip && /^# pnpm end$/ { skip = 0; next }
    !skip { print }
  ' "$config" >"$tmp" && mv "$tmp" "$config"
}

pnpm_install_standalone() {
  local path version fish
  path="$(command -v pnpm 2>/dev/null || true)"
  if in_pnpm_home "$path"; then
    version="$(pnpm --version 2>/dev/null || true)"
    if [[ "${version%%.*}" =~ ^[0-9]+$ && "${version%%.*}" -ge "$PNPM_INSTALL_VERSION" ]]; then
      print_success "pnpm $version"
      return 0
    fi
  elif [[ -n "$path" ]]; then
    print_warning "pnpm at $path is not the standalone install in PNPM_HOME"
  fi

  fish="$(command -v fish 2>/dev/null)" || {
    print_error "Fish is required to install standalone pnpm"
    return 1
  }

  print_info "Installing standalone pnpm $PNPM_INSTALL_VERSION"
  if ! curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION="$PNPM_INSTALL_VERSION" SHELL="$fish" sh -; then
    print_error "Failed to install pnpm"
    return 1
  fi
  pnpm_remove_installer_block || return 1
  hash -r

  if ! in_pnpm_home "$(command -v pnpm 2>/dev/null || true)"; then
    print_error "pnpm installed, but it does not resolve from PNPM_HOME"
    return 1
  fi
  print_success "pnpm installed"
}

pnpm_install_node() {
  print_info "Ensuring pnpm-managed Node.js $NODE_RUNTIME_VERSION"
  pnpm runtime set node "$NODE_RUNTIME_VERSION" -g -y || return 1
  hash -r

  if ! in_pnpm_home "$(command -v node 2>/dev/null || true)"; then
    print_error "pnpm set up Node.js, but node does not resolve from PNPM_HOME"
    return 1
  fi
  print_success "Node.js $(node --version)"
}

pnpm_install_globals() {
  local entry package command path

  for entry in "${PNPM_GLOBAL_PACKAGES[@]}"; do
    package="${entry%%:*}"
    command="${entry#*:}"
    path="$(command -v "$command" 2>/dev/null || true)"

    if in_pnpm_home "$path"; then
      if [[ "$command" != npm || "$(npm --version)" == "$NPM_RUNTIME_VERSION".* ]]; then
        print_success "$command"
        continue
      fi
      print_warning "npm is not the managed $NPM_RUNTIME_VERSION.x release"
    elif [[ -n "$path" ]]; then
      print_warning "$command at $path is not managed from PNPM_HOME"
    fi

    print_info "Installing pnpm global $package"
    # sfw installs itself without the firewall; everything else goes through it.
    if [[ "$package" == sfw ]]; then
      pnpm add -g "$package" || return 1
    else
      sfw pnpm add -g "$package" || return 1
    fi
    hash -r

    if ! in_pnpm_home "$(command -v "$command" 2>/dev/null || true)"; then
      print_error "$package installed, but $command does not resolve from PNPM_HOME"
      return 1
    fi
    print_success "$command installed"
  done
}

pnpm_setup() {
  pnpm_install_standalone && pnpm_install_node && pnpm_install_globals
}

# pnpm_install_deps DIR LABEL: install a package.json's dependencies through sfw.
pnpm_install_deps() {
  local dir="$1" label="$2"
  [[ -f "$dir/package.json" ]] || return 0

  if ! command_exists sfw; then
    print_warning "Skipping $label dependencies until sfw is installed ('dot init')"
    return 0
  fi

  print_info "Installing $label dependencies"
  if ! (cd "$dir" && sfw pnpm install); then
    print_error "Failed to install $label dependencies in $(pretty_path "$dir")"
    return 1
  fi
}

pnpm_update() {
  local current latest

  if ! command_exists pnpm; then
    print_warning "pnpm is missing; skipping its update check"
    return 0
  fi

  current="$(pnpm --version)"
  if ! latest="$(pnpm view "pnpm@$PNPM_UPDATE_TAG" version 2>/dev/null)" || [[ -z "$latest" ]]; then
    print_warning "Could not check for a pnpm update"
    return 0
  fi
  if [[ "$current" == "$latest" ]]; then
    print_success "pnpm $current is current"
    return 0
  fi

  print_info "pnpm $latest is available (installed: $current)"
  confirm "Update pnpm to $latest?" n || return 0
  pnpm self-update "$latest" --yes || return 1
  hash -r
  print_success "pnpm $(pnpm --version)"
}

pnpm_check_origins() {
  local command path failed=0

  for command in pnpm node npm npx sfw pi agent-browser; do
    path="$(command -v "$command" 2>/dev/null || true)"
    if [[ -z "$path" ]]; then
      print_error "$command is missing; run 'dot init'"
      failed=1
    elif in_pnpm_home "$path"; then
      print_success "$command resolves from PNPM_HOME"
    else
      print_error "$command is not managed by pnpm: $path"
      failed=1
    fi
  done

  if brew list --formula opencode-v2 >/dev/null 2>&1; then
    print_success "opencode is installed through Homebrew"
  else
    print_error "opencode is not installed through Homebrew (anomalyco/tap/opencode-v2)"
    failed=1
  fi
  return "$failed"
}

# policy_check FILE PATTERN LABEL: a tracked policy file contains a setting.
policy_check() {
  if grep -Eq "$2" "$HOME_DIR/$1" 2>/dev/null; then
    print_success "$3"
  else
    print_error "$3 is not set in home/$1"
    return 1
  fi
}

pnpm_check() {
  local failed=0
  pnpm_check_origins || failed=1
  policy_check .npmrc '^ignore-scripts=true$' "npm ignore-scripts" || failed=1
  policy_check .npmrc '^min-release-age=5$' "npm release age" || failed=1
  policy_check .config/pnpm/config.yaml '^minimumReleaseAge: 7200$' "pnpm release age" || failed=1
  policy_check .config/pnpm/config.yaml '^minimumReleaseAgeStrict: true$' "pnpm strict release age" || failed=1
  policy_check .config/pnpm/config.yaml "^  - '@opencode/\\*'$" "pnpm OpenCode release-age exception" || failed=1
  policy_check .config/pnpm/config.yaml '^dangerouslyAllowAllBuilds: false$' "pnpm build approval" || failed=1
  policy_check .bunfig.toml '^ignoreScripts = true$' "Bun ignoreScripts" || failed=1
  policy_check .bunfig.toml '^minimumReleaseAge = 432000$' "Bun release age" || failed=1
  return "$failed"
}
