set -gx BUN_INSTALL "$HOME/.bun"

if test -d "$BUN_INSTALL/bin"
    fish_add_path "$BUN_INSTALL/bin"
end
