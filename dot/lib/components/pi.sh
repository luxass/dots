# shellcheck shell=bash
# Pi: public extension dependencies in ~/.pi and updates.
define_component pi optional "Pi extensions"

# Pi loads extensions from their real path in the repository, so their
# dependencies install there too. Git and Stow ignore node_modules.
readonly PI_PACKAGE_DIR="$STOW_DIR/pi/.pi"

# Git dependencies, such as mpl in agent/extensions/mpl, build in their prepare
# script. pnpm runs that build with npm, which reads ignore-scripts=true from
# ~/.npmrc and silently skips it. Allow scripts for this one install only.
# pnpm-workspace.yaml's allowBuilds still names every package that may run one.
pi_install_dependencies() {
  NPM_CONFIG_IGNORE_SCRIPTS=false pnpm_install_deps "$PI_PACKAGE_DIR" "Pi extension"
}

# pi_mpl_built: mpl, if installed, has its build output. A plain pnpm install
# leaves it without dist/ (see pi_install_dependencies).
pi_mpl_built() {
  local mpl="$PI_PACKAGE_DIR/agent/extensions/mpl/node_modules/mpl"
  [[ ! -e "$mpl" ]] || [[ -f "$mpl/dist/browser/index.js" ]]
}

# Pi's camelCase pnpm flag doesn't override pnpm 12's release-age policy, so
# both updates set the supported env override for that one command.
pi_update_self() {
  if ! command_exists pi; then
    print_warning "Pi is missing; skipping its update"
    return 0
  fi
  PNPM_CONFIG_MINIMUM_RELEASE_AGE=0 sfw pi update --self || {
    print_error "Failed to update Pi"
    return 1
  }
}

pi_update_extensions() {
  command_exists pi || return 0
  confirm "Update installed Pi extension packages?" n || return 0
  NPM_CONFIG_MIN_RELEASE_AGE=0 PNPM_CONFIG_MINIMUM_RELEASE_AGE=0 sfw pi update --extensions || {
    print_error "Failed to update Pi extensions"
    return 1
  }
  print_success "Pi extensions updated"
}

pi_check() {
  local failed=0

  if [[ -f "$PI_PACKAGE_DIR/package.json" ]]; then
    if [[ -d "$PI_PACKAGE_DIR/node_modules/@earendil-works/pi-coding-agent" ]]; then
      print_success "Pi extension dependencies"
    else
      print_error "Pi extension dependencies are missing; run 'dot init --only pi'"
      failed=1
    fi
    if pi_mpl_built; then
      print_success "mpl chart library is built"
    else
      print_error "mpl is installed without its build; run 'dot init --only pi', not a plain pnpm install"
      failed=1
    fi
  fi
  return "$failed"
}

component_pi_install() { pi_install_dependencies; }

component_pi_update() {
  local failed=0
  pi_update_self || failed=1
  pi_install_dependencies || failed=1
  pi_update_extensions || failed=1
  return "$failed"
}

component_pi_check() { pi_check; }
