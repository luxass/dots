# shellcheck shell=bash
# dot package: edit the package lists (dot/lib/package-lists.sh) and install,
# upgrade, or uninstall through Homebrew (dot/lib/package-manager.sh).

cmd_package_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot package [list|add|remove|update|help] [ARGS]

${BOLD}SUBCOMMANDS${RESET}
  list [all|base|work]                List packages and whether they are installed (default)
  add NAME [brew|cask] [base|work]    Install a package and add it to a list
  remove NAME [base|work|all]         Remove a package from the lists; asks before uninstalling
  update [NAME|all] [all|base|work]   Upgrade one package, one list, or everything

TYPE is detected when omitted. base is packages/bundle. work is
packages/bundle.work, which takes formulas only.

${BOLD}EXAMPLES${RESET}
  dot package add ripgrep
  dot package add docker cask
  dot package add kubectl brew work
  dot package remove docker base
  dot package update all base
EOF
}

cmd_package() {
  local subcommand="${1:-list}" argument
  [[ "$#" -gt 0 ]] && shift

  for argument in "$@"; do
    if [[ "$argument" == -h || "$argument" == --help ]]; then
      cmd_package_usage
      return 0
    fi
  done

  case "$subcommand" in
    list) package_command_list "$@" ;;
    add) package_command_add "$@" ;;
    remove) package_command_remove "$@" ;;
    update) package_command_update "$@" ;;
    help | -h | --help) cmd_package_usage ;;
    *)
      print_error "Unknown package subcommand: $subcommand"
      print_info "Run 'dot package help' for usage"
      return 1
      ;;
  esac
}

# selected_package_list_names all|base|work: print the list names an argument selects.
selected_package_list_names() {
  case "$1" in
    all) package_list_names ;;
    base | work) printf '%s\n' "$1" ;;
    *)
      print_error "Unknown package list '$1': expected all, base, or work"
      return 1
      ;;
  esac
}

package_command_add() {
  local package_name="${1:-}" package_type=auto list_name=base argument list_file

  if [[ -z "$package_name" || "$package_name" == -* ]]; then
    print_error "Package name required"
    print_info "Usage: dot package add NAME [brew|cask] [base|work]"
    return 1
  fi
  shift
  for argument in "$@"; do
    case "$argument" in
      base | work) list_name="$argument" ;;
      auto | brew | cask) package_type="$argument" ;;
      *)
        print_error "Unexpected argument for package add: $argument"
        return 1
        ;;
    esac
  done

  homebrew_require || return 1
  list_file="$(package_list_file "$list_name")" || return 1
  if [[ "$package_type" == auto ]]; then
    package_type="$(package_detect_type "$package_name")"
  fi
  if [[ "$package_type" == cask && "$list_name" == work ]]; then
    print_error "Casks must be added to the base list (packages/bundle)"
    return 1
  fi
  if package_list_entry_type "$list_file" "$package_name" >/dev/null; then
    print_warning "Package '$package_name' is already in $(basename "$list_file")"
    return 0
  fi

  print_header "Adding $package_type package: $package_name"
  if ! package_install "$package_type" "$package_name"; then
    print_error "Failed to install $package_name; $(basename "$list_file") is unchanged"
    return 1
  fi
  package_list_add "$list_file" "$package_type" "$package_name" || return 1
  print_success "Added '$package_name' to $(basename "$list_file")"
}

package_command_remove() {
  local package_name="${1:-}" list_argument="${2:-all}" list_names list_name list_file entry_type removed_type=""

  if [[ -z "$package_name" ]]; then
    print_error "Package name required"
    print_info "Usage: dot package remove NAME [base|work|all]"
    return 1
  fi
  if [[ "$#" -gt 2 ]]; then
    print_error "Too many arguments for package remove"
    return 1
  fi

  print_header "Removing package: $package_name"
  list_names="$(selected_package_list_names "$list_argument")" || return 1
  for list_name in $list_names; do
    list_file="$(package_list_file "$list_name")" || return 1
    if entry_type="$(package_list_remove "$list_file" "$package_name")"; then
      removed_type="$entry_type"
      print_success "Removed '$package_name' from $(basename "$list_file")"
    fi
  done

  if [[ -z "$removed_type" ]]; then
    print_warning "Package '$package_name' is not in any package list"
    return 0
  fi
  homebrew_require || return 1
  if confirm "Uninstall '$package_name' from this Mac?" n; then
    if package_uninstall "$removed_type" "$package_name"; then
      print_success "Uninstalled $package_name"
    else
      print_warning "Failed to uninstall $package_name (something may depend on it)"
    fi
  else
    print_info "Removed from the package list but left installed"
  fi
}

package_command_update() {
  local package_name="${1:-all}" list_argument="${2:-all}" list_names list_name list_file
  local entry_type entry_name status updated=() failed=()

  if [[ "$#" -gt 2 ]]; then
    print_error "Too many arguments for package update"
    return 1
  fi
  homebrew_require || return 1
  list_names="$(selected_package_list_names "$list_argument")" || return 1

  print_header "Updating packages"
  if [[ "$package_name" != all ]]; then
    update_one_package "$package_name" "$list_argument" "$list_names"
    return
  fi

  print_info "Updating the Homebrew package index"
  package_refresh_index || return 1
  if [[ "$list_argument" == all ]]; then
    package_upgrade_all
    return
  fi

  for list_name in $list_names; do
    list_file="$(package_list_file "$list_name")" || return 1
    if [[ "$list_name" == work ]]; then
      validate_work_brewfile "$list_file" || return 1
    fi
    while IFS=$'\t' read -r entry_type entry_name; do
      [[ -n "$entry_name" ]] || continue
      status=0
      package_is_installed "$entry_type" "$entry_name" || status=$?
      [[ "$status" -eq 2 ]] && return 1
      if [[ "$status" -ne 0 ]]; then
        print_warning "$entry_type package $entry_name is not installed; skipping"
        continue
      fi
      status=0
      package_is_outdated "$entry_type" "$entry_name" || status=$?
      [[ "$status" -eq 2 ]] && return 1
      [[ "$status" -eq 0 ]] || continue

      print_info "Upgrading $entry_type package: $entry_name"
      if package_upgrade "$entry_type" "$entry_name"; then
        updated+=("$entry_name ($entry_type)")
      else
        failed+=("$entry_name ($entry_type)")
      fi
    done < <(read_package_list "$list_file")
  done

  if [[ "${#updated[@]}" -gt 0 ]]; then
    print_success "Upgraded ${#updated[@]} package(s):"
    printf '  - %s\n' "${updated[@]}"
  elif [[ "${#failed[@]}" -eq 0 ]]; then
    print_success "Every package in the $list_argument list is up to date"
  fi
  if [[ "${#failed[@]}" -gt 0 ]]; then
    print_error "Failed to upgrade ${#failed[@]} package(s):"
    printf '  - %s\n' "${failed[@]}" >&2
    return 1
  fi
}

# update_one_package NAME LIST_ARGUMENT LIST_NAMES: upgrade one installed
# package. With a list other than all, the package must be in that list.
update_one_package() {
  local package_name="$1" list_argument="$2" list_names="$3"
  local package_type="" candidate status list_name list_file in_list=false

  for candidate in $(package_types); do
    status=0
    package_is_installed "$candidate" "$package_name" || status=$?
    [[ "$status" -eq 2 ]] && return 1
    if [[ "$status" -eq 0 ]]; then
      package_type="$candidate"
      break
    fi
  done
  if [[ -z "$package_type" ]]; then
    print_error "Package '$package_name' is not installed"
    return 1
  fi

  if [[ "$list_argument" != all ]]; then
    for list_name in $list_names; do
      list_file="$(package_list_file "$list_name")" || return 1
      if package_list_entry_type "$list_file" "$package_name" >/dev/null; then
        in_list=true
      fi
    done
    if [[ "$in_list" == false ]]; then
      print_error "Package '$package_name' is not in the $list_argument list"
      return 1
    fi
  fi

  status=0
  package_is_outdated "$package_type" "$package_name" || status=$?
  [[ "$status" -eq 2 ]] && return 1
  if [[ "$status" -ne 0 ]]; then
    print_success "$package_name is already up to date"
    return 0
  fi
  print_info "Upgrading $package_type package: $package_name"
  if package_upgrade "$package_type" "$package_name"; then
    print_success "Upgraded $package_name"
  else
    print_error "Failed to upgrade $package_name"
    return 1
  fi
}

package_command_list() {
  local list_argument="${1:-all}" list_names list_name list_file entries entry_type entry_name status

  if [[ "$#" -gt 1 ]]; then
    print_error "Too many arguments for package list"
    return 1
  fi
  homebrew_require || return 1
  list_names="$(selected_package_list_names "$list_argument")" || return 1

  for list_name in $list_names; do
    list_file="$(package_list_file "$list_name")" || return 1
    if [[ ! -f "$list_file" ]]; then
      print_error "Package list not found: $(pretty_path "$list_file")"
      return 1
    fi
    print_section "$list_name packages ($(basename "$list_file"))"
    entries="$(read_package_list "$list_file")"
    if [[ -z "$entries" ]]; then
      print_info "No packages"
      continue
    fi
    while IFS=$'\t' read -r entry_type entry_name; do
      status=0
      package_is_installed "$entry_type" "$entry_name" || status=$?
      case "$status" in
        0) print_success "$entry_name ${CYAN}($entry_type)${RESET}" ;;
        1) print_error "$entry_name ${CYAN}($entry_type)${RESET} is not installed" ;;
        *) return 1 ;;
      esac
    done <<<"$entries"
  done
}
