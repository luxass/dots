# dots

Personal macOS dotfiles managed with GNU Stow and a small `dot` CLI.

## Overview

This repository contains a reproducible macOS development setup. Files under
`home/` mirror `$HOME`, packages live in `packages/`, and `dot` handles setup,
maintenance, package checks, symlinks, and local-only identity configuration.

The repo is intentionally small: Fish, Git, Ghostty, Homebrew packages,
and JavaScript runtime policy. It does not try to manage Linux, Neovim, tmux,
or other configs that are not currently wanted.

## Key Features

- One-command setup through `./dot init`
- GNU Stow symlink management from `home/` to `$HOME`
- Homebrew bundles with optional per-machine groups (fonts, work, personal)
- Homebrew-installed mise with Fish activation for project and language runtimes
- Standalone pnpm 12 with pnpm-managed Node.js and npm 12
- Managed pnpm global tools, including Socket Firewall (`sfw`)
- Public-safe Git config with private identity in `~/.gitconfig.local`
- Tracked pre-push hook that runs secret scanning before publishing
- npm, pnpm, and Bun install policy for build approvals and release age checks
- Diagnostics for required tools, package state, managed links, and secrets
- shellcheck and shfmt linting for the `dot` CLI itself

## Quick Start

```sh
git clone git@github.com:luxass/dots.git ~/dots
cd ~/dots
./dot init
```

Run `dot` directly from the repository by keeping `~/dots` on your PATH.
If needed, run `fish_add_path ~/dots` once in Fish. Setup does not create a
second CLI link in `~/.local/bin/`.

## Repository Structure

```text
~/dots/
├── dot                 # CLI entrypoint: loads lib/ and runs main
├── lib/
│   ├── core/           # Output, prompts, paths, preferences, links, dispatch
│   ├── features/       # One file per managed thing, with setup and check hooks
│   └── commands/       # The CLI surface: cmd_* functions
├── home/               # Files stowed into $HOME
│   ├── .codex/         # Ignore policy only; Codex config stays local
│   ├── .config/
│   │   ├── fish/
│   │   ├── ghostty/
│   │   ├── opencode/
│   │   └── pnpm/
│   ├── .gitconfig      # Public Git settings; includes ~/.gitconfig.local
│   ├── .npmrc          # Public npm policy only; no auth
│   ├── .pi/            # Lean Pi agent config (settings, keybindings, notes)
│   └── dot-gitignore   # Stowed as ~/.gitignore via --dotfiles
├── packages/
│   ├── bundle          # Base Brewfile
│   ├── bundle.fonts    # Optional font casks
│   ├── bundle.personal # Optional personal-only Brewfile
│   └── bundle.work     # Optional work-only Brewfile
├── AGENTS.md           # Notes for AI/code agents
└── README.md
```

## Commands

Global options: `-v` / `--verbose` prints extra diagnostics, and `-y` /
`--yes` answers yes to confirmations. Without a terminal, prompts use their
default answer.

```sh
dot init             # install packages, link dotfiles, set up runtimes, hooks, identity
dot update           # pull, update Pi, offer pnpm/Homebrew/Pi extension upgrades, relink
dot stow             # link home/ and install plugin dependencies
dot unstow           # remove stowed symlinks
dot doctor           # check every feature, including a secret scan
dot info             # show paths, runtime versions, and git status
dot secret-scan      # scan tracked and unignored files for secrets
dot lint             # run shellcheck and shfmt on dot itself
dot package ...      # Homebrew packages (see below)
dot config ...       # local-only preferences
dot hooks            # point Git at .githooks
dot git-identity     # create or update ~/.gitconfig.local
```

## Package Management

The base package list is `packages/bundle`. Fonts live in
`packages/bundle.fonts`, optional work-only packages in `packages/bundle.work`,
and personal-only packages (installed only on machines that opt in) in
`packages/bundle.personal`. `dot init` prompts for optional groups only when
their local preference is unset. Answers are saved under XDG state so future
runs know whether fonts, work, or personal packages are enabled or
intentionally skipped.

```sh
dot package list [GROUP]                   # every package and whether it is installed
dot package check                          # only what is missing
dot package add NAME [--cask|--formula] [--group GROUP]
dot package remove NAME [--group GROUP]
dot package unmanaged                      # installed but not in any bundle
dot package update [NAME]
```

`add` detects whether NAME is a formula or a cask (pass `--cask` or
`--formula` when it is both), writes the entry with `brew bundle add`, keeps the
Brewfile sorted under its header comment, and installs it when the group is
enabled on this machine. `remove` uses `brew bundle remove` and then offers to
uninstall. `brew bundle install` keeps going past a failed package and reports
it at the end; run `dot package check` afterwards to see what is missing.

## Local-Only Configuration

Machine-local dot preferences are stored outside the repo at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dot/preferences
```

The file uses git-config format. Manage it with:

```sh
dot config list
dot config get packages.brew.fonts.enabled
dot config set packages.brew.fonts.enabled true
dot config unset packages.brew.fonts.enabled
dot config reset
dot config help   # lists every known key
```

Known keys:

```text
packages.brew.fonts.enabled
packages.brew.work.enabled
packages.brew.personal.enabled
```

Unset keys are asked about once, interactively, when `dot` needs them.

## Git Identity

Tracked Git config intentionally excludes name, email, and signing key:

```ini
[include]
  path = ~/.gitconfig.local
```

Create the local identity file with:

```sh
dot git-identity
```

For 1Password SSH signing, enable the 1Password SSH agent and use:

```sh
ssh-add -L
```

Paste the relevant public key when prompted for `user.signingkey`.

## Shell

Fish is the primary interactive shell. The tracked Fish config keeps a small
`config.fish` plus modular `conf.d/*.fish` style:

- `home/.config/fish/config.fish` stays small.
- `home/.config/fish/conf.d/*.fish` contains environment, paths, Homebrew,
  Starship, Zoxide, Direnv, pnpm, Bun, and OrbStack setup.
- `home/.config/fish/completions/` contains Fish completions.
- `home/.config/fish/fish_plugins` lists Fisher plugins (currently
  `jhillyerd/plugin-git`, which adds oh-my-zsh style git abbreviations such as
  `gst` and `gco`). `conf.d/fisher.fish` installs them to
  `~/.local/share/fisher` instead of the folded `~/.config/fish`, so plugin
  files never land in the repo. `dot init` and `dot stow` install missing
  plugins, `dot update` updates them, and `dot doctor` checks them.

`dot init` installs Fish through Homebrew, adds it to `/etc/shells` when needed,
and sets it as the login shell with `chsh`. Restart the terminal after the
change.

## Git Hooks

`dot init` installs repository hooks by setting:

```sh
git config core.hooksPath .githooks
```

The tracked `pre-push` hook runs:

```sh
dot secret-scan
dot lint
```

Run this manually with:

```sh
dot hooks
dot secret-scan
```

## JavaScript Runtime Policy

The repo tracks policy-only configs:

- `home/.npmrc`
- `home/.config/pnpm/config.yaml`
- `home/.bunfig.toml`

These require packages to be at least five days old before installation. npm
and Bun disable lifecycle scripts. pnpm denies unreviewed builds and keeps the
release-age exception for OpenCode plugin packages. Auth tokens must stay out of
the repo.

`mise` is installed from the base Homebrew bundle and activated automatically
in Fish by `home/.config/fish/conf.d/mise.fish`. Use `mise use` in a project to
select a runtime and record its version in `.mise.toml`; no global runtime
versions are pinned by this repo. Node.js remains managed by pnpm in the current
setup, so do not select a competing Node.js version with mise unless you intend
to migrate that ownership.

`dot init` stows these configs before installing standalone pnpm 12, the
pnpm-managed Node.js runtime, npm 12, or pnpm global tools, so package-manager
policy is active during setup.

`dot doctor` verifies that `pnpm`, `node`, `npm`, `pi`, and other managed global
commands resolve from `PNPM_HOME`. It checks that OpenCode is installed through
Homebrew and checks the tracked npm, pnpm, and Bun policy files.

`dot init` installs managed pnpm globals:

```text
sfw
npm 12
pi (@earendil-works/pi-coding-agent)
agent-browser
```

Run `agent-browser install` once to download its Chrome browser. Global CLI
installs go through `sfw pnpm add -g`; the browser download uses the native CLI.

OpenCode v2 is installed from `anomalyco/tap/opencode-v2` through
`packages/bundle`. `dot update` runs Pi's native self-updater, which detects
how Pi was installed and updates it directly. Homebrew upgrades use the usual
package prompt. Before installing the base Brewfile, setup or update removes
any installed formula or cask listed in `BREW_PACKAGE_REPLACEMENTS` in
`lib/core/migrations.sh`. This migrates the old `opencode` formula to `opencode-v2`.
Setup or update also removes the old pnpm-managed OpenCode package if found.

Socket Firewall can be used by prefixing supported package-manager commands:

```sh
sfw pnpm install
sfw npm install
```

## OpenCode

Global OpenCode config is tracked under `home/.config/opencode/` and stowed to
`~/.config/opencode/`.

Tracked files include:

- `opencode.json` for shared global OpenCode settings.
- `plugins/notification.ts`, a small AppleScript notification plugin that fires
  when a session becomes idle.
- `package.json` and `pnpm-lock.yaml` for TypeScript plugin types.

Keep `node_modules/` local-only. It is ignored by Git and by Stow through
`home/.stow-local-ignore`, but can exist in the source tree for editor/type
resolution. `dot stow` and `dot update` install or refresh plugin dependencies
with Socket Firewall (`sfw pnpm install` in `~/.config/opencode/`), and
`dot doctor` verifies that
`@opencode/plugin` is installed. Manual refresh is still available:

```sh
cd ~/.config/opencode
sfw pnpm install
```

Restart OpenCode after changing `opencode.json`, `cli.json`, or plugin files;
running sessions keep the config and plugin code loaded from startup.

OpenCode v2 registers `@luxass/opencode-voice` in the `plugins` array in
`opencode.json`. Use the plural `plugins` key. OpenCode loads the package's
terminal UI component in the local client. Its server component does no work.
Do not also register Voice in `cli.json`. That file is an alternative for
client-only plugins that must stay available with a different server.

Restart OpenCode, then run `/voice setup`. Choose an API profile because local
transcription is currently unsupported on Bun. Keep API keys in environment
variables, not tracked configuration. No private submodule or private
dependency install is needed.

OpenCode's internal npm resolver reads the global npm release-age policy.
Server plugins install and update in its background server. A CLI environment
override alone does not change the policy of an existing server.

Close active OpenCode sessions before this one-time command. It stops the
background server and sets its npm release age to zero for future starts:

```sh
"$(brew --prefix opencode-v2)/bin/opencode" service set env NPM_CONFIG_MIN_RELEASE_AGE 0
```

The setting applies only to OpenCode. Keep `service.json` and `service-*.json`
local because they can also contain passwords and private remote URLs. Git
and Stow ignore them. Reopen OpenCode after the command.

`dot update` offers to run OpenCode's native `plugin update`, like the Pi
extension update step. It uses the managed Homebrew binary and a temporary
`NPM_CONFIG_MIN_RELEASE_AGE=0` override for CLI-only plugin updates. It checks
the server setting first and does not stop or reconfigure a running server.
Local plugin files and pinned package revisions remain unchanged.

`dot stow` and setup also bypass the age filter for the tracked local OpenCode
plugin dependencies. Normal cached-plugin sessions need no special launcher.
Unrelated npm and pnpm installs keep the five-day policy.

Stow backs up leftover links from the retired private plugin setup. Other local
plugins are left alone.

## Pi

Pi (`@earendil-works/pi-coding-agent`, binary `pi`) is installed as a managed
pnpm global. `dot update` runs Pi's native self-updater, then offers to update
installed Pi extension packages after restowing. Both Pi update commands use a
one-command pnpm release-age override; other pnpm installs keep the five-day
age rule.

- The binary is managed through `PNPM_GLOBAL_PACKAGES` in `lib/core/paths.sh` and
  installed with Socket Firewall (`sfw pnpm add -g`).
- Public Pi extensions live under `home/.pi/agent/extensions/` and are stowed
  to `~/.pi/agent/extensions/`. Pi discovers them automatically at startup.
- Auth, trust, sessions, logs, caches, and packages stay local through
  `home/dot-gitignore`. Shared Agent Skills live under `home/.agents/skills/`
  and are not duplicated here.

## Agent Skills

Use the upstream CLI directly. Dot only maintains these links:

```text
~/.agents/skills                         -> home/.agents/skills/
~/.claude/skills                         -> ~/.agents/skills/
~/.agents/.skill-lock.json               -> home/.agents/.skill-lock.json
$XDG_STATE_HOME/skills/.skill-lock.json   -> home/.agents/.skill-lock.json
```

The XDG link uses `~/.local/state` when `XDG_STATE_HOME` is unset. Both global
lock locations point to the same native lock. Stowing never clears its entries.
No alias or wrapper forces global scope.

```sh
sfw pnpx skills add <source> -g --skill <name> -a universal --copy
sfw pnpx skills list -g
sfw pnpx skills update -g
sfw pnpx skills remove <name> -g
```

Global operations change the shared files and lock inside this repo. Review and
commit the Git diff. Commit or stash edits before updating; the upstream CLI
can overwrite skill files and change agent-specific links.

Without `-g`, commands use project scope by default. Interactive `add` can
also ask you to choose a scope. Project installs in other repositories stay
there with their own `skills-lock.json`; they are not redirected into dots.
Running from `~` is a special case: project and global skill directories both
resolve to `~/.agents/skills`, but their lock files are still different. Use
`-g` to manage this shared collection.

### Re-register the existing external imports

The wrapper's project inventory has been removed. Existing skill files are
unchanged, and the native global lock starts empty. Re-add only the selected
imports below to populate their upstream/path/hash metadata. These commands
also refresh their contents from upstream; review the resulting diff.

```sh
sfw pnpx skills add cursor/plugins/pstack/skills -g -a universal --copy \
  --skill architect blast-radius bro how \
  principle-encode-lessons-in-structure principle-guard-the-context-window \
  principle-laziness-protocol principle-minimize-reader-load \
  principle-prove-it-works principle-subtract-before-you-add \
  tdd teach technical-writing typescript-best-practices unslop why

sfw pnpx skills add mattpocock/skills/skills/productivity -g -a universal --copy \
  --skill grill-me grilling
```

Both `tdd` and `teach` come from pstack in `cursor/plugins`, not Matt Pocock.
Do not restore the archived stale inventory; it contains intentionally removed
skills and incorrect upstreams.

Locally maintained/adapted skills remain in `home/.agents/skills/` without
entries in the global lock, so the CLI updater does not manage them. Currently
these are `commit`, `gh-stack`, `github`, `herdr`, `install-anti-slop`,
`tailscale`, and `writing-great-skills`. No separate local inventory is needed.
To keep an imported skill locally, remove its entry from the global lock without
deleting its files before editing it. Native `remove` deletes the files too.

The lock is public tracked content. Keep credentials, private sources, and
machine-local paths out of it. CLI prompt preferences and installation timestamps
may produce normal lock-file churn.

## CLI development

`dot` runs on the Bash 3.2 included with macOS. Runtime code must not depend on
newer Bash features or on Node.js, Python, Ruby, or another separately managed
language runtime.

The `dot` executable sources every file in `lib/core/`, `lib/features/`, and
`lib/commands/`, then calls `main`:

- `lib/core/` holds shared plumbing: output, prompts, paths and versions
  (`paths.sh`), preferences, link helpers, one-time migrations, and dispatch.
- `lib/features/<name>.sh` owns one managed thing (Homebrew, Stow, pnpm, Pi,
  OpenCode, and so on). A feature defines any of the hooks `<name>_prestow`,
  `<name>_poststow`, `<name>_deps`, `<name>_unstow`, and `<name>_check`, and is
  listed in `FEATURES` in `lib/core/paths.sh`. Removing a feature means deleting
  its file and its `FEATURES` entry.
- `lib/commands/` defines the CLI. `dot foo-bar` runs `cmd_foo_bar`.

Conventions: functions return their status explicitly (`|| return 1`) instead of
relying on `set -e`, warnings and errors go to stderr, and colors are off for
non-terminal output or when `NO_COLOR` is set. Style comes from `.editorconfig`
and `.shellcheckrc`; `dot lint` must pass. shellcheck and shfmt are pinned in
the repo's `.mise.toml` rather than the Brewfile, and `dot lint` runs them with
`mise exec`. Run `mise trust` in the repo once per machine. Run `dot doctor` after changes that
affect setup behavior.

## Troubleshooting

Run diagnostics first:

```sh
dot doctor
```

Run the publish safety scan:

```sh
dot secret-scan
```

Repair managed symlinks:

```sh
dot stow
```

`dot doctor` verifies managed symlinks as part of its diagnostics.

Check package drift:

```sh
dot package check
dot package unmanaged
```

`dot stow` moves anything in the way of a managed link to
`${XDG_STATE_HOME:-$HOME/.local/state}/dot/backups/<timestamp>/`.

## Safety

This repository is intended to be public-safe. Do not commit tokens, auth files,
shell histories, generated app state, machine caches, or private identity files.
