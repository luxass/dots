# dots

Personal dotfiles for macOS on Apple Silicon, managed with GNU Stow and the `dot` CLI.

## Setup

Clone the repository and run setup:

```fish
git clone git@github.com:luxass/dots.git ~/dots
cd ~/dots
./dot init
```

Setup installs packages, links configuration, and sets up runtimes and hooks.
Choose which optional Homebrew bundles to enable when prompted.
`--yes` does not answer unset bundle choices.

Restart the terminal after setup changes the login shell to Fish.
If `dot` is not on PATH, run this once in Fish:

```fish
fish_add_path ~/dots
```

Rust setup is optional. Setup offers rustup from `https://sh.rustup.rs` if missing.
Fish loads `~/.cargo/env.fish` when present. `dot doctor` checks for rustup.
Authenticate apps separately. Credentials are not part of these dotfiles.

## Everyday commands

```fish
dot update           # Pull changes, offer upgrades, and relink
dot doctor           # Diagnose the setup, including a secret scan
dot stow             # Repair links and install missing plugin dependencies
dot brew check       # Check enabled packages and bundle choices
dot brew unmanaged   # Find installed packages not declared here
dot help             # All commands and global options
dot brew help        # Package and bundle commands
dot config help      # Machine-local preferences
```

`dot stow` backs up blocking files before replacing them.
See [managed links](lib/features/stow.md) for backup locations and recovery notes.
Bundle selection never installs or uninstalls packages.
`dot brew remove` changes declarations only, not installed packages.

## Feature references

Instructions live beside each feature's implementation:

- [Homebrew packages and preferences](lib/features/homebrew.md)
- [Managed links and local state](lib/features/stow.md)
- [Git identities and signing](lib/features/git.md)
- [Fish and plugins](lib/features/fish.md)
- [JavaScript runtimes and install policy](lib/features/pnpm.md)
- [Shared Agent Skills](lib/features/skills.md)
- [Pi and Plannotator](lib/features/pi.md)
- [Cua Driver](lib/features/cua.md)
- [OpenCode](lib/features/opencode.md)
- [Herdr](lib/features/herdr.md)
- [Rex](lib/features/rex.md)
- [GitHub CLI](lib/features/gh.md)

## Contributing safely

Edit configuration under `stow/`, not through linked HOME paths.
Keep credentials, private identities, sessions, and generated state outside the checkout.
Use Socket Firewall for package installs, such as `sfw pnpm install`.
Run `dot secret-scan` before publishing. It does not scan ignored files or Git history.

See [AGENTS.md](AGENTS.md) for repository layout, development rules, and validation.
