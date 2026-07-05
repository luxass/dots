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

enable_vite_plus_path() {
  export VP_HOME
  case ":$PATH:" in
    *":$VP_HOME/bin:"*) ;;
    *) export PATH="$VP_HOME/bin:$PATH" ;;
  esac
}

ensure_vite_plus() {
  enable_vite_plus_path

  local vp_path
  vp_path="$(command -v vp 2>/dev/null || true)"
  if [[ -n "$vp_path" && "$vp_path" == "$VP_HOME"/* ]]; then
    print_success "Vite+ is installed"
    return 0
  fi

  if [[ -n "$vp_path" ]]; then
    print_warning "vp is not managed from VP_HOME: $vp_path"
  fi

  print_info "Installing Vite+..."

  if curl -fsSL https://vite.plus | VP_NODE_MANAGER=yes bash; then
    enable_vite_plus_path
    hash -r 2>/dev/null || true
  else
    print_error "Failed to install Vite+"
    return 1
  fi

  if command_exists vp; then
    print_success "Vite+ installed"
  else
    print_error "Vite+ install completed, but vp is not on PATH"
    return 1
  fi
}

ensure_node_runtime() {
  ensure_vite_plus

  print_info "Ensuring Vite+ Node.js shims"
  vp env setup
  vp env default "$NODE_RUNTIME_VERSION"
  vp env install "$NODE_RUNTIME_VERSION"
  enable_vite_plus_path
  hash -r 2>/dev/null || true

  local node_path npm_path
  node_path="$(command -v node 2>/dev/null || true)"
  npm_path="$(command -v npm 2>/dev/null || true)"

  if command_path_in_vite_plus_home "$node_path" && command_path_in_vite_plus_home "$npm_path"; then
    print_success "Node.js and npm are managed by Vite+"
  else
    print_error "Vite+ Node.js setup did not expose managed node/npm"
    return 1
  fi
}

ensure_vite_plus_globals() {
  ensure_node_runtime

  local entry package command_name
  for entry in "${VITE_PLUS_GLOBAL_PACKAGES[@]}"; do
    package="${entry%%:*}"
    command_name="${entry#*:}"
    if [[ "$command_name" == "$entry" ]]; then
      command_name="$package"
    fi

    local command_path
    command_path="$(command -v "$command_name" 2>/dev/null || true)"
    if command_path_in_vite_plus_home "$command_path"; then
      print_success "$command_name is installed"
      continue
    fi

    if [[ -n "$command_path" ]]; then
      print_warning "$command_name is not managed from VP_HOME: $command_path"
    fi

    print_info "Installing Vite+ global: $package"
    if command_exists sfw; then
      NPM_CONFIG_MIN_RELEASE_AGE=0 sfw vp install -g "$package"
    else
      NPM_CONFIG_MIN_RELEASE_AGE=0 vp install -g "$package"
    fi
    hash -r 2>/dev/null || true

    command_path="$(command -v "$command_name" 2>/dev/null || true)"
    if command_path_in_vite_plus_home "$command_path"; then
      print_success "$command_name installed"
    else
      print_error "$package install completed, but $command_name is not managed from VP_HOME"
      return 1
    fi

  done
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

command_path_in_vite_plus_home() {
  local command_path="$1"
  [[ -n "$command_path" && "$command_path" == "$VP_HOME"/* ]]
}

check_runtime_origins() {
  local failed=0
  local lookup_path command_name command_path

  lookup_path="$(runtime_lookup_path)"

  for command_name in vp node npm corepack; do
    command_path="$(PATH="$lookup_path" command -v "$command_name" 2>/dev/null || true)"

    if [[ -z "$command_path" ]]; then
      print_error "$command_name is missing"
      failed=1
    elif command_path_in_vite_plus_home "$command_path"; then
      print_success "$command_name resolves from VP_HOME"
    else
      print_error "$command_name is not managed by Vite+: $command_path"
      failed=1
    fi
  done

  for command_name in pnpm yarn; do
    command_path="$(PATH="$lookup_path" command -v "$command_name" 2>/dev/null || true)"
    [[ -n "$command_path" ]] || continue

    if command_path_in_vite_plus_home "$command_path"; then
      print_success "$command_name resolves from VP_HOME"
    else
      print_error "$command_name is not managed by Vite+: $command_path"
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
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^ignoreScripts: true$' "pnpm ignoreScripts policy" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^minimumReleaseAge: 7200$' "pnpm release-age policy" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^minimumReleaseAgeStrict: true$' "pnpm strict release-age policy" || failed=1
  check_file_contains "${HOME_DIR}/.config/pnpm/config.yaml" '^dangerouslyAllowAllBuilds: false$' "pnpm build approval policy" || failed=1
  check_file_contains "${HOME_DIR}/.bunfig.toml" '^ignoreScripts = true$' "Bun ignoreScripts policy" || failed=1
  check_file_contains "${HOME_DIR}/.bunfig.toml" '^minimumReleaseAge = 432000$' "Bun release-age policy" || failed=1

  return "$failed"
}
