# Fish

[config.fish](../../stow/fish/.config/fish/config.fish) stays small.
[conf.d/](../../stow/fish/.config/fish/conf.d/) owns environment, paths, and tool activation.
Edit those source files rather than their linked HOME paths.

## Set up the shell

Dot init installs Fish, adds it to /etc/shells if needed, and sets it as the login shell.
Restart the terminal afterward. Keep the repository on PATH with fish_add_path ~/dots.
Mise activates automatically. Use mise use inside a project for project runtimes.
Node.js remains managed by [pnpm](pnpm.md), not mise.

## Manage plugins

Declare Fisher plugins in [fish_plugins](../../stow/fish/.config/fish/fish_plugins).
Fisher installs them under ~/.local/share/fisher, outside the repository.
Dot init and dot stow install missing plugins. Dot update updates them.
Dot doctor checks installation.

Managed completions live in the tracked completions directory.
OrbStack owns its generated Docker, kubectl, and orbctl completions in HOME.
Do not commit generated completions, plugin files, or fish_variables.
