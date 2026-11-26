# shellcheck shell=bash
# Homebrew itself. Install it by hand first; dot prints the official command.
# Its packages are the packages component, which also runs brew update.
define_component homebrew required "Homebrew"

homebrew_require() {
  command_exists brew && return 0
  print_error "Homebrew is missing. Install it with:"
  # shellcheck disable=SC2016 # printed for the user, not expanded
  printf '  %s\n' '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  return 1
}

component_homebrew_install() {
  homebrew_require || return 1
  print_success "Homebrew is installed"
}

component_homebrew_check() {
  homebrew_require || return 1
  print_success "$(brew --version | head -n 1)"
}
