# shellcheck shell=bash
# dot doctor: run every component's check step and report problems. Read-only.

cmd_doctor_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot doctor [--only LIST] [--skip LIST]

Check every component on this Mac. Exits 1 when a required component's check
fails. Optional components only report.
EOF
}

cmd_doctor() {
  DOT_OPTION_ONLY=""
  DOT_OPTION_SKIP=""
  while [[ "$#" -gt 0 ]]; do
    parse_component_option "$@" || return 1
    if [[ "$DOT_OPTION_SHIFT" -gt 0 ]]; then
      shift "$DOT_OPTION_SHIFT"
      continue
    fi
    print_error "Unknown doctor option: $1"
    print_info "Run 'dot doctor --help' for usage"
    return 1
  done
  # doctor never changes anything, so --dry-run is the same as a normal run.
  DOT_DRY_RUN=false
  select_components "$DOT_OPTION_ONLY" "$DOT_OPTION_SKIP" || return 1

  print_header "Running diagnostics"
  if command_exists dot; then
    print_success "dot is on PATH"
  else
    print_warning "dot is not on PATH; run '$DOT_ROOT/bin/dot link'"
  fi

  if run_component_phase check; then
    print_header "All critical checks passed"
  else
    print_header "Critical checks failed (required components marked ✗ above)"
    return 1
  fi
}
