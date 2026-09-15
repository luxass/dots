stow_install_pnpm_deps() {
  local dir="$1"
  local label="${2:-plugin}"
  local extra_args="${3:-}"

  [[ -f "$dir/package.json" ]] || return 0

  if ! command_exists pnpm; then
    print_warning "pnpm is not available; skipping $label dependencies in $dir (run 'dot stow' again after init)"
    return 0
  fi

  print_info "Installing $label dependencies in $dir"
  if command_exists sfw; then
    # shellcheck disable=SC2086
    if (cd "$dir" && sfw pnpm install $extra_args); then
      print_success "$label dependencies installed in $dir"
    else
      print_warning "Failed to install $label dependencies in $dir"
    fi
  else
    # shellcheck disable=SC2086
    if (cd "$dir" && pnpm install $extra_args); then
      print_success "$label dependencies installed in $dir"
    else
      print_warning "Failed to install $label dependencies in $dir"
    fi
  fi
}
