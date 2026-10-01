# shellcheck shell=bash
# package: Homebrew bundle management. Writes go through `brew bundle add` and
# `brew bundle remove`; everything else reads the Brewfiles directly.

package_help() {
  cat <<EOF
${BOLD}dot package${RESET} - Homebrew packages in packages/bundle*

  list [GROUP]                          Show every package and whether it is installed
  check                                 Show only what is missing
  add NAME [--cask|--formula] [--group GROUP]
                                        Track a package and install it (default group: base)
  remove NAME [--group GROUP]           Stop tracking a package, then offer to uninstall it
  unmanaged                             Installed packages that no bundle tracks
  update [NAME]                         Upgrade one package, or review all available upgrades

Groups: ${BUNDLE_GROUPS[*]}. base is always installed; enable the others per
machine with 'dot config set packages.brew.GROUP.enabled true'.
EOF
}

PACKAGE_FORMULAE=''
PACKAGE_CASKS=''
PACKAGE_LOADED=false

# Read installed formulae and casks once per run.
package_load_installed() {
  [[ "$PACKAGE_LOADED" == true ]] && return 0
  PACKAGE_FORMULAE="$(brew list --formula -1 2>/dev/null || true)"
  PACKAGE_CASKS="$(brew list --cask -1 2>/dev/null || true)"
  PACKAGE_LOADED=true
}

# package_installed TYPE NAME: formulae match by short name (tap/name -> name).
package_installed() {
  if [[ "$1" == cask ]]; then
    grep -qxF "$2" <<<"$PACKAGE_CASKS"
  else
    grep -qxF "${2##*/}" <<<"$PACKAGE_FORMULAE"
  fi
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

# package_group_header GROUP STATE INSTALLED TOTAL
package_group_header() {
  local group="$1" state="$2" installed="$3" total="$4" summary
  case "$state" in
    disabled) summary="${DIM}disabled on this machine${RESET}" ;;
    unset) summary="${YELLOW}not chosen yet; 'dot init' will ask${RESET}" ;;
    *)
      if [[ "$installed" -eq "$total" ]]; then
        summary="${GREEN}$installed/$total installed${RESET}"
      else
        summary="${YELLOW}$installed/$total installed${RESET}"
      fi
      ;;
  esac
  printf '%s%-9s%s %s%-26s%s %s\n' "$BOLD" "$group" "$RESET" "$DIM" "packages/$(basename "$(bundle_file "$group")")" "$RESET" "$summary"
}

# package_row MARK NAME TYPE [NOTE]
package_row() {
  printf '  %s %-36s %s%s%s%s\n' "$1" "$2" "$DIM" "$3" "$RESET" "${4:+  $4}"
}

# package_report GROUP all|missing: print a group; returns 1 when an enabled
# group is missing packages.
package_report() {
  local group="$1" mode="$2" state file type name installed=0 total=0 rows=''
  state="$(bundle_state "$group")"
  file="$(bundle_file "$group")"
  [[ -f "$file" ]] || return 0

  while read -r type name; do
    total=$((total + 1))
    if [[ "$state" != enabled ]]; then
      rows+="$(package_row "${DIM}·${RESET}" "$name" "$type")"$'\n'
    elif package_installed "$type" "$name"; then
      installed=$((installed + 1))
      [[ "$mode" == all ]] && rows+="$(package_row "${GREEN}✓${RESET}" "$name" "$type")"$'\n'
    else
      rows+="$(package_row "${RED}✗${RESET}" "$name" "$type" "${RED}missing${RESET}")"$'\n'
    fi
  done < <(bundle_entries "$file")

  [[ "$mode" == all ]] && echo
  package_group_header "$group" "$state" "$installed" "$total"
  if [[ "$mode" == all || "$state" == enabled ]]; then
    printf '%s' "$rows"
  fi
  [[ "$state" != enabled || "$installed" -eq "$total" ]]
}

package_list() {
  local group groups
  groups="$(package_groups "${1:-}")" || return 1
  package_load_installed
  while IFS= read -r group; do
    package_report "$group" all || true
  done <<<"$groups"
}

package_check() {
  local group failed=0
  package_load_installed
  echo
  for group in "${BUNDLE_GROUPS[@]}"; do
    package_report "$group" missing || failed=1
  done
  echo
  if [[ "$failed" -eq 0 ]]; then
    print_success "All enabled groups are installed"
  else
    print_error "Some packages are missing; run 'dot init' or 'brew install NAME'"
  fi
  return "$failed"
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
  package_load_installed
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

  package_load_installed
  if package_installed "$type" "$entry" && confirm "Uninstall $name from this machine?" n; then
    if [[ "$type" == cask ]]; then
      brew uninstall --cask "$name"
    else
      brew uninstall "$name"
    fi
  fi
}

package_unmanaged() {
  local group type name tracked_formulae='' tracked_casks='' formulae casks

  for group in "${BUNDLE_GROUPS[@]}"; do
    while read -r type name; do
      if [[ "$type" == cask ]]; then
        tracked_casks+="$name"$'\n'
      else
        tracked_formulae+="${name##*/}"$'\n'
      fi
    done < <(bundle_entries "$(bundle_file "$group")")
  done

  formulae="$(comm -23 <(brew leaves --installed-on-request | sed 's#.*/##' | sort -u) <(sort -u <<<"$tracked_formulae"))"
  casks="$(comm -23 <(brew list --cask -1 | sort -u) <(sort -u <<<"$tracked_casks"))"

  if [[ -z "$formulae$casks" ]]; then
    print_success "Every installed package is tracked"
    return 0
  fi

  if [[ -n "$formulae" ]]; then
    print_section "Formulae ($(grep -c . <<<"$formulae"))"
    indent <<<"$formulae"
  fi
  if [[ -n "$casks" ]]; then
    print_section "Casks ($(grep -c . <<<"$casks"))"
    indent <<<"$casks"
  fi
  printf '\n%sTrack:%s  dot package add NAME [--group GROUP]\n' "$DIM" "$RESET"
  printf '%sRemove:%s brew uninstall NAME\n' "$DIM" "$RESET"
}

package_update() {
  local name="${1:-}"

  if [[ -z "$name" ]]; then
    brew update || return 1
    homebrew_upgrade
    return
  fi

  package_load_installed
  if package_installed formula "$name"; then
    brew upgrade "$name"
  elif package_installed cask "$name"; then
    brew upgrade --cask "$name"
  else
    print_error "$name is not installed"
    return 1
  fi
}

cmd_package() {
  local action="${1:-list}"
  [[ "$#" -gt 0 ]] && shift

  case "$action" in
    help | -h | --help)
      package_help
      return 0
      ;;
  esac
  homebrew_require || return 1

  case "$action" in
    list) package_list "$@" ;;
    check) no_args "$@" && package_check ;;
    add) package_add "$@" ;;
    remove) package_remove "$@" ;;
    unmanaged) no_args "$@" && package_unmanaged ;;
    update) package_update "$@" ;;
    *)
      print_error "Unknown package command: $action"
      package_help
      return 1
      ;;
  esac
}
