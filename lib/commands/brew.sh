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

# Match declarations by canonical identity, never by a shortened tap name.
package_find() {
  awk -F '\t' -v group="$1" -v type="$2" -v identity="$3" '
    (!group || $1 == group) && $2 == type && $4 == identity { print; found = 1 }
    END { exit !found }
  ' <<<"$BUNDLE_ROWS"
}

# One strict parser for package mutations. Results stay in this shell.
package_parse() {
  local action="$1" flag group_seen=false
  shift
  PACKAGE_NAME=''
  PACKAGE_TYPE=''
  PACKAGE_GROUP=''
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --formula | --cask)
        flag="${1#--}"
        if [[ -n "$PACKAGE_TYPE" && "$PACKAGE_TYPE" != "$flag" ]]; then
          print_error "Choose either --formula or --cask"
          return 1
        fi
        PACKAGE_TYPE="$flag"
        ;;
      --group=* | --group | -g)
        [[ "$action" == add || "$action" == remove ]] || {
          print_error "$action does not take --group"
          return 1
        }
        [[ "$group_seen" == false ]] || {
          print_error "Choose one bundle"
          return 1
        }
        group_seen=true
        if [[ "$1" == --group=* ]]; then
          PACKAGE_GROUP="${1#*=}"
        else
          [[ "$#" -ge 2 ]] || {
            print_error "$1 needs a bundle name"
            return 1
          }
          PACKAGE_GROUP="$2"
          shift
        fi
        bundle_file "$PACKAGE_GROUP" >/dev/null || return 1
        ;;
      -*)
        print_error "Unknown option: $1"
        return 1
        ;;
      *)
        [[ -z "$PACKAGE_NAME" ]] || {
          print_error "Choose one package"
          return 1
        }
        PACKAGE_NAME="$1"
        ;;
    esac
    shift
  done
  if [[ -z "$PACKAGE_NAME" ]]; then
    [[ "$action" == update && -z "$PACKAGE_TYPE" ]] && return 0
    print_error "Usage: dot brew $action NAME [--formula|--cask]"
    return 1
  fi
  [[ "$PACKAGE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9@._+/-]*$ ]] || {
    print_error "Invalid package name"
    return 1
  }
  if [[ "$action" == add && -z "$PACKAGE_GROUP" ]]; then PACKAGE_GROUP=base; fi
}

# Resolve a known name. More than one type or tap requires an explicit choice.
package_resolve() {
  local type identity status found=false
  RESOLVED_TYPE=''
  RESOLVED_NAME=''
  for type in formula cask; do
    [[ -z "$PACKAGE_TYPE" || "$PACKAGE_TYPE" == "$type" ]] || continue
    if identity="$(brew_identity "$type" "$PACKAGE_NAME")"; then
      if [[ "$found" == true ]]; then
        print_error "$PACKAGE_NAME is both a formula and a cask; use --formula or --cask"
        return 1
      fi
      RESOLVED_TYPE="$type"
      RESOLVED_NAME="$identity"
      found=true
    else
      status=$?
      [[ "$status" -ne 2 ]] || {
        print_error "Use a fully qualified tap name for $PACKAGE_NAME"
        return 1
      }
    fi
  done
  [[ "$found" == true ]] || {
    print_error "Cannot resolve $PACKAGE_NAME; check its name and type"
    return 1
  }
}

# New declarations need current native metadata, not a second name resolver.
package_available() {
  local type data index found=false
  for type in formula cask; do
    [[ -z "$PACKAGE_TYPE" || "$PACKAGE_TYPE" == "$type" ]] || continue
    if data="$(HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 "--$type" "$PACKAGE_NAME" 2>/dev/null)"; then
      index="$(brew_metadata_index <<<"$data")" || return 1
      BREW_NAMES+="$index"$'\n'
      found=true
    fi
  done
  [[ "$found" == true ]] || {
    print_error "Cannot read Homebrew metadata for $PACKAGE_NAME"
    return 1
  }
  package_resolve
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
  local file state status match group type name identity
  package_parse add "$@" || return 1
  file="$(bundle_file "$PACKAGE_GROUP")" || return 1
  package_prepare || return 1
  package_available || return 1
  if match="$(package_find '' "$RESOLVED_TYPE" "$RESOLVED_NAME")"; then
    IFS=$'\t' read -r group type name identity <<<"$match"
    if [[ "$group" != "$PACKAGE_GROUP" ]]; then
      print_error "$RESOLVED_NAME already belongs to $group; remove that declaration before moving it"
      return 1
    fi
  fi
  state="$(bundle_state "$PACKAGE_GROUP")" || return 1
  if [[ "$state" == unset ]]; then
    if preference_enabled "$(bundle_pref_key "$PACKAGE_GROUP")" "Enable the $PACKAGE_GROUP bundle on this machine?"; then
      state=enabled
    else
      status=$?
      [[ "$status" -eq 1 ]] || return 1
      state=disabled
    fi
  fi
  if [[ -z "$match" ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle add --file "$file" --no-describe "--$RESOLVED_TYPE" "$RESOLVED_NAME" || return 1
    bundle_sort "$file" || return 1
    print_success "Declared $RESOLVED_TYPE $RESOLVED_NAME in $PACKAGE_GROUP"
  fi
  if [[ "$state" != enabled ]]; then
    print_info "$PACKAGE_GROUP is disabled; declaration saved without installation"
  elif package_installed "$RESOLVED_TYPE" "$RESOLVED_NAME"; then
    print_success "$RESOLVED_NAME is already installed"
  else
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_AUTOREMOVE=1 \
      brew install "--$RESOLVED_TYPE" "$RESOLVED_NAME" || {
      print_error "Installation failed; the declaration remains in $PACKAGE_GROUP"
      return 1
    }
  fi
}

package_remove() {
  local match group type name identity file
  package_parse remove "$@" || return 1
  bundle_load || return 1
  package_resolve || return 1
  match="$(package_find "$PACKAGE_GROUP" "$RESOLVED_TYPE" "$RESOLVED_NAME")" || {
    print_error "$PACKAGE_NAME is not declared in the requested bundle"
    return 1
  }
  IFS=$'\t' read -r group type name identity <<<"$match"
  file="$(bundle_file "$group")" || return 1
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle remove --file "$file" "--$type" "$name" || return 1
  print_success "Removed $name from $group; installed packages unchanged"
}

# Refuse active services or executables; never stop anything for an uninstall.
package_refuse_active() {
  local services processes paths prefix cellar executables labels label status
  services="$(HOMEBREW_NO_AUTO_UPDATE=1 brew services list --json)" || return 1
  if ! jq -e --arg name "$RESOLVED_NAME" --arg short "${RESOLVED_NAME##*/}" '
    if type != "array" then error("Invalid service inventory") else . end
    | all(.[]; (.name != $name and .name != $short)
      or (.status == "none" or .status == "stopped"))
  ' <<<"$services" >/dev/null; then
    print_error "Cannot uninstall $RESOLVED_NAME: stop its service explicitly first (or repair the service inventory)"
    return 1
  fi
  processes="$(ps -axo comm=)" || return 1
  if [[ "$RESOLVED_TYPE" == formula ]]; then
    prefix="$(brew --prefix)" || return 1
    cellar="$(brew --cellar "$RESOLVED_NAME")" || return 1
    paths="$(brew list --formula "$RESOLVED_NAME")" || return 1
    executables="$(awk '/\/(s?bin)\/[^/]+$/ { sub(/^.*\//, ""); print }' <<<"$paths")" || return 1
    paths="$cellar/"$'\n'"$prefix/opt/${RESOLVED_NAME##*/}/"
    while IFS= read -r label; do
      [[ -n "$label" ]] || continue
      paths+=$'\n'"$prefix/bin/$label"$'\n'"$prefix/sbin/$label"
    done <<<"$executables"
  else
    paths="$(jq -r --arg name "$RESOLVED_NAME" '
      .casks[] | select(.full_token == $name) | .artifacts[] | .target? // empty
    ' <<<"$PACKAGE_INVENTORY")" || return 1
    if [[ -z "$paths" ]]; then
      print_error "Cannot identify installed app or executable paths for $RESOLVED_NAME; refusing automatic uninstall"
      return 1
    fi
    labels="$(jq -r --arg name "$RESOLVED_NAME" '
      .casks[] | select(.full_token == $name) | .artifacts[]
      | .uninstall[]? | .launchctl? // empty | if type == "array" then .[] else . end
    ' <<<"$PACKAGE_INVENTORY")" || return 1
    while IFS= read -r label; do
      [[ -n "$label" ]] || continue
      if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1 || launchctl print "system/$label" >/dev/null 2>&1; then
        print_error "Cannot uninstall $RESOLVED_NAME: stop its launch service explicitly first"
        return 1
      fi
    done <<<"$labels"
  fi
  if awk -v paths="$paths" -v executables="${executables:-}" '
    BEGIN { count = split(paths, targets, "\n"); bins = split(executables, names, "\n") }
    {
      sub(/^[[:space:]]+/, "")
      for (i = 1; i <= count; i++) {
        if (targets[i] != "" && ($0 == targets[i] || index($0, targets[i] "/") == 1 ||
          (substr(targets[i], length(targets[i])) == "/" && index($0, targets[i]) == 1))) active = 1
      }
      for (i = 1; i <= bins; i++) if (names[i] != "" && $0 == names[i]) active = 1
    }
    END { exit !active }
  ' <<<"$processes"; then
    print_error "Cannot uninstall $RESOLVED_NAME: close its active app or command explicitly first"
    return 1
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] || {
    print_error "Cannot inspect active processes safely"
    return 1
  }
}

package_uninstall() {
  local match
  package_parse uninstall "$@" || return 1
  package_prepare || return 1
  package_resolve || return 1
  if match="$(package_find '' "$RESOLVED_TYPE" "$RESOLVED_NAME")"; then
    print_error "$RESOLVED_NAME is still declared in $(awk -F '\t' '{ print $1 }' <<<"$match"); remove its declaration first"
    return 1
  fi
  package_installed "$RESOLVED_TYPE" "$RESOLVED_NAME" || {
    print_error "$RESOLVED_NAME is not installed"
    return 1
  }
  package_refuse_active || return 1
  print_info "Uninstall target: $RESOLVED_TYPE $RESOLVED_NAME (no user-data or dependency cleanup)"
  confirm "Uninstall this package from this machine?" n || return 0
  # Recheck after the human confirmation in case an app or service started.
  package_refuse_active || return 1
  HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 \
    brew uninstall "--$RESOLVED_TYPE" "$RESOLVED_NAME"
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
  package_parse update "$@" || return 1
  if [[ -z "$PACKAGE_NAME" ]]; then
    brew update || return 1
    homebrew_upgrade
    return
  fi
  # Standalone upgrades do not depend on bundle selection or declaration validity.
  BREW_NAMES=''
  PACKAGE_LOADED=false
  package_load_installed || return 1
  package_resolve || return 1
  package_installed "$RESOLVED_TYPE" "$RESOLVED_NAME" || {
    print_error "$RESOLVED_NAME is not installed"
    return 1
  }
  print_info "Upgrade target: $RESOLVED_TYPE $RESOLVED_NAME (all-installed policy)"
  confirm "Upgrade this installed package?" n || return 0
  HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 \
    brew upgrade "--$RESOLVED_TYPE" "$RESOLVED_NAME"
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
    check | install | unmanaged)
      [[ "$#" -eq 0 ]] || {
        print_error "Usage: dot brew $action"
        return 1
      }
      case "$action" in
        check) package_check ;;
        install) packages_install ;;
        unmanaged) package_unmanaged ;;
      esac
      ;;
    add) package_add "$@" ;;
    remove) package_remove "$@" ;;
    uninstall) package_uninstall "$@" ;;
    update) package_update "$@" ;;
    *)
      print_error "Unknown brew action: $action"
      return 1
      ;;
  esac
}
