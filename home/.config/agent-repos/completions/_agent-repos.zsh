#compdef agent-repos

_agent_repos() {
  local -a commands modes
  commands=(
    'init:prepare repository metadata and ignores'
    'add:add a clone or subtree reference repository'
    'update:update one or all reference repositories'
    'list:list reference repositories'
    'remove:remove a manifest entry'
    'instructions:add or refresh AGENTS.md guidance'
    'completions:print shell completions'
    'help:show help'
  )
  modes=('clone:local ignored clone' 'subtree:tracked git subtree')

  _arguments -C \
    '1:command:->command' \
    '*::arg:->args'

  case $state in
    command)
      _describe 'command' commands
      ;;
    args)
      case $words[2] in
        init)
          _arguments \
            '--mode[select reference mode]:mode:((clone\:local\ ignored\ clone subtree\:tracked\ git\ subtree))' \
            '--instructions[write AGENTS.md instructions]' \
            '--file[agent instructions file]:file:_files'
          ;;
        add)
          _arguments \
            '--mode[select reference mode]:mode:((clone\:local\ ignored\ clone subtree\:tracked\ git\ subtree))' \
            '(-n --name)'{-n,--name}'[logical repo name]:name:' \
            '(-p --path)'{-p,--path}'[target path]:path:_files -/' \
            '(-b --branch)'{-b,--branch}'[branch or ref]:branch:' \
            '(-y --yes)'{-y,--yes}'[confirm subtree operation]' \
            '1:url:'
          ;;
        update)
          _arguments \
            '(-a --all)'{-a,--all}'[update all entries]' \
            '(-y --yes)'{-y,--yes}'[confirm subtree operation]' \
            '1:name or path:'
          ;;
        remove)
          _arguments \
            '--delete[delete clone directory too]' \
            '(-y --yes)'{-y,--yes}'[confirm deletion]' \
            '1:name or path:'
          ;;
        instructions)
          _arguments '--file[agent instructions file]:file:_files'
          ;;
        completions)
          _arguments '1:shell:(zsh)'
          ;;
      esac
      ;;
  esac
}

compdef _agent_repos agent-repos
