# shellcheck shell=bash
# dot components: list the registry (dot/lib/component-registry.sh).

cmd_components_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot components [--names]

List every component in run order: whether it is required, and whether it
has its own update step (otherwise update runs install).
--names prints only the names, for completions.
EOF
}

cmd_components() {
  local names_only=false name requirement update_step

  case "${1:-}" in
    '') ;;
    --names) names_only=true ;;
    *)
      print_error "Unknown components option: $1"
      return 1
      ;;
  esac

  if [[ "$names_only" == true ]]; then
    printf '%s\n' "${DOT_COMPONENTS[@]}"
    return 0
  fi

  printf '%s%-10s %-9s %-8s %s%s\n' "$BOLD" COMPONENT REQUIRED UPDATE TITLE "$RESET"
  for name in "${DOT_COMPONENTS[@]}"; do
    requirement=optional
    if component_is_required "$name"; then
      requirement=required
    fi
    update_step=install
    if declare -F "component_${name}_update" >/dev/null; then
      update_step=own
    fi
    printf '%-10s %-9s %-8s %s\n' "$name" "$requirement" "$update_step" "$(component_title "$name")"
  done
}
