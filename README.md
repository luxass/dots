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
- Managed pnpm global tools, including Socket Firewall (`sfw`)
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
├── dot                 # Main management CLI
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

```sh
dot init             # install packages, stow files, create local identity, link dot
dot update           # pull, update Homebrew, install bundle, restow
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

`dot init` also installs managed pnpm globals:

```text
sfw
```

Socket Firewall can be used by prefixing supported package-manager commands:

```sh
sfw pnpm install
sfw npm install
```

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
