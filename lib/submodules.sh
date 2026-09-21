private_submodule_paths() {
  printf '%s\n' private/opencode private/pi
}

private_submodule_configured() {
  local path="$1"
  git -C "$DOTFILES_DIR" config -f .gitmodules --get "submodule.$path.path" >/dev/null 2>&1
}

update_private_submodules() {
  local path
  local -a paths=()

  [[ -f "$DOTFILES_DIR/.gitmodules" ]] || {
    print_warning "No .gitmodules file found"
    return 0
  }

  while IFS= read -r path; do
    private_submodule_configured "$path" || continue

    if [[ ! -d "$DOTFILES_DIR/$path" ]]; then
      print_error "Missing submodule directory: $path"
      return 1
    fi

    if [[ -d "$DOTFILES_DIR/$path/.git" || -f "$DOTFILES_DIR/$path/.git" ]]; then
      if [[ -n "$(git -C "$DOTFILES_DIR/$path" status --porcelain --untracked-files=all)" ]]; then
        print_error "Submodule has local changes: $path"
        print_info "Commit or discard them before updating private submodules"
        return 1
      fi
    fi

    paths+=("$path")
  done < <(private_submodule_paths)

  if [[ "${#paths[@]}" -eq 0 ]]; then
    print_verbose "No private submodules are configured"
    return 0
  fi

  print_info "Synchronizing private submodule URLs"
  git -C "$DOTFILES_DIR" submodule sync --recursive -- "${paths[@]}"
  print_info "Fetching latest private submodule commits"
  git -C "$DOTFILES_DIR" submodule update \
    --remote --init --checkout --recursive -- "${paths[@]}"
  git -C "$DOTFILES_DIR" add -- "${paths[@]}"
  print_success "Private submodules updated to their configured branches"
  print_info "Gitlink changes are staged; review them, then commit the parent repository"
}

cmd_submodule() {
  local action="${1:-}"
  shift || true

  case "$action" in
    update)
      parse_verbose_args "$@" || return 1
      print_header "Updating private submodules"
      update_private_submodules
      ;;
    status)
      parse_verbose_args "$@" || return 1
      git -C "$DOTFILES_DIR" submodule status --recursive
      ;;
    *)
      print_error "Usage: dot submodule {update|status}"
      return 1
      ;;
  esac
}
