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

  if curl -fsSL https://get.pnpm.io/install.sh | ENV="$installer_env" SHELL="$(command -v zsh)" sh -; then
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

  local package
  for package in "${PNPM_GLOBAL_PACKAGES[@]}"; do
    if command_exists "$package"; then
      print_success "$package is installed"
      continue
    fi

    print_info "Installing pnpm global: $package"
    pnpm add -g "$package"
    hash -r 2>/dev/null || true

    if command_exists "$package"; then
      print_success "$package installed"
    else
      print_error "$package install completed, but command is not on PATH"
      return 1
    fi
  done
}
