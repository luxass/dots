# dots

Personal dotfiles for macOS on Apple Silicon, managed with GNU Stow and the `dot` CLI.

## Setup

Install [Homebrew](https://brew.sh) first. Then clone the repository, run setup,
and put `dot` on PATH:

```fish
git clone git@github.com:luxass/dots.git ~/dots
cd ~/dots
./dot/bin/dot init
./dot/bin/dot link
```

Setup installs packages, links configuration, and sets up runtimes and hooks,
one component at a time. It asks whether to install the work packages.
`dot link` creates `~/.local/bin/dot`, and Fish puts `~/.local/bin` on PATH.

Restart the terminal after setup changes the login shell to Fish.
Rust setup is optional. Setup offers rustup from `https://sh.rustup.rs` if missing.
Fish loads `~/.cargo/env.fish` when present. `dot doctor` checks for rustup.
Authenticate apps separately. Credentials are not part of these dotfiles.

## Everyday commands

```fish
dot update                  # Pull, then update every component
dot update --only rex,pi    # Update some components
dot doctor                  # Check every component, including a secret scan
dot components              # What dot manages, in run order
dot stow                    # Re-link the Stow packages
dot package add ripgrep     # Install a package and add it to packages/bundle
dot check-packages          # Report missing packages
dot help                    # All commands and global options
```

`init`, `update`, and `doctor` take `--only` and `--skip` with component names.
`init` and `update` also take `--dry-run`.
`dot update` upgrades every outdated Homebrew package without asking.
`dot stow` backs up blocking files before replacing them.
See [managed links](dot/lib/components/stow.md) for backup locations and recovery notes.
[dot/README.md](dot/README.md) explains how the CLI works.

## Component references

Instructions live beside each component's implementation:

- [Homebrew packages](dot/lib/components/packages.md)
- [Managed links and local state](dot/lib/components/stow.md)
- [Git identities and signing](dot/lib/components/git.md)
- [Fish and plugins](dot/lib/components/fish.md)
- [JavaScript runtimes and install policy](dot/lib/components/pnpm.md)
- [Shared Agent Skills](dot/lib/components/skills.md)
- [Pi and Plannotator](dot/lib/components/pi.md)
- [Cua Driver](dot/lib/components/cua.md)
- [OpenCode](dot/lib/components/opencode.md)
- [Rex](dot/lib/components/rex.md)
- [GitHub CLI](dot/lib/components/gh.md)

## Contributing safely

Edit configuration under `stow/`, not through linked HOME paths.
Keep credentials, private identities, sessions, and generated state outside the checkout.
Use Socket Firewall for package installs, such as `sfw pnpm install`.
Run `dot secret-scan` before publishing. It does not scan ignored files or Git history.

See [AGENTS.md](AGENTS.md) for repository layout, development rules, and validation.
