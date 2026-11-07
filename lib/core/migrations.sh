# shellcheck shell=bash
# One-time cleanups for older setups. Delete an entry once every machine has run it.

# OpenCode used to be a pnpm global; it now comes from Homebrew. Check pnpm's
# global list, not PATH: Homebrew's opencode can shadow the leftover pnpm copy.
migrate_pnpm_opencode() {
  command_exists pnpm || return 0
  pnpm list -g --depth 0 --parseable @opencode/cli 2>/dev/null \
    | grep -q '/node_modules/@opencode/cli$' || return 0

  print_info "Removing the legacy pnpm OpenCode install"
  if command_exists sfw && sfw pnpm remove -g @opencode/cli; then
    hash -r
  else
    print_warning "Could not remove it; run 'sfw pnpm remove -g @opencode/cli'"
  fi
}
