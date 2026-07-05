# DOTFILES

Personal macOS development environment managed with GNU Stow and the `dot` CLI.

This repo is public-facing. Keep tokens, auth files, shell histories, private
Git identity, work-only details, and machine-local secrets out of tracked
content. Personal Git identity belongs in `~/.gitconfig.local`.

## STRUCTURE

```text
dots/
|-- dot                 # Main CLI: init/update/doctor/stow/package
|-- lib/
|   |-- brew.sh         # Homebrew bundle install, update, retry, package ops
|   |-- core.sh         # Shared output, prompts, command helpers
|   |-- git.sh          # Git hooks, identity, secret scanning
|   |-- skills.sh       # Agent Skills wrapper around the skills CLI
|   |-- runtime.sh      # Vite+, Node.js, npm, and global runtime tools
|   `-- stow.sh         # GNU Stow links, backups, dot CLI linking
|-- home/               # Stowed into $HOME
|   |-- .config/
|   |   |-- fish/       # Primary shell config
|   |   |-- ghostty/    # Terminal config
|   |   |-- pnpm/       # pnpm security policy
|   |   `-- starship.toml
|   |-- .bunfig.toml    # Bun install policy
|   |-- .gitconfig      # Public Git settings; includes ~/.gitconfig.local
|   |-- .npmrc          # npm policy only; no auth
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
| Change runtime tools | `lib/runtime.sh`, `home/.npmrc`, `home/.config/pnpm/config.yaml`, `home/.bunfig.toml`, `home/.config/fish/conf.d/vite-plus.fish` |
| Change Git defaults | `home/.gitconfig` for public config only |
| Change private Git identity | `~/.gitconfig.local`, never tracked files |
| Change shell startup | `home/.config/fish/` |
| Change prompt | `home/.config/starship.toml` |
| Change terminal | `home/.config/ghostty/config` |
| Change Agent Skills | `lib/skills.sh`, `home/.agents/` |
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
dot update           # Pull repo changes, update packages, restow
dot doctor           # Run diagnostics and secret scan
dot info             # Show repo paths, runtime tools, and git status
dot links            # Verify managed home symlinks
dot hooks            # Install repository Git hooks
dot secret-scan      # Scan repository for secrets
dot stow             # Create symlinks using GNU Stow
dot unstow           # Remove symlinks using GNU Stow
dot git-identity     # Create or update ~/.gitconfig.local
dot config           # Manage local-only preferences
dot retry-failed     # Retry failed package installations
dot package list     # List managed packages
dot package check    # Check installed Homebrew package state
dot package add X    # Add and install a package
dot skills add U     # Add shared global Agent Skills from a URL/source
dot skills list      # List installed shared global Agent Skills
dot completions      # Print Fish completions
```

Use `dot --verbose doctor` or `dot --verbose info` when diagnostics need more
detail.

## KEY CONFIGS

| Tool | Entry | Notes |
| --- | --- | --- |
| Fish | `home/.config/fish/` | Primary shell startup and environment |
| Git | `home/.gitconfig` | Public config; private identity is local-only |
| Ghostty | `home/.config/ghostty/config` | Terminal settings |
| Starship | `home/.config/starship.toml` | Prompt |
| Homebrew | `packages/bundle*` | Base, fonts, and optional work bundles |
| npm | `home/.npmrc` | Install policy, no auth |
| pnpm | `home/.config/pnpm/config.yaml` | Security policy and runtime behavior |
| Bun | `home/.bunfig.toml` | Install policy |

## NOTES

- The tracked pre-push hook runs `dot secret-scan`.
- `dot init` stows package-manager policy before installing Vite+-managed
  runtime tools, so install policy is active during setup.
- Managed Vite+ globals currently include Socket Firewall (`sfw`).
- Optional package groups are controlled by local-only preferences under
  `${XDG_STATE_HOME:-$HOME/.local/state}/dot/preferences`: fonts default to yes
  when first prompted, work packages default to no.
- Only custom/local Agent Skills should be edited directly. Install external
  skills with `dot skills add <url>` so files remain under
  `home/.agents/skills/`. Use `dot skills list` to inspect installed shared
  global Agent Skills; the wrapped skills CLI updates its lock/inventory.
