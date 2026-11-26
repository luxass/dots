# shellcheck shell=bash
# Component runner: walks the registry (component-registry.sh), runs one phase
# for each selected component, then prints a summary table.
#   install  dot init     stops at the first failed required component
#   update   dot update   same; components without an update step run install
#   check    dot doctor   runs every check; failed required checks are critical

# true: print the plan (which function each component would run) and run nothing.
DOT_DRY_RUN=false

# One entry per component that ran. Parallel arrays filled by record_component_result.
DOT_RESULT_NAMES=()
DOT_RESULT_STATUSES=()
DOT_RESULT_SECONDS=()

record_component_result() {
  DOT_RESULT_NAMES+=("$1")
  DOT_RESULT_STATUSES+=("$2")
  DOT_RESULT_SECONDS+=("$3")
}

# run_component_phase install|update|check: run one phase for every selected
# component. Returns 1 when a required component failed. install and update
# stop there; check runs every component first.
run_component_phase() {
  local phase="$1" name phase_function started warnings_before status
  local selected=() required_failed=false

  case "$phase" in
    install | update | check) ;;
    *)
      print_error "Unknown component phase '$phase': expected install, update, or check"
      return 1
      ;;
  esac

  DOT_RESULT_NAMES=()
  DOT_RESULT_STATUSES=()
  DOT_RESULT_SECONDS=()

  # The ${a[@]+...} form keeps Bash 3.2 happy with empty arrays under set -u.
  for name in ${DOT_COMPONENTS[@]+"${DOT_COMPONENTS[@]}"}; do
    if component_is_selected "$name"; then
      selected+=("$name")
    fi
  done
  if [[ "${#selected[@]}" -eq 0 ]]; then
    print_warning "No components selected"
    return 0
  fi

  STEP_CURRENT=0
  STEP_TOTAL="${#selected[@]}"
  for name in "${selected[@]}"; do
    print_step "$(component_title "$name") ${CYAN}($name)${RESET}"

    if ! phase_function="$(component_phase_function "$name" "$phase")"; then
      print_info "No $phase step"
      record_component_result "$name" none 0
      continue
    fi
    if [[ "$DOT_DRY_RUN" == true ]]; then
      print_info "Would run $phase_function"
      record_component_result "$name" planned 0
      continue
    fi

    started="$SECONDS"
    warnings_before="$DOT_WARNING_COUNT"
    if "$phase_function"; then
      status=ok
      if [[ "$DOT_WARNING_COUNT" -gt "$warnings_before" ]]; then
        status=warnings
      fi
    else
      status=failed
    fi
    record_component_result "$name" "$status" "$((SECONDS - started))"

    if [[ "$status" == failed ]] && component_is_required "$name"; then
      required_failed=true
      if [[ "$phase" != check ]]; then
        print_error "Required component $name failed; stopping"
        break
      fi
    fi
  done

  print_component_summary "$phase"
  [[ "$required_failed" == false ]]
}

# print_component_summary PHASE: one line per component that ran: status,
# name, requirement, and seconds.
print_component_summary() {
  local phase="$1" index name status mark requirement

  print_header "Summary ($phase)"
  [[ "${#DOT_RESULT_NAMES[@]}" -gt 0 ]] || return 0

  for index in "${!DOT_RESULT_NAMES[@]}"; do
    name="${DOT_RESULT_NAMES[$index]}"
    status="${DOT_RESULT_STATUSES[$index]}"
    case "$status" in
      ok) mark="${GREEN}✓${RESET}" ;;
      warnings) mark="${YELLOW}⚠${RESET}" ;;
      failed) mark="${RED}✗${RESET}" ;;
      *) mark="${CYAN}·${RESET}" ;;
    esac
    requirement=optional
    if component_is_required "$name"; then
      requirement=required
    fi
    printf '  %s %-10s %-9s %-8s %3ss\n' "$mark" "$name" "$status" "$requirement" "${DOT_RESULT_SECONDS[$index]}"
  done
}
