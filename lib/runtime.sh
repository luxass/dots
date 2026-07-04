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
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
  case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) export PATH="$PNPM_HOME/bin:$PATH" ;;
  esac
}

ensure_pnpm() {
  enable_pnpm_path

  if command_exists pnpm; then
    print_success "pnpm is installed"
    return 0
  fi

  print_info "Installing pnpm standalone..."

  local installer_env
  installer_env="$(mktemp)"

  if curl -fsSL https://get.pnpm.io/install.sh | ENV="$installer_env" SHELL="/bin/sh" sh -; then
    rm -f "$installer_env"
    enable_pnpm_path
    hash -r 2>/dev/null || true
  else
    rm -f "$installer_env"
    print_error "Failed to install pnpm"
    return 1
  fi

  if command_exists pnpm; then
    print_success "pnpm installed"
  else
    print_error "pnpm install completed, but pnpm is not on PATH"
    return 1
  fi
}

ensure_node_runtime() {
  ensure_pnpm

  if command_exists node && [[ "$(command -v node)" == "$PNPM_HOME"* ]]; then
    if command_exists npm; then
      print_success "Node.js and npm are managed by pnpm"
      return 0
    fi
    print_info "Node.js is managed by pnpm; npm is missing"
  fi

  print_info "Installing Node.js runtime with pnpm..."
  pnpm runtime set node "$NODE_RUNTIME_VERSION" -g
  enable_pnpm_path
  hash -r 2>/dev/null || true

  if ! command_exists npm; then
    print_info "Installing npm with pnpm..."
    pnpm add -g npm
    hash -r 2>/dev/null || true
  fi

  if command_exists node && command_exists npm; then
    print_success "Node.js runtime and npm installed"
  else
    print_error "Node.js runtime installation did not expose node/npm"
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

    if command_exists "$command_name"; then
      print_success "$command_name is installed"
      continue
    fi

    print_info "Installing pnpm global: $package"
    pnpm add -g "$package"
    hash -r 2>/dev/null || true

    if command_exists "$command_name"; then
      print_success "$command_name installed"
    else
      print_error "$package install completed, but $command_name is not on PATH"
      return 1
    fi
  done
}

command_path_in_pnpm_home() {
  local command_name="$1"
  local command_path

  command_path="$(command -v "$command_name" 2>/dev/null || true)"
  [[ -n "$command_path" && "$command_path" == "$PNPM_HOME"/* ]]
}

check_runtime_origins() {
  local failed=0
  local command_name command_path

  for command_name in pnpm node npm; do
    command_path="$(command -v "$command_name" 2>/dev/null || true)"

    if [[ -z "$command_path" ]]; then
      print_error "$command_name is missing"
      failed=1
    elif command_path_in_pnpm_home "$command_name"; then
      print_success "$command_name resolves from PNPM_HOME"
    else
      print_error "$command_name is not managed by pnpm: $command_path"
      failed=1
    fi
  done

  return "$failed"
}

check_pnpm_config_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(pnpm config get "$key" 2>/dev/null || true)"

  if [[ "$actual" == "$expected" ]]; then
    print_success "pnpm $key=$expected"
    return 0
  fi

  print_error "pnpm $key is ${actual:-unset}; expected $expected"
  return 1
}

check_pnpm_policy() {
  if ! command_exists pnpm; then
    print_error "pnpm policy cannot be checked because pnpm is missing"
    return 1
  fi

  local failed=0

  check_pnpm_config_value "ignore-scripts" "true" || failed=1
  check_pnpm_config_value "minimumReleaseAge" "7200" || failed=1
  check_pnpm_config_value "minimumReleaseAgeStrict" "true" || failed=1
  check_pnpm_config_value "dangerouslyAllowAllBuilds" "false" || failed=1

  return "$failed"
}
