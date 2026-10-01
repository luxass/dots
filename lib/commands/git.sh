# shellcheck shell=bash
# hooks, git-identity, secret-scan, and submodule.

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

submodule_help() {
  cat <<EOF
${BOLD}dot submodule${RESET} - private Git submodules

  status    Show the pinned commit of each submodule
  update    Move each submodule to its configured branch and stage the gitlinks
EOF
}

# Move every submodule to the latest commit of its configured branch, then
# stage the new gitlinks for review.
submodule_update() {
  local path paths=()

  while IFS= read -r path; do
    if [[ -e "$DOTFILES_DIR/$path/.git" && -n "$(git -C "$DOTFILES_DIR/$path" status --porcelain)" ]]; then
      print_error "$path has local changes; commit or discard them first"
      return 1
    fi
    paths+=("$path")
  done < <(submodule_paths)

  if [[ "${#paths[@]}" -eq 0 ]]; then
    print_info "No submodules are configured"
    return 0
  fi

  repo_git submodule sync --recursive -- "${paths[@]}" || return 1
  repo_git submodule update --remote --init --checkout --recursive -- "${paths[@]}" || return 1
  repo_git add -- "${paths[@]}" || return 1
  print_success "Submodules updated; the gitlink changes are staged for review"
}

cmd_submodule() {
  local action="${1:-status}"
  [[ "$#" -gt 0 ]] && shift

  case "$action" in
    status)
      no_args "$@" || return 1
      repo_git submodule status --recursive
      ;;
    update)
      no_args "$@" || return 1
      print_header "Updating private submodules"
      submodule_update
      ;;
    help | -h | --help) submodule_help ;;
    *)
      print_error "Unknown submodule command: $action"
      submodule_help
      return 1
      ;;
  esac
}
