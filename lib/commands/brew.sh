# shellcheck shell=bash
# Homebrew declarations, local bundle selection, and installed-package inventory.

brew_help() {
  cat <<EOF
${BOLD}dot brew${RESET} - Homebrew packages and machine-local bundle choices

  list [GROUP]                          Show declaration, selection, and installation
  check                                 Check all enabled bundles and unresolved choices
  bundle list                           Show local bundle choices
  bundle enable|disable GROUP           Save a choice only; never install or uninstall
  install                               Install missing packages in enabled bundles
  add NAME [--cask|--formula] [--group GROUP]
                                        Declare a package; install if its bundle is enabled
  remove NAME [--cask|--formula] [--group GROUP]
                                        Remove its declaration only
  uninstall NAME [--cask|--formula]       Uninstall an undeclared, inactive package
  unmanaged                             Undeclared requested formulae and installed casks
  update [NAME] [--cask|--formula]        Upgrade all installed packages, or one package

Groups: ${BUNDLE_GROUPS[*]}. Base is always enabled. Other choices use the
existing dot config preferences. Disabled bundles never cause uninstalls.
Updates cover all installed packages, including disabled bundles and untracked
packages. First setup needs explicit choices; --yes never selects bundles.
EOF
}

PACKAGE_LOADED=false
PACKAGE_INVENTORY=''
PACKAGE_INSTALLED=''

package_load_installed() {
  local index
  [[ "$PACKAGE_LOADED" == true ]] && return 0
  command_exists jq || {
    print_error "jq is required to read Homebrew metadata"
    return 1
  }
  PACKAGE_INVENTORY="$(HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 --installed)" || return 1
  index="$(brew_metadata_index <<<"$PACKAGE_INVENTORY")" || return 1
  PACKAGE_INSTALLED="$(jq -r '
    (.formulae[]
      | if (.installed | type) != "array" or (.installed | length) == 0 then
          error("Invalid installed formula metadata") else . end
      | ["formula", .full_name, (any(.installed[]; .installed_on_request == true) | tostring)] | @tsv),
    (.casks[] | ["cask", .full_token, "true"] | @tsv)
  ' <<<"$PACKAGE_INVENTORY")" || return 1
  BREW_NAMES+="$index"$'\n'
  PACKAGE_LOADED=true
}

package_installed() {
  local identity
  identity="$(brew_identity "$1" "$2")" || return 1
  awk -F '\t' -v type="$1" -v name="$identity" '
    $1 == type && $2 == name { found = 1 }
    END { exit !found }
  ' <<<"$PACKAGE_INSTALLED"
}

package_prepare() {
  bundle_load || return 1
  # bundle_load rebuilds the identity index, so append installed identities anew.
  PACKAGE_LOADED=false
  package_load_installed
}

# package_groups [GROUP]: one validated group, or all of them.
package_groups() {
  if [[ -n "${1:-}" ]]; then
    bundle_file "$1" >/dev/null || return 1
    printf '%s\n' "$1"
  else
    printf '%s\n' "${BUNDLE_GROUPS[@]}"
  fi
}

# package_find GROUP NAME: print "TYPE ENTRY" when the group tracks NAME,
# matching either the full entry or its short name.
package_find() {
  local type entry
  while read -r type entry; do
    if [[ "$entry" == "$2" || "${entry##*/}" == "$2" ]]; then
      printf '%s %s\n' "$type" "$entry"
      return 0
    fi
  done < <(bundle_entries "$(bundle_file "$1")")
  return 1
}

package_list() {
  local groups group state row_group type name identity status
  [[ "$#" -le 1 ]] || {
    print_error "Usage: dot brew list [GROUP]"
    return 1
  }
  groups="$(package_groups "${1:-}")" || return 1
  package_prepare || return 1
  printf '%-10s %-10s %-8s %-42s %s\n' BUNDLE SELECTION TYPE PACKAGE INSTALLED
  while IFS= read -r group; do
    state="$(bundle_state "$group")" || return 1
    while IFS=$'\t' read -r row_group type name identity; do
      [[ "$row_group" == "$group" ]] || continue
      status=no
      package_installed "$type" "$identity" && status=yes
      printf '%-10s %-10s %-8s %-42s %s\n' "$group" "$state" "$type" "$name" "$status"
    done <<<"$BUNDLE_ROWS"
  done <<<"$groups"
}

package_check() {
  package_prepare || return 1
  bundles_check
}

package_bundle() {
  local action="${1:-help}" group state
  [[ "$#" -eq 0 ]] || shift
  case "$action" in
    list)
      [[ "$#" -eq 0 ]] || {
        print_error "Usage: dot brew bundle list"
        return 1
      }
      printf '%-10s %s\n' BUNDLE SELECTION
      for group in "${BUNDLE_GROUPS[@]}"; do
        state="$(bundle_state "$group")" || return 1
        printf '%-10s %s\n' "$group" "$state"
      done
      ;;
    enable | disable)
      [[ "$#" -eq 1 ]] || {
        print_error "Usage: dot brew bundle $action GROUP"
        return 1
      }
      group="$1"
      bundle_file "$group" >/dev/null || return 1
      if [[ "$group" == base ]]; then
        [[ "$action" == enable ]] || {
          print_error "Base cannot be disabled"
          return 1
        }
      elif [[ "$action" == enable ]]; then
        prefs_set "$(bundle_pref_key "$group")" true || return 1
      else
        prefs_set "$(bundle_pref_key "$group")" false || return 1
      fi
      print_success "$group: $action (selection only; installed packages unchanged)"
      ;;
    help | -h | --help) [[ "$#" -eq 0 ]] && brew_help ;;
    *)
      print_error "Unknown bundle action: $action"
      return 1
      ;;
  esac
}

package_add() {
  local name='' type='' group=base file state found_formula=false found_cask=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --cask) type=cask ;;
      --formula) type=formula ;;
      --group=*) group="${1#*=}" ;;
      -g | --group)
        [[ "$#" -ge 2 ]] || {
          print_error "$1 needs a group name"
          return 1
        }
        group="$2"
        shift
        ;;
      -*)
        print_error "Unknown option: $1"
        return 1
        ;;
      *)
        [[ -z "$name" ]] || {
          print_error "Add one package at a time"
          return 1
        }
        name="$1"
        ;;
    esac
    shift
  done
  [[ -n "$name" ]] || {
    print_error "Usage: dot package add NAME [--cask|--formula] [--group GROUP]"
    return 1
  }
  file="$(bundle_file "$group")" || return 1

  if [[ -z "$type" ]]; then
    brew info --formula "$name" >/dev/null 2>&1 && found_formula=true
    brew info --cask "$name" >/dev/null 2>&1 && found_cask=true
    if [[ "$found_formula" == true && "$found_cask" == true ]]; then
      print_error "$name is both a formula and a cask; pass --formula or --cask"
      return 1
    elif [[ "$found_formula" == true ]]; then
      type=formula
    elif [[ "$found_cask" == true ]]; then
      type=cask
    else
      print_error "No formula or cask named $name"
      return 1
    fi
  fi

  if package_find "$group" "$name" >/dev/null; then
    print_info "$name is already in the $group group"
  else
    touch "$file" || return 1
    brew bundle add --file "$file" --no-describe "--$type" "$name" || return 1
    bundle_sort "$file" || return 1
    print_success "Added $type $name to the $group group"
  fi

  state="$(bundle_state "$group")"
  if [[ "$state" != enabled ]]; then
    print_info "Not installing: the $group group is $state on this machine"
    return 0
  fi
  package_load_installed || return 1
  if package_installed "$type" "$name"; then
    print_success "$name is installed"
  elif [[ "$type" == cask ]]; then
    brew install --cask "$name"
  else
    brew install "$name"
  fi
}

package_remove() {
  local name='' only='' group match type entry removed=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --group=*) only="${1#*=}" ;;
      -g | --group)
        [[ "$#" -ge 2 ]] || {
          print_error "$1 needs a group name"
          return 1
        }
        only="$2"
        shift
        ;;
      -*)
        print_error "Unknown option: $1"
        return 1
        ;;
      *) name="$1" ;;
    esac
    shift
  done
  [[ -n "$name" ]] || {
    print_error "Usage: dot package remove NAME [--group GROUP]"
    return 1
  }
  package_groups "$only" >/dev/null || return 1

  while IFS= read -r group; do
    match="$(package_find "$group" "$name")" || continue
    read -r type entry <<<"$match"
    brew bundle remove --file "$(bundle_file "$group")" "--$type" "$entry" || return 1
    print_success "Removed $type $entry from the $group group"
    removed=true
  done < <(package_groups "$only")

  if [[ "$removed" != true ]]; then
    print_warning "$name is not tracked${only:+ in the $only group}"
    return 1
  fi

  package_load_installed || return 1
  if package_installed "$type" "$entry" && confirm "Uninstall $entry from this machine?" n; then
    if [[ "$type" == cask ]]; then
      brew uninstall --cask "$entry"
    else
      brew uninstall "$entry"
    fi
  fi
}

package_unmanaged() {
  local type identity requested group row_type name row_identity declared found=false
  package_prepare || return 1
  while IFS=$'\t' read -r type identity requested; do
    [[ "$requested" == true ]] || continue
    declared=false
    while IFS=$'\t' read -r group row_type name row_identity; do
      if [[ "$type" == "$row_type" && "$identity" == "$row_identity" ]]; then
        declared=true
        break
      fi
    done <<<"$BUNDLE_ROWS"
    if [[ "$declared" == false ]]; then
      printf '%-8s %s\n' "$type" "$identity"
      found=true
    fi
  done <<<"$PACKAGE_INSTALLED"
  if [[ "$found" == false ]]; then
    print_success "All requested formulae and installed casks are declared"
  fi
}

package_update() {
  local name="${1:-}"

  if [[ -z "$name" ]]; then
    brew update || return 1
    homebrew_upgrade
    return
  fi

  package_load_installed || return 1
  if package_installed formula "$name"; then
    brew upgrade "$name"
  elif package_installed cask "$name"; then
    brew upgrade --cask "$name"
  else
    print_error "$name is not installed"
    return 1
  fi
}

cmd_brew() {
  local action="${1:-help}"
  [[ "$#" -eq 0 ]] || shift
  case "$action" in
    help | -h | --help)
      [[ "$#" -eq 0 ]] && brew_help
      return
      ;;
    bundle)
      package_bundle "$@"
      return
      ;;
  esac
  homebrew_require || return 1
  case "$action" in
    list) package_list "$@" ;;
    check) [[ "$#" -eq 0 ]] && package_check ;;
    install) [[ "$#" -eq 0 ]] && packages_install ;;
    add) package_add "$@" ;;
    remove) package_remove "$@" ;;
    unmanaged) [[ "$#" -eq 0 ]] && package_unmanaged ;;
    update) package_update "$@" ;;
    *)
      print_error "Unknown brew action: $action"
      return 1
      ;;
  esac
}
