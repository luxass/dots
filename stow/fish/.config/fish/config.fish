# Keep config.fish small; Fish automatically loads conf.d/*.fish.
set fish_greeting

set -gx EDITOR nvim
set -gx MANPAGER "less -X"

# The CLI inside a Rex pane must match its server. Keep this after conf.d.
if set -q REX_BIN_DIR; and test -x "$REX_BIN_DIR/rex"
    fish_add_path --path --prepend --move "$REX_BIN_DIR"
end

