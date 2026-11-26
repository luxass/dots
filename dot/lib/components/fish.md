# Fish

[config.fish](../../../stow/fish/.config/fish/config.fish) stays small.
[conf.d/](../../../stow/fish/.config/fish/conf.d/) owns environment, paths, and tool activation.
Edit those source files rather than their linked HOME paths.

## Set up the shell

Dot init installs Fish, adds it to /etc/shells if needed, and sets it as the login shell.
Restart the terminal afterward. Put dot on PATH once with ~/dots/dot/bin/dot link.
It links ~/.local/bin/dot, and [conf.d/paths.fish](../../../stow/fish/.config/fish/conf.d/paths.fish)
adds ~/.local/bin to PATH.
Mise activates in all shells so scripts can use project runtimes.
[conf.d/mise.fish](../../../stow/fish/.config/fish/conf.d/mise.fish) disables Homebrew's
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

## Measure startup

Run dot benchmark-shell after changing conf.d or adding a plugin. It starts Fish
ten times as an interactive shell and ten times as a noninteractive shell, then
prints the fastest, median, mean, and slowest startup. Use --runs to change the
count. If a change makes startup slower, find the slow commands with
fish --profile-startup /tmp/fish-startup.txt -i -c exit.

## Manage plugins

Declare Fisher plugins in [fish_plugins](../../../stow/fish/.config/fish/fish_plugins).
Fisher installs them under ~/.local/share/fisher, outside the repository.
Dot init installs missing plugins. After editing the list, run dot init --only fish.
Dot update updates them and removes unlisted plugins.
Dot doctor checks installation.

Managed completions live in the tracked completions directory.
OrbStack owns its generated Docker, kubectl, and orbctl completions in HOME.
Do not commit generated completions, plugin files, or fish_variables.
