# shellcheck shell=bash
# dot init: run every component's install step (dot/lib/components/).

cmd_init_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot init [--only LIST] [--skip LIST] [--dry-run]

Install everything this Mac needs, one component at a time (list them with
'dot components'). Safe to run again: each step skips what is already
installed. A failed required component stops the run.

${BOLD}OPTIONS${RESET}
  --only LIST   Run only these components (comma-separated)
  --skip LIST   Skip these components (comma-separated)
  --dry-run     Print the plan and change nothing
EOF
}

cmd_init() {
  DOT_OPTION_ONLY=""
  DOT_OPTION_SKIP=""
  while [[ "$#" -gt 0 ]]; do
    parse_component_option "$@" || return 1
    if [[ "$DOT_OPTION_SHIFT" -gt 0 ]]; then
      shift "$DOT_OPTION_SHIFT"
      continue
    fi
    print_error "Unknown init option: $1"
    print_info "Run 'dot init --help' for usage"
    return 1
  done
  select_components "$DOT_OPTION_ONLY" "$DOT_OPTION_SKIP" || return 1

  if [[ "$DOT_DRY_RUN" == true ]]; then
    print_header "Setting up dotfiles (dry run: nothing changes)"
  else
    acquire_run_lock || return 1
    print_header "Setting up dotfiles"
  fi

  if ! run_component_phase install; then
    print_header "Setup stopped at a failed required component"
    return 1
  fi
  if [[ "$DOT_DRY_RUN" == true ]]; then
    print_header "Dry run complete (nothing changed)"
  else
    print_header "Setup complete"
  fi
}
