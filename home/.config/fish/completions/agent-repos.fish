function __agent_repos_targets
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$root"; and test -f "$root/.agent-repos"
        awk -F '\t' 'NF >= 5 && $1 !~ /^#/ && $1 != "" { print $2 "\t" $1 " " $3; print $3 "\t" $1 " " $2 }' "$root/.agent-repos"
    end
end

complete -c agent-repos -f
complete -c agent-repos -n __fish_use_subcommand -a init -d 'Prepare repository for agent reference repos'
complete -c agent-repos -n __fish_use_subcommand -a add -d 'Add a reference repository'
complete -c agent-repos -n __fish_use_subcommand -a update -d 'Update reference repositories'
complete -c agent-repos -n __fish_use_subcommand -a pull -d 'Alias for update'
complete -c agent-repos -n __fish_use_subcommand -a list -d 'List reference repositories'
complete -c agent-repos -n __fish_use_subcommand -a ls -d 'Alias for list'
complete -c agent-repos -n __fish_use_subcommand -a remove -d 'Remove a manifest entry'
complete -c agent-repos -n __fish_use_subcommand -a rm -d 'Alias for remove'
complete -c agent-repos -n __fish_use_subcommand -a instructions -d 'Add or refresh AGENTS.md guidance'
complete -c agent-repos -n __fish_use_subcommand -a help -d 'Show help'

complete -c agent-repos -n '__fish_seen_subcommand_from init add' -l mode -xa 'clone subtree' -d 'Reference repository mode'
complete -c agent-repos -n '__fish_seen_subcommand_from init' -l instructions -d 'Write AGENTS.md instructions'
complete -c agent-repos -n '__fish_seen_subcommand_from init instructions' -l file -r -d 'Agent instructions file'

complete -c agent-repos -n '__fish_seen_subcommand_from add' -s n -l name -r -d 'Logical repo name'
complete -c agent-repos -n '__fish_seen_subcommand_from add' -s p -l path -r -d 'Target path'
complete -c agent-repos -n '__fish_seen_subcommand_from add' -s b -l branch -r -d 'Branch or ref'
complete -c agent-repos -n '__fish_seen_subcommand_from add update pull remove rm' -s y -l yes -d 'Confirm non-interactively'

complete -c agent-repos -n '__fish_seen_subcommand_from update pull remove rm' -a '(__agent_repos_targets)' -d 'Reference repo'
complete -c agent-repos -n '__fish_seen_subcommand_from update pull' -s a -l all -d 'Update all entries'
complete -c agent-repos -n '__fish_seen_subcommand_from remove rm' -l delete -d 'Delete clone directory too'
