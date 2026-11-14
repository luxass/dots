if status is-interactive; and command -q direnv
    direnv hook fish | source
end
