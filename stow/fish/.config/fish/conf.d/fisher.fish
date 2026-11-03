# Fisher installs plugins here instead of ~/.config/fish, which is folded into
# the dots repo. The plugin list is the tracked fish_plugins file; dot installs
# missing plugins during init/stow and updates them during update.
set -g fisher_path (set -q XDG_DATA_HOME; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/fisher

contains -- $fisher_path/functions $fish_function_path
or set fish_function_path $fish_function_path[1] $fisher_path/functions $fish_function_path[2..-1]
contains -- $fisher_path/completions $fish_complete_path
or set fish_complete_path $fish_complete_path[1] $fisher_path/completions $fish_complete_path[2..-1]

for file in $fisher_path/conf.d/*.fish
    source $file
end
