# shellcheck shell=bash
# hooks, git-identity, and secret-scan.

cmd_hooks() {
  no_args "$@" || return 1
  git_install_hooks
}

cmd_git_identity() {
  no_args "$@" || return 1
  print_header "Git identity"
  git_write_identity true
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
