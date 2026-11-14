# Disable Homebrew's vendor activation; this file owns mise setup in all shells.
set -gx MISE_FISH_AUTO_ACTIVATE 0

if command -q mise
    mise activate fish | source
end
