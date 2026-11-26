# shellcheck shell=bash
# dot secret-scan: scan tracked and unignored files for secrets.

cmd_secret_scan_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot secret-scan

Scan tracked and unignored files for possible secrets without printing their
values. Exits 1 for findings and 2 when the scan cannot complete. Reviewed
exceptions live in .secret-scan-allowlist.
EOF
}

cmd_secret_scan() {
  no_args "$@" || return 1
  if git_secret_scan; then
    print_success "Secret scan passed"
  else
    if [[ "$?" -eq 1 ]]; then
      print_error "Possible secrets found"
      return 1
    fi
    print_error "Secret scan did not complete"
    return 2
  fi
}
