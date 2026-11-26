# shellcheck shell=bash
# Component registry. Everything dot sets up is a component: one file in
# dot/lib/components/<name>.sh that calls define_component and defines
#   component_<name>_install   required; must be safe to run again
#   component_<name>_update    optional; `dot update` runs install when missing
#   component_<name>_check     required; what `dot doctor` runs
# init, update, and doctor all walk DOT_COMPONENT_ORDER (component-runner.sh),
# so a tool cannot be installed by init and then forgotten by update or doctor.

# Run order for every phase. Later components may use what earlier ones installed.
DOT_COMPONENT_ORDER=(
  homebrew # Homebrew itself
  packages # packages/bundle, and packages/bundle.work when you confirm
  stow     # Stow packages; before pnpm, so its install policy applies
  skills   # shared agent skills and their lock
  git      # private starter files, repository hooks and filters
  fish     # login shell and Fisher plugins
  pnpm     # standalone pnpm, Node.js, and pnpm globals such as sfw and pi
  rust     # rustup
  gh       # GitHub CLI extensions (needs sfw)
  pi       # Pi extension dependencies and updates
  cua      # Cua Driver
  opencode # OpenCode plugin dependencies and updates
  herdr    # Herdr plugins
  rex      # Rex app (missing installs only) and its configuration
)
readonly DOT_COMPONENT_ORDER

# Names defined so far, in definition order. load_components defines them in run order.
DOT_COMPONENTS=()
# Space-padded name lists set by --only and --skip (" a b ").
DOT_ONLY_COMPONENTS=""
DOT_SKIP_COMPONENTS=""

# define_component NAME required|optional TITLE: register a component.
# Call it once at the top of the component file. A required component stops
# init and update when its step fails, and its failed check fails doctor.
# Optional components warn and continue.
define_component() {
  local name="$1" requirement="$2" title="$3"

  if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
    print_error "Invalid component name '$name': use lowercase letters, digits, and _"
    return 1
  fi
  case "$requirement" in
    required | optional) ;;
    *)
      print_error "Invalid requirement '$requirement' for component $name: expected required or optional"
      return 1
      ;;
  esac
  if [[ -z "$title" ]]; then
    print_error "Component $name needs a title"
    return 1
  fi

  printf -v "DOT_COMPONENT_REQUIREMENT__$name" '%s' "$requirement"
  printf -v "DOT_COMPONENT_TITLE__$name" '%s' "$title"
  DOT_COMPONENTS+=("$name")
}

component_is_defined() {
  local title_var="DOT_COMPONENT_TITLE__$1"
  [[ "$1" =~ ^[a-z][a-z0-9_]*$ && -n "${!title_var:-}" ]]
}

component_title() {
  local title_var="DOT_COMPONENT_TITLE__$1"
  printf '%s\n' "${!title_var}"
}

component_is_required() {
  local requirement_var="DOT_COMPONENT_REQUIREMENT__$1"
  [[ "${!requirement_var}" == required ]]
}

# component_phase_function NAME PHASE: print the function that runs a phase
# (install, update, check), or fail when there is none. update falls back to
# install, which every component keeps safe to run again.
component_phase_function() {
  local name="$1" phase="$2"

  if declare -F "component_${name}_$phase" >/dev/null; then
    printf '%s\n' "component_${name}_$phase"
  elif [[ "$phase" == update ]] && declare -F "component_${name}_install" >/dev/null; then
    printf '%s\n' "component_${name}_install"
  else
    return 1
  fi
}

# select_components ONLY_CSV SKIP_CSV: set which components run.
# Unknown names fail, so a typo never silently runs everything.
select_components() {
  local only_csv="$1" skip_csv="$2" name

  DOT_ONLY_COMPONENTS=" "
  DOT_SKIP_COMPONENTS=" "
  for name in ${only_csv//,/ }; do
    if ! component_is_defined "$name"; then
      print_error "Unknown component '$name' in --only (list them with: dot components)"
      return 1
    fi
    DOT_ONLY_COMPONENTS+="$name "
  done
  for name in ${skip_csv//,/ }; do
    if ! component_is_defined "$name"; then
      print_error "Unknown component '$name' in --skip (list them with: dot components)"
      return 1
    fi
    DOT_SKIP_COMPONENTS+="$name "
  done
  [[ "$DOT_ONLY_COMPONENTS" != " " ]] || DOT_ONLY_COMPONENTS=""
  [[ "$DOT_SKIP_COMPONENTS" != " " ]] || DOT_SKIP_COMPONENTS=""
}

# Comma-separated --only and --skip values collected by parse_component_option.
DOT_OPTION_ONLY=""
DOT_OPTION_SKIP=""
# Arguments the last parse_component_option call consumed (0: not its option).
DOT_OPTION_SHIFT=0

# parse_component_option ARGS...: parse one option shared by init, update,
# and doctor: --only LIST, --skip LIST (also --only=LIST), --dry-run, and the
# global -v and -y flags. Usage:
#   parse_component_option "$@" || return 1
#   if [[ "$DOT_OPTION_SHIFT" -gt 0 ]]; then shift "$DOT_OPTION_SHIFT"; continue; fi
parse_component_option() {
  DOT_OPTION_SHIFT=0
  case "${1:-}" in
    --dry-run)
      DOT_DRY_RUN=true
      DOT_OPTION_SHIFT=1
      ;;
    -v | --verbose)
      DOT_VERBOSE=true
      DOT_OPTION_SHIFT=1
      ;;
    -y | --yes)
      DOT_YES=true
      DOT_OPTION_SHIFT=1
      ;;
    --only | --skip)
      if [[ "$#" -lt 2 || -z "$2" ]]; then
        print_error "Option $1 needs a comma-separated list of components"
        return 1
      fi
      append_component_option "$1" "$2"
      DOT_OPTION_SHIFT=2
      ;;
    --only=* | --skip=*)
      append_component_option "${1%%=*}" "${1#*=}"
      DOT_OPTION_SHIFT=1
      ;;
  esac
}

append_component_option() {
  if [[ "$1" == --only ]]; then
    DOT_OPTION_ONLY="${DOT_OPTION_ONLY:+$DOT_OPTION_ONLY,}$2"
  else
    DOT_OPTION_SKIP="${DOT_OPTION_SKIP:+$DOT_OPTION_SKIP,}$2"
  fi
}

# component_is_selected NAME: the component runs with the current --only and --skip.
component_is_selected() {
  local name="$1"

  if [[ -n "$DOT_ONLY_COMPONENTS" && "$DOT_ONLY_COMPONENTS" != *" $name "* ]]; then
    return 1
  fi
  [[ "$DOT_SKIP_COMPONENTS" != *" $name "* ]]
}

# load_components: source dot/lib/components/<name>.sh for every name in
# DOT_COMPONENT_ORDER, and check that each file defined its component with
# install and check steps.
load_components() {
  local name

  for name in "${DOT_COMPONENT_ORDER[@]}"; do
    # shellcheck source=/dev/null
    source "$DOT_LIB_DIR/components/$name.sh" || return 1
    if ! component_is_defined "$name"; then
      print_error "Component file components/$name.sh did not call define_component $name"
      return 1
    fi
    if ! declare -F "component_${name}_install" >/dev/null || ! declare -F "component_${name}_check" >/dev/null; then
      print_error "Component $name must define component_${name}_install and component_${name}_check"
      return 1
    fi
  done
}
