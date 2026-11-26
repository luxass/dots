# shellcheck shell=bash
# dot check-packages: which packages from the package lists are missing here.

cmd_check_packages_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot check-packages

Report installed and missing packages from packages/bundle and packages/bundle.work.
EOF
}

cmd_check_packages() {
  local list_name list_file total missing missing_count all_missing=0

  no_args "$@" || return 1
  homebrew_require || return 1
  print_header "Checking installed packages"

  for list_name in $(package_list_names); do
    list_file="$(package_list_file "$list_name")" || return 1
    if [[ "$list_name" == work ]]; then
      validate_work_brewfile "$list_file" || return 1
    fi
    total="$(read_package_list "$list_file" | grep -c . || true)"
    missing="$(find_missing_packages "$list_file")" || return 1
    missing_count=0
    if [[ -n "$missing" ]]; then
      missing_count="$(grep -c . <<<"$missing")"
    fi
    all_missing=$((all_missing + missing_count))

    print_success "$(basename "$list_file"): $((total - missing_count))/$total installed"
    if [[ "$missing_count" -gt 0 ]]; then
      print_warning "Missing from $(basename "$list_file") ($missing_count):"
      tr '\t' ' ' <<<"$missing" | sed 's/^/  - /' >&2
    fi
  done

  if [[ "$all_missing" -gt 0 ]]; then
    print_info "Run 'dot init --only packages' to install missing packages"
  else
    print_success "All packages are installed"
  fi
}
