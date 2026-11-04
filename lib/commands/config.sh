# shellcheck shell=bash
# config: machine-local preferences.

config_help() {
  cat <<EOF
${BOLD}dot config${RESET} - machine-local preferences

  list               Show all preferences
  get KEY            Print one value
  set KEY VALUE      Set a value (*.enabled keys take true/false, yes/no, on/off)
  unset KEY          Remove a value; interactive installation asks again
  reset              Remove every preference
  path               Print the preferences file path

${BOLD}Known keys${RESET}
  packages.brew.fonts.enabled      Select packages/bundle.fonts
  packages.brew.work.enabled       Select packages/bundle.work
  packages.brew.personal.enabled   Select packages/bundle.personal

Bundle choices also have 'dot brew bundle list/enable/disable' commands.
Both interfaces use the same keys and file. Changes never install or uninstall.
Unset choices block unattended installation, even with --yes.

Stored in $(pretty_path "$PREFS_FILE")
EOF
}

cmd_config() {
  local action="${1:-list}" value
  [[ "$#" -gt 0 ]] && shift

  case "$action" in
    list) [[ "$#" -eq 0 ]] && prefs_list ;;
    get)
      [[ "$#" -eq 1 ]] || {
        print_error "Usage: dot config get KEY"
        return 1
      }
      prefs_get "$1"
      ;;
    set)
      [[ "$#" -eq 2 ]] || {
        print_error "Usage: dot config set KEY VALUE"
        return 1
      }
      prefs_set "$1" "$2" || return 1
      value="$(prefs_get "$1")" || return 1
      print_success "$1 = $value"
      ;;
    unset)
      [[ "$#" -eq 1 ]] || {
        print_error "Usage: dot config unset KEY"
        return 1
      }
      prefs_unset "$1"
      ;;
    reset)
      [[ "$#" -eq 0 ]] || {
        print_error "Usage: dot config reset"
        return 1
      }
      rm -f "$PREFS_FILE"
      ;;
    path) [[ "$#" -eq 0 ]] && printf '%s\n' "$PREFS_FILE" ;;
    help | -h | --help) [[ "$#" -eq 0 ]] && config_help ;;
    *)
      print_error "Unknown config command: $action"
      config_help
      return 1
      ;;
  esac
}
