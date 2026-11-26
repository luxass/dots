complete -c dot -f
complete -c dot -s v -l verbose -d 'Print extra diagnostics'
complete -c dot -s y -l yes -d 'Answer yes to confirmations'
complete -c dot -s h -l help -d 'Show help'
complete -c dot -l version -d 'Show version'

set -l dot_commands init update doctor components info package check-packages retry-failed stow unstow hooks secret-scan lint benchmark-shell link unlink edit help
complete -c dot -n __fish_use_subcommand -a init -d 'Install everything (every component install step)'
complete -c dot -n __fish_use_subcommand -a update -d 'Pull, then update every component'
complete -c dot -n __fish_use_subcommand -a doctor -d 'Check every component'
complete -c dot -n __fish_use_subcommand -a components -d 'List components in run order'
complete -c dot -n __fish_use_subcommand -a info -d 'Show paths, runtimes, and repo status'
complete -c dot -n __fish_use_subcommand -a package -d 'List, add, remove, or upgrade packages'
complete -c dot -n __fish_use_subcommand -a check-packages -d 'Report missing packages'
complete -c dot -n __fish_use_subcommand -a retry-failed -d 'Retry packages that failed during init'
complete -c dot -n __fish_use_subcommand -a stow -d 'Re-link the Stow packages'
complete -c dot -n __fish_use_subcommand -a unstow -d 'Remove the Stow and skills links'
complete -c dot -n __fish_use_subcommand -a hooks -d 'Point Git at .githooks and set up repo filters'
complete -c dot -n __fish_use_subcommand -a secret-scan -d 'Scan for secrets'
complete -c dot -n __fish_use_subcommand -a lint -d 'Run shellcheck, shfmt, and bats'
complete -c dot -n __fish_use_subcommand -a benchmark-shell -d 'Time Fish startup'
complete -c dot -n __fish_use_subcommand -a link -d 'Link ~/.local/bin/dot'
complete -c dot -n __fish_use_subcommand -a unlink -d 'Remove ~/.local/bin/dot'
complete -c dot -n __fish_use_subcommand -a edit -d 'Open the repository in $EDITOR'
complete -c dot -n __fish_use_subcommand -a help -d 'Show help'
complete -c dot -n '__fish_seen_subcommand_from help' -a "$dot_commands"

# init, update, doctor: component selection
complete -c dot -n '__fish_seen_subcommand_from init update doctor' -l only -x -a '(dot components --names 2>/dev/null)' -d 'Only these components (comma-separated)'
complete -c dot -n '__fish_seen_subcommand_from init update doctor' -l skip -x -a '(dot components --names 2>/dev/null)' -d 'Skip these components (comma-separated)'
complete -c dot -n '__fish_seen_subcommand_from init update' -l dry-run -d 'Print the plan and change nothing'
complete -c dot -n '__fish_seen_subcommand_from update' -l no-pull -d 'Skip the git pull'
complete -c dot -n '__fish_seen_subcommand_from components' -l names -d 'Print only component names'
complete -c dot -n '__fish_seen_subcommand_from benchmark-shell' -s r -l runs -x -a '5 10 20 50' -d 'Timed runs per mode'
complete -c dot -n '__fish_seen_subcommand_from benchmark-shell' -l show-runs -d 'Print every run'

# package
set -l package_commands list add remove update help
complete -c dot -n "__fish_seen_subcommand_from package; and not __fish_seen_subcommand_from $package_commands" -a list -d 'List packages (default)'
complete -c dot -n "__fish_seen_subcommand_from package; and not __fish_seen_subcommand_from $package_commands" -a add -d 'Install a package and add it to a list'
complete -c dot -n "__fish_seen_subcommand_from package; and not __fish_seen_subcommand_from $package_commands" -a remove -d 'Remove a package from the lists'
complete -c dot -n "__fish_seen_subcommand_from package; and not __fish_seen_subcommand_from $package_commands" -a update -d 'Upgrade packages'
complete -c dot -n "__fish_seen_subcommand_from package; and not __fish_seen_subcommand_from $package_commands" -a help -d 'Show package help'
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from add' -a 'brew cask' -d 'Package type'
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from add remove update list' -a 'base work' -d 'Package list'
complete -c dot -n '__fish_seen_subcommand_from package; and __fish_seen_subcommand_from remove update list' -a all -d 'Every list'
