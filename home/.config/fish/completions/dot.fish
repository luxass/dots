complete -c dot -f
complete -c dot -s v -l verbose -d 'Print extra diagnostics'
complete -c dot -s y -l yes -d 'Answer yes to confirmations'
complete -c dot -s h -l help -d 'Show help'
complete -c dot -l version -d 'Show version'

complete -c dot -n __fish_use_subcommand -a init -d 'Install packages, link dotfiles, set up runtimes'
complete -c dot -n __fish_use_subcommand -a update -d 'Pull changes, offer upgrades, relink'
complete -c dot -n __fish_use_subcommand -a stow -d 'Link home/ and install plugin dependencies'
complete -c dot -n __fish_use_subcommand -a unstow -d 'Remove the links'
complete -c dot -n __fish_use_subcommand -a doctor -d 'Check the whole setup'
complete -c dot -n __fish_use_subcommand -a info -d 'Show paths, runtimes, and repo status'
complete -c dot -n __fish_use_subcommand -a secret-scan -d 'Scan for secrets'
complete -c dot -n __fish_use_subcommand -a lint -d 'Run shellcheck and shfmt on dot'
complete -c dot -n __fish_use_subcommand -a package -d 'Homebrew packages'
complete -c dot -n __fish_use_subcommand -a skills -d 'Shared Agent Skills'
complete -c dot -n __fish_use_subcommand -a config -d 'Machine-local preferences'
complete -c dot -n __fish_use_subcommand -a submodule -d 'Private submodules'
complete -c dot -n __fish_use_subcommand -a hooks -d 'Point Git at .githooks'
complete -c dot -n __fish_use_subcommand -a git-identity -d 'Create or update ~/.gitconfig.local'
complete -c dot -n __fish_use_subcommand -a cliproxyapi -d 'Run CLIProxyAPI in the foreground'
complete -c dot -n __fish_use_subcommand -a help -d 'Show help'

set -l package_cmds list check add remove unmanaged update help
complete -c dot -n "__fish_seen_subcommand_from package; and not __fish_seen_subcommand_from $package_cmds" -a "$package_cmds"
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from list' -a 'base fonts work personal'
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from add remove' -s g -l group -x -a 'base fonts work personal' -d 'Bundle group'
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from add' -l cask -d 'Add a cask'
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from add' -l formula -d 'Add a formula'

complete -c dot -n '__fish_seen_subcommand_from skills; and not __fish_seen_subcommand_from add list help' -a 'add list help'
complete -c dot -n '__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from list get set unset reset path help' -a 'list get set unset reset path help'
complete -c dot -n '__fish_seen_subcommand_from config; and __fish_seen_subcommand_from get set unset' -a 'packages.brew.fonts.enabled packages.brew.work.enabled packages.brew.personal.enabled'
complete -c dot -n '__fish_seen_subcommand_from submodule; and not __fish_seen_subcommand_from status update help' -a 'status update help'
