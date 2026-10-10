# shellcheck shell=bash
# help: the top-level command list.

cmd_help() {
  cat <<EOF
${BOLD}dot${RESET} $DOT_VERSION - dotfiles management

${BOLD}USAGE${RESET}
  dot [OPTIONS] COMMAND [ARGS]

${BOLD}SETUP${RESET}
  init           Install packages, link dotfiles, and set up runtimes
  update         Pull changes, offer upgrades, and relink
  stow           Link home/ into ~ and install plugin dependencies
  unstow         Remove the links

${BOLD}DIAGNOSTICS${RESET}
  doctor         Check the whole setup
  info           Show paths, runtime versions, and repo status
  secret-scan    Scan tracked and unignored files for secrets
  lint           Run shellcheck and shfmt on dot itself

${BOLD}MANAGE${RESET}
  package        Homebrew packages ('dot package help')
  config         Machine-local preferences ('dot config help')
  submodule      Private submodules: status, update
  hooks          Point Git at .githooks
  git-identity   Create or update ~/.gitconfig.local

${BOLD}OPTIONS${RESET}
  -v, --verbose  Print extra diagnostics
  -y, --yes      Answer yes to confirmations
  -h, --help     Show this help
  --version      Show the version
EOF
}
