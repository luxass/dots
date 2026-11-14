# Fish

[config.fish](../../stow/fish/.config/fish/config.fish) stays small.
[conf.d/](../../stow/fish/.config/fish/conf.d/) owns environment, paths, and tool activation.
Edit those source files rather than their linked HOME paths.

## Set up the shell

Dot init installs Fish, adds it to /etc/shells if needed, and sets it as the login shell.
Restart the terminal afterward. Keep the repository on PATH with fish_add_path ~/dots.
Mise activates in all shells so scripts can use project runtimes.
[conf.d/mise.fish](../../stow/fish/.config/fish/conf.d/mise.fish) disables Homebrew's
vendor activation to avoid running mise twice. Use mise use inside a project for project runtimes.
Node.js remains managed by [pnpm](pnpm.md), not mise.

Prompt setup, tool hooks, aliases, generated completions, and plugin startup scripts
load only in interactive shells. Environment variables, runtime paths, and Fisher
function paths remain available in noninteractive shells.

Starship's left and right prompt renderers use a process-local Git override:
`core.fsmonitor=false`. This lets Starship use its internal gitoxide status engine
instead of external Git when filesystem monitoring is enabled. The wrapper appends
the override to existing Git environment settings. Normal Git commands keep their
configured filesystem monitoring, and Starship keeps its status indicators.

## Manage plugins

Declare Fisher plugins in [fish_plugins](../../stow/fish/.config/fish/fish_plugins).
Fisher installs them under ~/.local/share/fisher, outside the repository.
Dot init and dot stow install missing plugins. Dot update updates them.
Dot doctor checks installation.

Managed completions live in the tracked completions directory.
OrbStack owns its generated Docker, kubectl, and orbctl completions in HOME.
Do not commit generated completions, plugin files, or fish_variables.
