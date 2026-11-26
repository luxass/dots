# shellcheck shell=bash
# Packages from the Brewfiles (package-lists.sh): packages/bundle, and
# packages/bundle.work when you confirm.
define_component packages required "Homebrew packages"

component_packages_install() {
  local base_list work_list

  homebrew_require || return 1
  DOT_FAILED_PACKAGES=()

  base_list="$(package_list_file base)" || return 1
  install_package_list "$base_list" || return 1

  work_list="$(package_list_file work)" || return 1
  if [[ -f "$work_list" ]] && confirm "Install work packages ($(pretty_path "$work_list"))?" n; then
    validate_work_brewfile "$work_list" || return 1
    install_package_list "$work_list" || return 1
  fi

  save_failed_packages || return 1
  migrate_pnpm_opencode
}

# Refresh the index, then upgrade every outdated Homebrew package.
component_packages_update() {
  homebrew_require || return 1
  print_info "Updating the Homebrew package index"
  if ! package_refresh_index; then
    print_error "Failed to update the Homebrew package index"
    return 1
  fi
  if ! package_upgrade_all; then
    print_error "Failed to upgrade Homebrew packages"
    return 1
  fi
  print_success "Homebrew packages are up to date"
}

component_packages_check() {
  local list_name list_file missing

  homebrew_require || return 1
  for list_name in $(package_list_names); do
    list_file="$(package_list_file "$list_name")" || return 1
    missing="$(find_missing_packages "$list_file")" || return 1
    if [[ -z "$missing" ]]; then
      print_success "Every package in $(basename "$list_file") is installed"
    else
      print_warning "Not installed from $(basename "$list_file") (run: dot init --only packages):"
      tr '\t' ' ' <<<"$missing" | indent >&2
    fi
  done
}
