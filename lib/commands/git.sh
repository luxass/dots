# shellcheck shell=bash
# hooks and secret-scan.

cmd_hooks() {
  no_args "$@" || return 1
  git_install_hooks
}

cmd_secret_scan() {
  no_args "$@" || return 1
  if git_secret_scan; then
    print_success "Secret scan passed"
  else
    print_error "Possible secrets found"
    return 1
  fi
}
