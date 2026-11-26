# shellcheck shell=bash
# dot update: pull the repository, then run every component's update step.
# Components without an update step run their install step.

cmd_update_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot update [--only LIST] [--skip LIST] [--dry-run] [--no-pull]

Pull the dotfiles repository, then update every component in order
('dot components'). When the pull changes dot/ itself, dot restarts with the
new version first. A failed required component stops the run.

${BOLD}OPTIONS${RESET}
  --only LIST   Update only these components (comma-separated)
  --skip LIST   Skip these components (comma-separated)
  --dry-run     Print the plan and change nothing (no pull either)
  --no-pull     Skip the git pull
EOF
}

cmd_update() {
  local pull=true original_args=("$@")

  DOT_OPTION_ONLY=""
  DOT_OPTION_SKIP=""
  while [[ "$#" -gt 0 ]]; do
    parse_component_option "$@" || return 1
    if [[ "$DOT_OPTION_SHIFT" -gt 0 ]]; then
      shift "$DOT_OPTION_SHIFT"
      continue
    fi
    case "$1" in
      --no-pull) pull=false ;;
      *)
        print_error "Unknown update option: $1"
        print_info "Run 'dot update --help' for usage"
        return 1
        ;;
    esac
    shift
  done
  select_components "$DOT_OPTION_ONLY" "$DOT_OPTION_SKIP" || return 1

  if [[ "$DOT_DRY_RUN" == true ]]; then
    print_header "Updating dotfiles (dry run: nothing changes)"
    if [[ "$pull" == true ]]; then
      print_info "Would run: git -C $(pretty_path "$DOTFILES_DIR") pull --ff-only"
    fi
  else
    acquire_run_lock || return 1
    print_header "Updating dotfiles"
    if [[ "$pull" == true ]]; then
      pull_dotfiles_and_restart ${original_args[@]+"${original_args[@]}"} || return 1
    fi
  fi

  if ! run_component_phase update; then
    print_header "Update stopped at a failed required component"
    return 1
  fi
  if [[ "$DOT_DRY_RUN" == true ]]; then
    print_header "Dry run complete (nothing changed)"
  else
    print_header "Update complete"
  fi
}

# pull_dotfiles_and_restart ARGS...: fast-forward the repository. When the
# pull changed dot/, exec the new dot with --no-pull and the same arguments:
# this shell already loaded the old functions, and the new components may
# differ. exec keeps the PID, so the new process keeps the run lock.
pull_dotfiles_and_restart() {
  local head_before head_after

  repo_is_git || return 0
  head_before="$(repo_git rev-parse HEAD)" || return 1
  print_info "Pulling latest changes"
  if ! repo_git pull --ff-only; then
    print_error "Failed to pull the dotfiles repository"
    return 1
  fi

  head_after="$(repo_git rev-parse HEAD)" || return 1
  if [[ "$head_before" != "$head_after" ]] && ! repo_git diff --quiet "$head_before" "$head_after" -- dot; then
    print_info "The pull changed dot/; restarting with the new version"
    DOT_VERBOSE="$DOT_VERBOSE" DOT_YES="$DOT_YES" \
      exec "$DOT_ROOT/bin/dot" update --no-pull "$@"
  fi
}
