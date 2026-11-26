# shellcheck shell=bash
# Homebrew verbs for the package lists: install, upgrade, uninstall, and list.
# Every verb takes a package type (brew or cask), so commands and components
# never repeat Homebrew flags. Homebrew's automatic cleanup and autoremove
# stay off for every change dot makes.

# Packages that failed during this run, as "<type>:<name>". See save_failed_packages.
DOT_FAILED_PACKAGES=()

# brew_without_cleanup ARGS...: run brew without its automatic cleanup or autoremove.
brew_without_cleanup() {
  HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_AUTOREMOVE=1 brew "$@"
}

# package_types: print the package types dot manages, one per line.
package_types() {
  printf '%s\n' brew cask
}

package_type_is_supported() {
  case "$1" in
    brew | cask) return 0 ;;
    *) return 1 ;;
  esac
}

unknown_package_type() {
  print_error "Unknown package type '$1': expected brew or cask"
  return 1
}

# package_install TYPE NAME...: install packages of one type.
package_install() {
  local package_type="$1"
  shift
  case "$package_type" in
    brew) brew_without_cleanup install --formula "$@" ;;
    cask) brew_without_cleanup install --cask "$@" ;;
    *) unknown_package_type "$package_type" ;;
  esac
}

# package_upgrade TYPE NAME...: upgrade installed packages of one type.
package_upgrade() {
  local package_type="$1"
  shift
  case "$package_type" in
    brew) brew_without_cleanup upgrade --formula "$@" ;;
    cask) brew_without_cleanup upgrade --cask "$@" ;;
    *) unknown_package_type "$package_type" ;;
  esac
}

# package_uninstall TYPE NAME...: uninstall packages of one type. Dependencies
# that become unused stay installed.
package_uninstall() {
  local package_type="$1"
  shift
  case "$package_type" in
    brew) brew_without_cleanup uninstall --formula "$@" ;;
    cask) brew_without_cleanup uninstall --cask "$@" ;;
    *) unknown_package_type "$package_type" ;;
  esac
}

# package_installed_names TYPE: print installed package names of one type.
package_installed_names() {
  case "$1" in
    brew) brew list --formula -1 ;;
    cask) brew list --cask -1 ;;
    *) unknown_package_type "$1" ;;
  esac
}

# package_outdated_names TYPE: print installed packages of one type that have a newer version.
package_outdated_names() {
  case "$1" in
    brew) brew outdated --formula --quiet ;;
    cask) brew outdated --cask --quiet ;;
    *) unknown_package_type "$1" ;;
  esac
}

# package_detect_type NAME: print brew for a formula or cask for a cask.
package_detect_type() {
  if brew info --json=v2 --formula "$1" >/dev/null 2>&1; then
    printf 'brew\n'
  elif brew info --json=v2 --cask "$1" >/dev/null 2>&1; then
    printf 'cask\n'
  else
    print_warning "Package '$1' is neither a formula nor a cask; assuming a formula"
    printf 'brew\n'
  fi
}

# package_refresh_index: download the newest Homebrew package index.
package_refresh_index() {
  brew update
}

# package_upgrade_all: upgrade every outdated Homebrew package, including
# packages that are not in a package list.
package_upgrade_all() {
  local outdated

  outdated="$(brew outdated)" || return 1
  if [[ -z "$outdated" ]]; then
    print_success "All Homebrew packages are up to date"
    return 0
  fi
  print_info "Upgrading:"
  indent <<<"$outdated"
  brew_without_cleanup upgrade --yes
}

# install_package_list FILE: install a Brewfile in one batch. When the batch
# fails, retry one package at a time and record failures in DOT_FAILED_PACKAGES.
install_package_list() {
  local list_file="$1" list_label entry_type entry_name

  list_label="$(basename "$list_file")"
  if [[ ! -f "$list_file" ]]; then
    print_error "Package list not found: $(pretty_path "$list_file")"
    return 1
  fi

  if brew_without_cleanup bundle --file="$list_file"; then
    print_success "All packages in $list_label are installed"
    return 0
  fi

  # One bad name fails the whole batch, so retry one package at a time.
  print_warning "Some packages in $list_label failed to install; trying them one at a time"
  while IFS=$'\t' read -r entry_type entry_name; do
    if ! package_install "$entry_type" "$entry_name" >/dev/null 2>&1; then
      print_warning "Failed to install $entry_type package: $entry_name"
      DOT_FAILED_PACKAGES+=("$entry_type:$entry_name")
    fi
  done < <(read_package_list "$list_file")
}

# load_package_cache installed|outdated TYPE: load package names of one type
# into DOT_PACKAGE_CACHE__<kind>__<type>, once per run.
load_package_cache() {
  local kind="$1" package_type="$2" cache_var names

  cache_var="DOT_PACKAGE_CACHE__${kind}__$package_type"
  declare -p "$cache_var" >/dev/null 2>&1 && return 0
  if [[ "$kind" == installed ]]; then
    names="$(package_installed_names "$package_type")" || {
      print_error "Failed to list installed $package_type packages"
      return 1
    }
  else
    names="$(package_outdated_names "$package_type")" || {
      print_error "Failed to list outdated $package_type packages"
      return 1
    }
  fi
  printf -v "$cache_var" '%s' "$names"
}

# package_listed_name TYPE NAME: brew list and brew outdated drop the tap from
# tap-qualified names (user/tap/name -> name).
package_listed_name() {
  printf '%s\n' "${2##*/}"
}

# package_name_in_list NAME LIST: LIST (newline-separated) contains the exact line NAME.
package_name_in_list() {
  grep -Fqx -- "$1" <<<"$2"
}

# package_is_installed TYPE NAME: 0 installed, 1 missing, 2 listing failed.
package_is_installed() {
  local cache_var="DOT_PACKAGE_CACHE__installed__$1"
  load_package_cache installed "$1" || return 2
  package_name_in_list "$(package_listed_name "$1" "$2")" "${!cache_var}"
}

# package_is_outdated TYPE NAME: 0 outdated, 1 current, 2 listing failed.
package_is_outdated() {
  local cache_var="DOT_PACKAGE_CACHE__outdated__$1"
  load_package_cache outdated "$1" || return 2
  package_name_in_list "$(package_listed_name "$1" "$2")" "${!cache_var}"
}

# find_missing_packages FILE: print the entries of a Brewfile that are not
# installed, as "<type><TAB><name>".
find_missing_packages() {
  local entries entry_type entry_name status

  entries="$(read_package_list "$1")"
  [[ -n "$entries" ]] || return 0
  while IFS=$'\t' read -r entry_type entry_name; do
    status=0
    package_is_installed "$entry_type" "$entry_name" || status=$?
    case "$status" in
      0) ;;
      1) printf '%s\t%s\n' "$entry_type" "$entry_name" ;;
      *) return 1 ;;
    esac
  done <<<"$entries"
}

# save_failed_packages: write DOT_FAILED_PACKAGES to a file in
# FAILED_PACKAGES_DIR for `dot retry-failed`, and print them.
save_failed_packages() {
  local failed_file

  [[ "${#DOT_FAILED_PACKAGES[@]}" -gt 0 ]] || return 0
  print_warning "Failed to install ${#DOT_FAILED_PACKAGES[@]} package(s):"
  printf '  - %s\n' "${DOT_FAILED_PACKAGES[@]}"

  mkdir -p "$FAILED_PACKAGES_DIR" || return 1
  failed_file="$FAILED_PACKAGES_DIR/$(date +%Y%m%d-%H%M%S)-$$.txt"
  printf '%s\n' "${DOT_FAILED_PACKAGES[@]}" | sort -u >"$failed_file" || return 1
  print_info "Saved them to $(pretty_path "$failed_file"); retry with 'dot retry-failed'"
}
