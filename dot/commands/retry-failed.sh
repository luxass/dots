# shellcheck shell=bash
# dot retry-failed: retry packages that init recorded in FAILED_PACKAGES_DIR.

cmd_retry_failed_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot retry-failed

Retry every package a failed init recorded in $(pretty_path "$FAILED_PACKAGES_DIR")
(entries are <type>:<name>). Packages that still fail are written to a new file.
EOF
}

cmd_retry_failed() {
  local failed_files=() failed_file entries entry package_type package_name retry_count=0 success_count=0

  no_args "$@" || return 1
  print_header "Retrying failed package installations"

  while IFS= read -r failed_file; do
    failed_files+=("$failed_file")
  done < <(find "$FAILED_PACKAGES_DIR" -name '*.txt' -type f 2>/dev/null | sort)
  if [[ "${#failed_files[@]}" -eq 0 ]]; then
    print_info "No failed packages recorded"
    return 0
  fi
  homebrew_require || return 1

  entries="$(sort -u "${failed_files[@]}")"
  print_info "Found ${#failed_files[@]} failed package file(s)"
  DOT_FAILED_PACKAGES=()
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    retry_count=$((retry_count + 1))
    package_type="${entry%%:*}"
    package_name="${entry#*:}"
    if [[ "$entry" != *:* ]] || ! package_type_is_supported "$package_type"; then
      print_warning "Cannot retry '$entry'"
      DOT_FAILED_PACKAGES+=("$entry")
      continue
    fi
    print_info "Retrying $package_type package: $package_name"
    if package_install "$package_type" "$package_name" >/dev/null 2>&1; then
      print_success "Installed $package_name"
      success_count=$((success_count + 1))
    else
      print_warning "Still failing: $package_name"
      DOT_FAILED_PACKAGES+=("$entry")
    fi
  done <<<"$entries"

  rm -f "${failed_files[@]}" || return 1
  print_info "Retry complete: $success_count/$retry_count packages installed"
  if [[ "${#DOT_FAILED_PACKAGES[@]}" -eq 0 ]]; then
    print_success "All failed packages are now installed"
    return 0
  fi
  save_failed_packages
  return 1
}
