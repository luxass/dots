# shellcheck shell=bash
# Homebrew and the packages/bundle* Brewfiles.

homebrew_require() {
  command_exists brew && return 0
  print_error "Homebrew is missing. Install it with:"
  # shellcheck disable=SC2016 # printed for the user, not expanded
  printf '  %s\n' '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  return 1
}

# bundle_file GROUP: the Brewfile for a bundle group.
bundle_file() {
  case "$1" in
    base) printf '%s\n' "$PACKAGES_DIR/bundle" ;;
    fonts | work | personal) printf '%s\n' "$PACKAGES_DIR/bundle.$1" ;;
    *)
      print_error "Unknown bundle group: $1 (use: ${BUNDLE_GROUPS[*]})"
      return 1
      ;;
  esac
}

bundle_pref_key() { printf 'packages.brew.%s.enabled\n' "$1"; }

# bundle_state GROUP: enabled, disabled, or unset (not chosen on this machine yet).
bundle_state() {
  local value
  if [[ "$1" == base ]]; then
    echo enabled
  elif ! value="$(prefs_get "$(bundle_pref_key "$1")" 2>/dev/null)"; then
    echo unset
  elif [[ "$value" == true ]]; then
    echo enabled
  else
    echo disabled
  fi
}

# bundle_entries FILE: "formula NAME" / "cask NAME" lines from a Brewfile.
bundle_entries() {
  [[ -f "$1" ]] || return 0
  sed -nE 's/^brew "([^"]+)".*/formula \1/p; s/^cask "([^"]+)".*/cask \1/p' "$1"
}

# bundle_sort FILE: keep the leading comment block, then sorted tap, brew,
# and cask sections, then any other entries in their original order.
bundle_sort() {
  local file="$1" tmp kind lines
  tmp="$(mktemp "$file.XXXXXX")" || return 1
  {
    sed -n '/^#/!q;p' "$file"
    for kind in tap brew cask; do
      lines="$(grep -E "^$kind \"" "$file" | LC_ALL=C sort -u || true)"
      if [[ -n "$lines" ]]; then
        printf '\n%s\n' "$lines"
      fi
    done
    lines="$(grep -vE '^(#|(tap|brew|cask) "|[[:space:]]*$)' "$file" || true)"
    if [[ -n "$lines" ]]; then
      printf '\n%s\n' "$lines"
    fi
  } | sed '1{/^$/d;}' >"$tmp" && mv "$tmp" "$file"
}

bundle_satisfied() {
  brew bundle check --no-upgrade --file "$1" >/dev/null 2>&1
}

# packages_install: install the base bundle plus every opted-in group.
packages_install() {
  local group file default failed=0

  homebrew_require || return 1
  migrate_brew_replacements || return 1

  for group in "${BUNDLE_GROUPS[@]}"; do
    file="$(bundle_file "$group")"
    [[ -f "$file" ]] || continue

    if [[ "$group" != base ]]; then
      default=n
      [[ "$group" == fonts ]] && default=y
      if ! preference_enabled "$(bundle_pref_key "$group")" "Install $group packages on this machine?" "$default"; then
        print_info "Skipping $group packages"
        continue
      fi
    fi

    if bundle_satisfied "$file"; then
      print_success "$group packages are installed"
      continue
    fi

    print_info "Installing $group packages"
    if ! brew bundle install --no-upgrade --file "$file"; then
      print_error "Some $group packages failed to install; run 'dot package check'"
      failed=1
    fi
  done

  migrate_pnpm_opencode
  return "$failed"
}

# homebrew_upgrade: show outdated packages and offer to upgrade them.
homebrew_upgrade() {
  local formulae casks count

  formulae="$(brew outdated --formula --quiet)" || return 1
  casks="$(brew outdated --cask --quiet)" || return 1
  count="$(printf '%s\n%s\n' "$formulae" "$casks" | grep -c . || true)"

  if [[ "$count" -eq 0 ]]; then
    print_success "Homebrew packages are current"
    return 0
  fi

  print_info "$count Homebrew updates are available"
  if [[ -n "$formulae" ]]; then
    print_section "Formulae"
    indent <<<"$formulae"
  fi
  if [[ -n "$casks" ]]; then
    print_section "Casks"
    indent <<<"$casks"
  fi
  echo

  if ! confirm "Upgrade these Homebrew packages?" n; then
    print_info "Skipping Homebrew upgrades"
    return 0
  fi
  if [[ -n "$formulae" ]]; then
    brew upgrade --formula --yes || return 1
  fi
  if [[ -n "$casks" ]]; then
    brew upgrade --cask --yes || return 1
  fi
}

homebrew_check() {
  homebrew_require || return 1
  if bundle_satisfied "$(bundle_file base)"; then
    print_success "Base packages are installed"
  else
    print_error "Base packages are missing; run 'dot package check'"
    return 1
  fi
}
