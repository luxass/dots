fish_add_path "$HOME/.local/bin"
fish_add_path "$GOPATH/bin"
fish_add_path "$PNPM_HOME"
fish_add_path "$PNPM_HOME/bin"

if test -d "$HOME/.cargo/bin"
    fish_add_path "$HOME/.cargo/bin"
end

if test -d "$HOME/.bun/bin"
    fish_add_path "$HOME/.bun/bin"
end
