# shellcheck shell=bash
# dot hooks: point Git at .githooks and configure the repository filters.

cmd_hooks_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot hooks

Set core.hooksPath to .githooks and configure the Pi settings and skills
lock clean filters. The git component runs the same step.
EOF
}

cmd_hooks() {
  no_args "$@" || return 1
  git_install_hooks
}
