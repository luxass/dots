# DOTFILES

Personal macOS development environment managed with GNU Stow and the `dot` CLI.

This repo is public-facing. Keep tokens, auth files, shell histories, private
Git identity, work-only details, and machine-local secrets out of tracked
content. Personal Git identity belongs in `~/.gitconfig.local`.

## STRUCTURE

```text
dots/
|-- dot                 # Main CLI: init/update/doctor/stow/package/pi
|-- lib/
|   |-- brew.sh         # Homebrew bundle install, update, retry, package ops
|   |-- core.sh         # Shared output, prompts, command helpers
|   |-- git.sh          # Git hooks, identity, secret scanning
|   |-- pi.sh           # Managed Pi package and extension commands
|   |-- runtime.sh      # pnpm, Node.js, npm, and global runtime tools
|   `-- stow.sh         # GNU Stow links, backups, dot CLI linking
|-- home/               # Stowed into $HOME
|   |-- .config/
|   |   |-- ghostty/    # Terminal config
|   |   |-- pnpm/       # pnpm security policy
|   |   `-- starship.toml
|   |-- .pi/            # Managed Pi runtime/config
|   |-- .bunfig.toml    # Bun install policy
|   |-- .gitconfig      # Public Git settings; includes ~/.gitconfig.local
|   |-- .npmrc          # npm policy only; no auth
|   |-- .zprofile
|   |-- .zshenv
|   |-- .zshrc
|   `-- dot-gitignore   # Stowed as ~/.gitignore via stow --dotfiles
|-- packages/
|   |-- bundle          # Base Brewfile
|   |-- bundle.fonts    # Optional font casks
|   `-- bundle.work     # Optional work-only Brewfile
|-- backups/            # Local Stow conflict backups; do not rely on contents
|-- .githooks/          # Tracked repository hooks
|-- AGENTS.md           # Agent instructions
`-- README.md           # User-facing setup and command docs
```

## WHERE TO LOOK

| Task | Location |
| --- | --- |
| Add or remove packages | `dot package ...` first, or edit `packages/bundle*` |
| Diagnose setup | `dot doctor`, `dot info`, `dot links` |
| Change setup/update behavior | `dot`, then relevant `lib/*.sh` helper |
| Change Homebrew behavior | `lib/brew.sh` |
| Change symlink/Stow behavior | `lib/stow.sh` |
| Change runtime tools | `lib/runtime.sh`, `home/.npmrc`, `home/.config/pnpm/config.yaml`, `home/.bunfig.toml` |
| Change Git defaults | `home/.gitconfig` for public config only |
| Change private Git identity | `~/.gitconfig.local`, never tracked files |
| Change shell startup | `home/.zshenv`, `home/.zprofile`, `home/.zshrc` |
| Change prompt | `home/.config/starship.toml` |
| Change terminal | `home/.config/ghostty/config` |
| Change Pi management | `lib/pi.sh`, `home/.pi/package.json`, `home/.pi/agent/settings.json` |
| Install hooks | `dot hooks` |
| Scan for secrets | `dot secret-scan` |

## CONVENTIONS

- macOS-only unless a user explicitly asks for another platform.
- Prefer the existing `dot` CLI over ad hoc commands for setup, package checks,
  symlink checks, and diagnostics.
- Use GNU Stow semantics. Files under `home/` map to `$HOME`; `dot-*` names map
  to hidden files through `stow --dotfiles`.
- Keep `home/.gitconfig` public-safe. It may include `~/.gitconfig.local`, but
  must not contain name, email, signing key, or work-only identity values.
- Keep package policy public and token-free. `home/.npmrc`, pnpm config, and
  Bun config should contain install policy, not registry auth.
- Neovim may remain installed/tracked as a package, but do not reintroduce
  Neovim configuration unless explicitly requested.
- After behavior changes, run `dot doctor`.

## ANTI-PATTERNS

- Editing generated symlink targets in `$HOME` instead of files under `home/`.
- Adding tokens, auth files, shell histories, private keys, private Git identity,
  or machine-local secrets to tracked files.
- Printing or exposing sensitive local auth content while debugging.
- Reintroducing removed configs or tools such as tmux, skhd, lazygit, wezterm,
  Neovim config, or custom alias/function files unless explicitly requested.
- Hardcoding absolute user paths when `$HOME`, repo-relative paths, or existing
  helper variables are available.
- Adding Linux-specific setup paths unless requested.
- Adding casks to `packages/bundle.work`; keep work-only casks out unless the
  user explicitly asks for them.
- Creating nested git repositories or unmanaged dependency installs inside
  stowed config directories.

## COMMANDS

```sh
dot init             # Install packages, stow files, create local identity, link dot
dot update           # Pull repo changes, update packages, and restow
dot doctor           # Run diagnostics and secret scan
dot info             # Show repo paths, runtime tools, and git status
dot links            # Verify managed home symlinks
dot hooks            # Install repository Git hooks
dot secret-scan      # Scan repository for secrets
dot stow             # Create symlinks using GNU Stow
dot unstow           # Remove symlinks using GNU Stow
dot git-identity     # Create or update ~/.gitconfig.local
dot check-packages   # Check installed Homebrew package state
dot retry-failed     # Retry failed package installations
dot package list     # List managed packages
dot package add X    # Add and install a package
dot pi status        # Show managed Pi status
dot completions      # Print zsh completions
```

Use `dot --verbose doctor` or `dot --verbose info` when diagnostics need more
detail.

## KEY CONFIGS

| Tool | Entry | Notes |
| --- | --- | --- |
| zsh | `home/.zshrc`, `.zprofile`, `.zshenv` | Shell startup and environment |
| Git | `home/.gitconfig` | Public config; private identity is local-only |
| Ghostty | `home/.config/ghostty/config` | Terminal settings |
| Starship | `home/.config/starship.toml` | Prompt |
| Homebrew | `packages/bundle*` | Base, fonts, and optional work bundles |
| npm | `home/.npmrc` | Install policy, no auth |
| pnpm | `home/.config/pnpm/config.yaml` | Security policy and runtime behavior |
| Bun | `home/.bunfig.toml` | Install policy |
| Pi | `home/.pi/package.json`, `home/.pi/agent/settings.json` | Managed by `dot pi` |

## NOTES

- The tracked pre-push hook runs `dot secret-scan`.
- `dot init` stows package-manager policy before installing pnpm-managed
  runtime tools, so install policy is active during setup.
- Managed pnpm globals currently include Socket Firewall (`sfw`) and Pi (`pi`).
- Optional package groups are prompted during `dot init`: fonts default to yes,
  work packages default to no.
