# shellcheck shell=bash
# dot benchmark-shell: time Fish startup with Fish's own `time` keyword, so no
# other runtime is needed. Runs Fish with the real configuration in HOME.

readonly BENCHMARK_SHELL_DEFAULT_RUNS=10
readonly BENCHMARK_SHELL_MAX_RUNS=100

cmd_benchmark_shell_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot benchmark-shell [-r|--runs N] [--show-runs]

Start Fish N times as an interactive shell (fish -i -c exit) and as a
non-interactive shell (fish -c exit). Print the fastest, median, mean, and
slowest startup in milliseconds. One untimed run first warms caches.

${BOLD}OPTIONS${RESET}
  -r, --runs N   Timed runs per mode, 1-$BENCHMARK_SHELL_MAX_RUNS (default $BENCHMARK_SHELL_DEFAULT_RUNS)
  --show-runs    Print every run's time

For a per-command breakdown of one interactive startup, run:
  fish --profile-startup /tmp/fish-startup.txt -i -c exit
EOF
}

# fish_time_report_ms: read Fish `time` reports on stdin and print each
# "Executed in" duration in milliseconds, one per line.
fish_time_report_ms() {
  awk '
    $1 == "Executed" && $2 == "in" {
      value = $3
      if ($4 == "micros") value = value / 1000
      else if ($4 == "secs") value = value * 1000
      else if ($4 == "mins") value = value * 60000
      else if ($4 != "millis") exit 1
      printf "%.2f\n", value
    }
  '
}

# fish_startup_times_ms RUNS [FISH_FLAG...]: start Fish once untimed, then RUNS
# times under `time`, and print each startup in milliseconds. The outer Fish
# runs with --no-config, so only the measured shells load the configuration.
fish_startup_times_ms() {
  local runs="$1"
  shift
  # shellcheck disable=SC2016 # Fish expands these, not Bash
  fish --no-config -c '
    fish $argv[2..] -c exit >/dev/null 2>&1
    for run in (seq $argv[1])
      time fish $argv[2..] -c exit >/dev/null 2>&1
    end
  ' "$runs" "$@" 2>&1 >/dev/null | fish_time_report_ms
}

# startup_time_summary: read milliseconds on stdin and print
# "FASTEST MEDIAN MEAN SLOWEST", each with one decimal.
startup_time_summary() {
  sort -n | awk '
    { times[NR] = $1; total += $1 }
    END {
      if (NR == 0) exit 1
      if (NR % 2) median = times[(NR + 1) / 2]
      else median = (times[NR / 2] + times[NR / 2 + 1]) / 2
      printf "%.1f %.1f %.1f %.1f\n", times[1], median, total / NR, times[NR]
    }
  '
}

cmd_benchmark_shell() {
  local runs="$BENCHMARK_SHELL_DEFAULT_RUNS" show_runs=false
  local mode label times summary fastest median mean slowest

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -r | --runs)
        if [[ "$#" -lt 2 ]]; then
          print_error "Option $1 needs a number of runs"
          return 1
        fi
        runs="$2"
        shift
        ;;
      --runs=*) runs="${1#*=}" ;;
      --show-runs) show_runs=true ;;
      -v | --verbose) DOT_VERBOSE=true ;;
      -y | --yes) DOT_YES=true ;;
      *)
        print_error "Unknown benchmark-shell option: $1"
        print_info "Run 'dot benchmark-shell --help' for usage"
        return 1
        ;;
    esac
    shift
  done
  if [[ ! "$runs" =~ ^[0-9]+$ ]] || [[ "$runs" -lt 1 || "$runs" -gt "$BENCHMARK_SHELL_MAX_RUNS" ]]; then
    print_error "Runs must be a number from 1 to $BENCHMARK_SHELL_MAX_RUNS, not '$runs'"
    return 1
  fi
  command_exists fish || {
    print_error "Fish is missing; run 'dot init --only packages'"
    return 1
  }

  print_header "Benchmarking Fish startup ($runs runs per mode)"
  printf '  %-16s %9s %9s %9s %9s\n' Mode Fastest Median Mean Slowest
  for mode in interactive non-interactive; do
    label="$mode"
    if [[ "$mode" == interactive ]]; then
      times="$(fish_startup_times_ms "$runs" -i)" || times=""
    else
      times="$(fish_startup_times_ms "$runs")" || times=""
    fi
    if ! summary="$(startup_time_summary <<<"$times")"; then
      print_error "Could not time $label Fish startup"
      return 1
    fi
    read -r fastest median mean slowest <<<"$summary"
    printf '  %-16s %6s ms %6s ms %6s ms %6s ms\n' "$label" "$fastest" "$median" "$mean" "$slowest"
    if [[ "$show_runs" == true ]]; then
      printf '    %s\n' "$(paste -sd ' ' - <<<"$times") (ms)"
    fi
  done
}
