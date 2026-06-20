if command -q eza
    alias ls='eza --group-directories-first'
    alias ll='eza --long --group --git --group-directories-first'
    alias la='eza --all --group-directories-first'
    alias lla='eza --long --all --group --git --group-directories-first'
    alias tree='eza --tree --group-directories-first'
end
