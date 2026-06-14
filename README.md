# dots

Personal macOS dotfiles managed with GNU Stow and a small `dot` CLI.

## Overview

This repository contains a reproducible macOS development setup. Files under
`home/` mirror `$HOME`, packages live in `packages/`, and `dot` handles setup,
maintenance, package checks, symlinks, and local-only identity configuration.

The repo is intentionally small: zsh, Git, Ghostty, Homebrew packages, and
JavaScript runtime policy. It does not try to manage Linux, Neovim, tmux, or
other configs that are not currently wanted.

## Key Features

- One-command setup through `./dot init`
- GNU Stow symlink management from `home/` to `$HOME`
- Resilient Homebrew bundle installation with failed package retry files
- pnpm-managed Node.js runtime and npm installation
- Managed pnpm global tools, including Socket Firewall (`sfw`) and Pi (`pi`)
- Public-safe Git config with private identity in `~/.gitconfig.local`
- Tracked pre-push hook that runs secret scanning before publishing
- npm, pnpm, and Bun install policy for disabled scripts and release age checks
- Diagnostics for required tools, package state, managed links, and secrets

## Quick Start

```sh
git clone git@github.com:luxass/dots.git ~/dots
cd ~/dots
./dot init
```

After setup, `dot` is linked into `~/.local/bin/dot`. Restart the shell if the
command is not available immediately.

## Repository Structure

```text
~/dots/
├── dot                 # Main management CLI entrypoint
├── lib/
│   ├── brew.sh         # Homebrew bundle and package commands
│   ├── core.sh         # Shared output, prompts, and generic helpers
│   ├── git.sh          # Git hooks, identity, and secret scanning
│   ├── runtime.sh      # pnpm, Node.js, and global runtime tools
│   └── stow.sh         # GNU Stow links, backups, and dot CLI linking
├── home/               # Files stowed into $HOME
│   ├── .config/
│   │   ├── ghostty/
│   │   └── pnpm/
│   ├── .gitconfig      # Public Git settings; includes ~/.gitconfig.local
│   ├── .npmrc          # Public npm policy only; no auth
│   ├── .zprofile
│   ├── .zshenv
│   ├── .zshrc
│   └── dot-gitignore   # Stowed as ~/.gitignore via --dotfiles
├── packages/
│   ├── bundle          # Base Brewfile
│   ├── bundle.fonts    # Optional font casks
│   └── bundle.work     # Optional work-only Brewfile
├── AGENTS.md           # Notes for AI/code agents
└── README.md
```

## Commands

Global `-v` / `--verbose` prints progress and decision-point diagnostics, for
example `dot --verbose doctor`.

```sh
dot init             # install packages, stow files, create local identity, link dot
dot update           # pull, update Homebrew, install bundle, restow, optionally update Pi
dot doctor           # run diagnostics and secret scan
dot info             # show repo paths, runtime tools, and git status
dot links            # verify every managed symlink
dot hooks            # install repository Git hooks
dot secret-scan      # scan repository for secrets
dot stow             # restow home/
dot unstow           # remove stowed symlinks
dot git-identity     # create or update ~/.gitconfig.local
dot completions      # print zsh completions
dot edit             # open the repo in $EDITOR
```

## Package Management

The base package list is `packages/bundle`. Fonts live in
`packages/bundle.fonts`, and optional work-only packages can be kept in
`packages/bundle.work`. `dot init` asks before installing fonts and work
packages; fonts default to yes, work defaults to no.

```sh
dot package list [base|fonts|work|all]
dot package unmanaged
dot package add NAME [brew|cask|auto] [base|fonts|work]
dot package remove NAME [base|fonts|work|all]
dot package update [NAME|all]
dot check-packages
dot retry-failed
```

Failed package installs are written to `packages/failed_packages_<timestamp>.txt`
and ignored by Git.

## Local-Only Configuration

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

## Git Hooks

`dot init` installs repository hooks by setting:

```sh
git config core.hooksPath .githooks
```

The tracked `pre-push` hook runs:

```sh
dot secret-scan
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

These disable dependency lifecycle scripts and require packages to be at least
five days old before installation. Auth tokens must stay out of the repo.

`dot init` stows these configs before installing the pnpm-managed Node.js
runtime or pnpm global tools, so the package-manager policy is active during
setup.

`dot doctor` verifies that `pnpm`, `node`, and `npm` resolve from `PNPM_HOME`
and checks the tracked pnpm security policy values.

`dot init` also installs managed pnpm globals:

```text
sfw
pi
```

Socket Firewall can be used by prefixing supported package-manager commands:

```sh
sfw pnpm install
sfw npm install
```

## Pi Coding Agent

Pi is installed by default as a pnpm global package:

```sh
pnpm add -g @earendil-works/pi-coding-agent
```

The repo tracks a public-safe global Pi setup in `home/.pi/agent/`:

- `settings.json` keeps project trust on `ask`, disables Pi telemetry/analytics,
  and enables compaction/retry defaults.
- `AGENTS.md` contains global safety notes for Pi sessions.
- `extensions/safety-guard.ts` blocks writes outside the current project,
  blocks protected credential/config paths, blocks catastrophic shell commands,
  and asks before high-risk shell commands when a TUI is available.
- `extensions/trust-github-repos.ts` automatically trusts GitHub checkouts
  owned by `KvalitetsIT` or `luxass`.
- `extensions/notify.ts` sends a Ghostty-compatible desktop notification when
  Pi finishes a turn and waits for input.
- `extensions/review.ts` adds `/review` and `/end-review` workflows for code
  review sessions over PRs, branches, commits, folders, or local changes.
- `extensions/package-manager-interceptor.ts` prepends package-manager shims to
  Pi's bash `PATH`, blocks install-policy bypass flags, and routes install-like
  `pnpm`/`npm`/`yarn`/`bun` commands and runner aliases through Socket Firewall
  when available.
- `skills/commit/` teaches Pi to make focused Conventional Commits with useful
  commit bodies.
- `skills/github/` teaches Pi to use the `gh` CLI for PRs, checks, workflow
  runs, issues, and GitHub API queries.

This is a host-side guard, not a sandbox. For untrusted repositories or
unattended work, run Pi in an isolated environment instead of relying only on the
extension.

The shell environment sets `PI_SKIP_VERSION_CHECK=1` so Pi does not write update
or changelog state into the tracked settings file during startup.

Manage Pi and pinned Pi extensions through `dot pi`:

```sh
dot pi status
dot pi update
dot pi update 0.79.3
dot pi extension install plannotator 0.20.2
```

`dot update` asks whether to update Pi and managed Pi extensions/skills after
the Homebrew and Stow steps.

`dot pi update [VERSION]` updates the tracked Pi package pins in
`home/.pi/package.json`, refreshes the lockfile, runs `pi update`, verifies
`pi --version`, runs the optional manual skills sync workflow when installed,
and finishes with `dot doctor`. When `VERSION` is omitted, it resolves the
latest `@earendil-works/pi-coding-agent` version from npm. Pi's own updater
supplies its pnpm safety flags for self-updates, including disabled lifecycle
scripts and a release-age override for fresh Pi releases.

`dot pi extension install plannotator VERSION` installs the pinned Plannotator
Pi extension with sharing disabled by default through `PLANNOTATOR_SHARE`. This
explicit pinned install disables npm lifecycle scripts and overrides npm's
release-age gate for that command only.

Do not commit Pi auth, trust decisions, sessions, package installs, logs, or
caches. Those paths are ignored by the global gitignore.

## Troubleshooting

Run diagnostics first:

```sh
dot doctor
```

Run the publish safety scan:

```sh
dot secret-scan
```

Check symlinks:

```sh
dot links
dot stow
```

Check package drift:

```sh
dot check-packages
dot retry-failed
```

Open the repo:

```sh
dot edit
```

## Safety

This repository is intended to be public-safe. Do not commit tokens, auth files,
shell histories, generated app state, machine caches, or private identity files.
