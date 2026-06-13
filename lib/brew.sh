ensure_homebrew() {
  if command_exists brew; then
    return 0
  fi

  print_error "Homebrew is missing"
  print_info "Install it with:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  return 1
}

bundle_file_for() {
  case "${1:-base}" in
    base) echo "$BASE_BUNDLE" ;;
    fonts) echo "$FONTS_BUNDLE" ;;
    work) echo "$WORK_BUNDLE" ;;
    *)
      print_error "Unknown bundle: $1"
      return 1
      ;;
  esac
}

brew_bundle_check() {
  local bundle="$1"

  [[ -f "$bundle" ]] || {
    print_warning "Bundle not found: $bundle"
    return 0
  }

  brew bundle check --no-upgrade --file "$bundle"
}

brew_bundle_install_resilient() {
  local bundle="$1"

  [[ -f "$bundle" ]] || {
    print_warning "Bundle not found: $bundle"
    return 0
  }

  if HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle --file "$bundle"; then
    print_success "Installed packages from $(basename "$bundle")"
    return 0
  fi

  print_warning "Bundle install failed; retrying packages individually"

  local failed=()
  local installed_count=0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    if [[ "$line" =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
      local package="${BASH_REMATCH[1]}"
      local short_package="${package##*/}"
      if brew list --formula "$package" >/dev/null 2>&1 || brew list --formula "$short_package" >/dev/null 2>&1; then
        print_success "Formula already installed: $package"
        continue
      fi
      print_info "Installing formula: $package"
      if brew install "$package"; then
        ((installed_count++))
      else
        failed+=("brew:$package")
      fi
    elif [[ "$line" =~ ^cask[[:space:]]+\"([^\"]+)\" ]]; then
      local package="${BASH_REMATCH[1]}"
      if brew list --cask "$package" >/dev/null 2>&1; then
        print_success "Cask already installed: $package"
        continue
      fi
      print_info "Installing cask: $package"
      if brew install --cask "$package"; then
        ((installed_count++))
      else
        failed+=("cask:$package")
      fi
    fi
  done < "$bundle"

  print_success "Installed $installed_count packages individually"

  if [[ "${#failed[@]}" -gt 0 ]]; then
    local failed_file="${PACKAGES_DIR}/failed_packages_$(date +%Y%m%d_%H%M%S).txt"
    printf "%s\n" "${failed[@]}" > "$failed_file"
    print_warning "Failed packages saved to $failed_file"
    return 1
  fi
}

parse_bundle_packages() {
  local bundle="$1"

  [[ -f "$bundle" ]] || return 0

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    if [[ "$line" =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
      printf 'brew:%s\n' "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^cask[[:space:]]+\"([^\"]+)\" ]]; then
      printf 'cask:%s\n' "${BASH_REMATCH[1]}"
    fi
  done < "$bundle"
}

all_bundle_files() {
  printf '%s\n' "$BASE_BUNDLE"
  printf '%s\n' "$FONTS_BUNDLE"
  printf '%s\n' "$WORK_BUNDLE"
}

tracked_brews() {
  local bundle
  while IFS= read -r bundle; do
    [[ -f "$bundle" ]] || continue

    while IFS=: read -r type name; do
      [[ "$type" == "brew" && -n "$name" ]] || continue
      printf '%s\n' "$name"
      printf '%s\n' "${name##*/}"

      case "$name" in
        nvim) printf 'neovim\n' ;;
        neovim) printf 'nvim\n' ;;
      esac
    done < <(parse_bundle_packages "$bundle")
  done < <(all_bundle_files)
}

tracked_casks() {
  local bundle
  while IFS= read -r bundle; do
    [[ -f "$bundle" ]] || continue

    while IFS=: read -r type name; do
      [[ "$type" == "cask" && -n "$name" ]] || continue
      printf '%s\n' "$name"
    done < <(parse_bundle_packages "$bundle")
  done < <(all_bundle_files)
}

sort_bundle() {
  local bundle="$1"
  local tmp
  tmp="$(mktemp)"

  {
    grep -E '^tap "' "$bundle" 2>/dev/null | sort -u || true
    echo ""
    grep -E '^brew "' "$bundle" 2>/dev/null | sort -u || true
    echo ""
    grep -E '^cask "' "$bundle" 2>/dev/null | sort -u || true
  } > "$tmp"

  sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" > "$bundle"
  rm "$tmp"
}

_install_packages() {
  ensure_homebrew
  brew_bundle_install_resilient "$BASE_BUNDLE"

  if [[ -f "$FONTS_BUNDLE" ]] && confirm "Install font packages?" "y"; then
    brew_bundle_install_resilient "$FONTS_BUNDLE"
  fi

  if [[ -f "$WORK_BUNDLE" ]] && confirm "Install work-specific packages?" "n"; then
    brew_bundle_install_resilient "$WORK_BUNDLE"
  fi
}

cmd_check_packages() {
  print_header "Checking packages"

  local failed=0
  brew_bundle_check "$BASE_BUNDLE" || failed=1

  if [[ -f "$FONTS_BUNDLE" ]]; then
    brew_bundle_check "$FONTS_BUNDLE" || failed=1
  fi

  if [[ -f "$WORK_BUNDLE" ]]; then
    brew_bundle_check "$WORK_BUNDLE" || failed=1
  fi

  return "$failed"
}

cmd_retry_failed() {
  print_header "Retrying failed package installs"

  local files=("${PACKAGES_DIR}"/failed_packages_*.txt)
  if [[ ! -e "${files[0]}" ]]; then
    print_info "No failed package files found"
    return 0
  fi

  local failed=()
  for file in "${files[@]}"; do
    print_info "Retrying packages from $(basename "$file")"
    while IFS= read -r item; do
      [[ -z "$item" ]] && continue
      local type="${item%%:*}"
      local name="${item#*:}"

      if [[ "$type" == "cask" ]]; then
        brew install --cask "$name" || failed+=("$item")
      else
        brew install "$name" || failed+=("$item")
      fi
    done < "$file"
  done

  if [[ "${#failed[@]}" -gt 0 ]]; then
    print_warning "Still failed:"
    printf "  - %s\n" "${failed[@]}"
    return 1
  fi

  rm -f "${files[@]}"
  print_success "All failed packages installed"
}

cmd_package_list() {
  local bundle_filter="${1:-all}"
  print_header "Listing packages"

  local installed_formulas installed_casks
  installed_formulas="$(brew list --formula 2>/dev/null || true)"
  installed_casks="$(brew list --cask 2>/dev/null || true)"

  local bundles=()
  case "$bundle_filter" in
    base) bundles=("$BASE_BUNDLE") ;;
    fonts) bundles=("$FONTS_BUNDLE") ;;
    work) bundles=("$WORK_BUNDLE") ;;
    all) bundles=("$BASE_BUNDLE" "$FONTS_BUNDLE" "$WORK_BUNDLE") ;;
    *) print_error "Unknown bundle: $bundle_filter"; return 1 ;;
  esac

  for bundle in "${bundles[@]}"; do
    [[ -f "$bundle" ]] || continue
    echo -e "\n${BOLD}$(basename "$bundle")${RESET}"

    while IFS=: read -r type name; do
      [[ -n "$name" ]] || continue
      local short_name="${name##*/}"

      if [[ "$type" == "cask" ]]; then
        if grep -qx "$name" <<< "$installed_casks"; then
          print_success "$name"
        else
          print_error "$name (not installed)"
        fi
      else
        if grep -qx "$name" <<< "$installed_formulas" || grep -qx "$short_name" <<< "$installed_formulas"; then
          print_success "$name"
        else
          print_error "$name (not installed)"
        fi
      fi
    done < <(parse_bundle_packages "$bundle")
  done
}

cmd_package_unmanaged() {
  print_header "Unmanaged Homebrew packages"

  local unmanaged_brews unmanaged_casks
  unmanaged_brews="$(comm -23 \
    <(brew leaves 2>/dev/null | sed 's#^.*/##' | sort -u) \
    <(tracked_brews | sort -u))"
  unmanaged_casks="$(comm -23 \
    <(brew list --cask 2>/dev/null | sort -u) \
    <(tracked_casks | sort -u))"

  echo -e "\n${BOLD}Formulae${RESET}"
  if [[ -n "$unmanaged_brews" ]]; then
    printf '%s\n' "$unmanaged_brews"
  else
    print_success "No unmanaged top-level formulae"
  fi

  echo -e "\n${BOLD}Casks${RESET}"
  if [[ -n "$unmanaged_casks" ]]; then
    printf '%s\n' "$unmanaged_casks"
  else
    print_success "No unmanaged casks"
  fi
}

cmd_package_add() {
  local name="${1:-}"
  local type="${2:-auto}"
  local bundle_name="${3:-base}"

  [[ -n "$name" ]] || {
    print_error "Package name required"
    return 1
  }

  local bundle
  bundle="$(bundle_file_for "$bundle_name")"
  mkdir -p "$(dirname "$bundle")"
  touch "$bundle"

  if [[ "$type" == "auto" ]]; then
    if brew info --cask "$name" >/dev/null 2>&1; then
      type="cask"
    else
      type="brew"
    fi
  fi

  case "$type" in
    brew)
      grep -qx "brew \"$name\"" "$bundle" 2>/dev/null || echo "brew \"$name\"" >> "$bundle"
      brew install "$name"
      ;;
    cask)
      grep -qx "cask \"$name\"" "$bundle" 2>/dev/null || echo "cask \"$name\"" >> "$bundle"
      brew install --cask "$name"
      ;;
    *)
      print_error "Type must be brew, cask, or auto"
      return 1
      ;;
  esac

  sort_bundle "$bundle"
  print_success "Added $name to $(basename "$bundle")"
}

cmd_package_remove() {
  local name="${1:-}"
  local bundle_name="${2:-all}"

  [[ -n "$name" ]] || {
    print_error "Package name required"
    return 1
  }

  local bundles=()
  case "$bundle_name" in
    base) bundles=("$BASE_BUNDLE") ;;
    fonts) bundles=("$FONTS_BUNDLE") ;;
    work) bundles=("$WORK_BUNDLE") ;;
    all) bundles=("$BASE_BUNDLE" "$FONTS_BUNDLE" "$WORK_BUNDLE") ;;
    *) print_error "Unknown bundle: $bundle_name"; return 1 ;;
  esac

  local found=false
  for bundle in "${bundles[@]}"; do
    [[ -f "$bundle" ]] || continue
    if grep -Eq "^(brew|cask)[[:space:]]+\"$name\"" "$bundle"; then
      local tmp
      tmp="$(mktemp)"
      grep -Ev "^(brew|cask)[[:space:]]+\"$name\"" "$bundle" > "$tmp"
      mv "$tmp" "$bundle"
      found=true
      print_success "Removed $name from $(basename "$bundle")"
    fi
  done

  if [[ "$found" == false ]]; then
    print_warning "$name was not found in bundle files"
    return 0
  fi

  if confirm "Uninstall $name from this machine?" "n"; then
    brew uninstall "$name" || brew uninstall --cask "$name"
  fi
}

cmd_package_update() {
  local name="${1:-all}"

  if [[ "$name" == "all" ]]; then
    print_header "Updating Homebrew packages"
    brew update
    brew upgrade
    brew upgrade --cask || true
    if confirm "Clean up old versions?" "y"; then
      brew cleanup
    fi
    return 0
  fi

  if brew list --formula | grep -qx "$name"; then
    brew upgrade "$name"
  elif brew list --cask | grep -qx "$name"; then
    brew upgrade --cask "$name"
  else
    print_error "$name is not installed"
    return 1
  fi
}

cmd_package_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} package${RESET}

Usage:
  ${SCRIPT_NAME} package list [base|fonts|work|all]
  ${SCRIPT_NAME} package unmanaged
  ${SCRIPT_NAME} package add NAME [brew|cask|auto] [base|fonts|work]
  ${SCRIPT_NAME} package remove NAME [base|fonts|work|all]
  ${SCRIPT_NAME} package update [NAME|all]
EOF
}

cmd_package() {
  local subcommand="${1:-list}"
  shift || true

  case "$subcommand" in
    list) cmd_package_list "$@" ;;
    unmanaged) cmd_package_unmanaged "$@" ;;
    add) cmd_package_add "$@" ;;
    remove) cmd_package_remove "$@" ;;
    update) cmd_package_update "$@" ;;
    help|-h|--help) cmd_package_help ;;
    *) print_error "Unknown package command: $subcommand"; cmd_package_help; return 1 ;;
  esac
}
