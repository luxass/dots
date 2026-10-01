# DOTFILES

Personal macOS development environment managed with GNU Stow and the `dot` CLI.

This repo is public-facing. Keep tokens, auth files, shell histories, private
Git identity, work-only details, and machine-local secrets out of tracked
content. Personal Git identity belongs in `~/.gitconfig.local`.

## STRUCTURE

```text
dots/
|-- dot                 # CLI entrypoint: sources lib/ and runs main
|-- lib/
|   |-- core/           # Output, prompts, paths/versions, prefs, links, dispatch, migrations
|   |-- features/       # One file per managed thing, exposing hooks (see CLI DESIGN)
|   `-- commands/       # CLI surface: `dot foo-bar` runs cmd_foo_bar
|-- home/               # Stowed into $HOME
|   |-- .codex/         # Ignore policy only; Codex config stays local and unmanaged
|   |-- .config/
|   |   |-- cliproxyapi/ # CLIProxyAPI config; auth/ is never tracked
|   |   |-- fish/       # Primary shell config
|   |   |-- ghostty/    # Terminal config
|   |   |-- opencode/   # OpenCode config, TS plugins, package lock
|   |   |-- pnpm/       # pnpm security policy
|   |   `-- starship.toml
|   |-- .bunfig.toml    # Bun install policy
|   |-- .gitconfig      # Public Git settings; includes ~/.gitconfig.local
|   |-- .local/bin/     # Personal CLI tools (git-wt-clean)
|   |-- .npmrc          # npm policy only; no auth
|   |-- .pi/            # Lean Pi agent config (settings, keybindings, notes)
|   `-- dot-gitignore   # Stowed as ~/.gitignore via stow --dotfiles
|-- packages/
|   |-- bundle          # Base Brewfile
|   |-- bundle.fonts    # Optional font casks
|   |-- bundle.personal # Optional personal-only Brewfile
|   `-- bundle.work     # Optional work-only Brewfile
|-- private/
|   |-- opencode/       # Private OpenCode plugins submodule (voice, ...)
|   `-- pi/             # Private Pi extensions submodule
|-- .githooks/          # Tracked repository hooks (pre-push: secret-scan, lint)
|-- .editorconfig       # Shell style, also read by shfmt
|-- .mise.toml          # Pinned lint tools for this repo (shellcheck, shfmt)
|-- .shellcheckrc       # shellcheck settings for dot
|-- AGENTS.md           # Agent instructions
`-- README.md           # User-facing setup and command docs
```

## WHERE TO LOOK

| Task | Location |
| --- | --- |
| Add or remove packages | `dot package add/remove ...` first, or edit `packages/bundle*` |
| Diagnose setup | `dot doctor`, `dot info` |
| Change setup/update flow | `lib/commands/setup.sh` |
| Change what a managed thing does | `lib/features/<name>.sh` |
| Add a managed thing | new `lib/features/<name>.sh` + `FEATURES` in `lib/core/paths.sh` |
| Add a command | `cmd_<name>` in `lib/commands/`, plus `cmd_help` and `dot.fish` completions |
| Change paths or managed versions | `lib/core/paths.sh` |
| Change Homebrew behavior | `lib/features/homebrew.sh`, `lib/commands/package.sh` |
| Change symlink/Stow behavior | `lib/features/stow.sh`, `lib/core/fs.sh` |
| Add a personal CLI tool | `home/.local/bin/`, then `dot stow` |
| Change runtime tools | `lib/features/pnpm.sh`, `home/.npmrc`, `home/.config/pnpm/config.yaml`, `home/.bunfig.toml`, `home/.config/fish/conf.d/` |
| Change Git defaults | `home/.gitconfig` for public config only |
| Change private Git identity | `~/.gitconfig.local`, never tracked files |
| Change shell startup | `home/.config/fish/` |
| Change prompt | `home/.config/starship.toml` |
| Change terminal | `home/.config/ghostty/config` |
| Change OpenCode config/plugins | `home/.config/opencode/`, `lib/features/opencode.sh` |
| Change private OpenCode plugins | `private/opencode/plugins/` |
| Change Pi agent config | `home/.pi/agent/` (lean: settings, keybindings, notes only) |
| Change Agent Skills | `lib/features/skills.sh`, `lib/commands/tools.sh`, `home/.agents/` |
| Change CLIProxyAPI config | `home/.config/cliproxyapi/config.yaml`, `lib/features/cliproxyapi.sh` |
| Change Claude Code skills link | `lib/features/skills.sh` (`~/.claude/skills` -> `~/.agents/skills`) |
| Remove a one-time migration | `lib/core/migrations.sh` |
| Install hooks | `dot hooks` |
| Scan for secrets | `dot secret-scan` |
| Lint the CLI | `dot lint` |

## CLI DESIGN

- Runs on macOS system Bash 3.2: no associative arrays, `mapfile`, `${x,,}`,
  `[[ -v ]]`, or globstar, and guard empty-array expansion under `set -u`.
- Features hook into the flow by defining `<name>_prestow`, `<name>_poststow`,
  `<name>_deps`, `<name>_unstow`, or `<name>_check`. `run_hook` calls them in
  `FEATURES` order; `dot doctor` prints one section per `_check`.
- Return status explicitly (`|| return 1`). Do not rely on `set -e` inside
  functions: it is disabled in functions called from `if`, `&&`, or `||`.
- Use `x=$((x + 1))`, never `((x++))`, which fails under `set -e` at zero.
- Use `print_*` helpers (warnings/errors go to stderr) and `pretty_path` for
  displayed paths; use `ensure_link`/`check_link` for managed symlinks and
  `backup_path` before replacing anything.
- `dot lint` (shellcheck + shfmt with `.editorconfig`) must pass. The tools
  are pinned in the repo's `.mise.toml`, not the Brewfile, and `dot lint` runs
  them with `mise exec` from the repo so hooks and other directories work.
  Each machine needs `mise trust` in the repo once.

## CONVENTIONS

- macOS-only unless a user explicitly asks for another platform.
- Prefer the existing `dot` CLI over ad hoc commands for setup, package checks,
  symlink checks, and diagnostics.
- Use GNU Stow semantics. Files under `home/` map to `$HOME`; `dot-*` names map
  to hidden files through `stow --dotfiles`.
- Keep `home/.gitconfig` public-safe. It may include `~/.gitconfig.local`, but
  must not contain name, email, signing key, or work-only identity values.
- Codex is installed as a Homebrew cask, but its config is not managed. The
  live `~/.codex/config.toml` is local state and must not be stowed or
  tracked; `home/.codex/` only holds an ignore policy.
- Keep package policy public and token-free. `home/.npmrc`, pnpm config, and
  Bun config should contain install policy, not registry auth.
- Keep OpenCode config public-safe. Do not track auth, trust, cache, or local
  provider secret files. `dot stow` installs TypeScript plugin dependencies with
  `sfw pnpm install` in `~/.config/opencode/` (and in `private/opencode/` when
  private plugins exist); `dot doctor` verifies them.
- `home/.config/opencode/node_modules/` may exist locally for editor/type
  resolution, but it is ignored by Git and Stow. Keep `pnpm-lock.yaml`
  tracked.
- Keep Pi config public-safe. `home/.pi/agent/` state is blanket-ignored
  with an allow-list for customization (`themes/`,
  `extensions/`, `mcp.json`, `cloak.json`, `settings.json`,
  `APPEND_SYSTEM.md`, packaging); auth, trust, sessions, logs, caches, and
  keybindings stay local. `settings.json` is tracked and holds preferences
  only. Pi writes to it unprompted, so expect churn from
  `lastChangelogVersion` on upgrade and from any `/settings` edit. Never put
  an `httpProxy` URL with a password in it: `dot secret-scan` now rejects
  credentials embedded in a URL, but a proxy belongs in the environment.
  Local dev checkouts of Pi packages are absolute-ish paths that do not
  resolve elsewhere; re-add them with `pi install` per machine rather than
  committing them.
  `home/.pi/package.json` provides extension dependencies (editor completion,
  types) via `sfw pnpm install` in `~/.pi` during `dot stow`;
  `dot doctor` verifies them. `home/.pi/node_modules/` is ignored by Git and
  Stow; keep `pnpm-lock.yaml` tracked. The `pi` binary itself is a managed
  pnpm global (`PNPM_GLOBAL_PACKAGES` in `lib/core/paths.sh`).
- Private OpenCode plugins live in the private submodule at
  `private/opencode/`. It uses a flat `plugins/` layout and `dot stow` links
  each plugin file or directory into `~/.config/opencode/plugins/` and removes
  stale links; do not add a mirrored `home/.config/opencode/` tree there unless
  explicitly requested. The voice plugin lives there and fetches its own
  Whisper model; dot does not download it.
- Private Pi extensions live in the `private/pi` submodule and load
  through Pi's native local-path package (`pi install` pointed in-tree,
  recorded in `settings.json`); edits take effect immediately with
  no copy step. Never track them outside the submodule. `dot stow`
  aligns the checkout to the parent gitlink and installs the package. Use
  `dot submodule update` to advance the submodule. The Pi voice extension
  fetches its own Whisper model.
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
- Running package-manager installs without Socket Firewall. Use `sfw pnpm install`,
  `sfw npm install`, or another `sfw ...` wrapper as appropriate. The standalone
  pnpm and Socket Firewall bootstrap steps are the exceptions.

## COMMANDS

```sh
dot init             # Install packages, link dotfiles, set up runtimes, hooks, identity
dot update           # Pull changes, offer pnpm/Homebrew/Pi upgrades, relink
dot stow             # Link home/ with GNU Stow and install plugin dependencies
dot unstow           # Remove symlinks using GNU Stow
dot doctor           # Run diagnostics and secret scan
dot info             # Show repo paths, runtime tools, and git status
dot secret-scan      # Scan tracked and unignored files for secrets
dot lint             # shellcheck + shfmt (pinned in .mise.toml) over dot, lib/, .githooks/
dot hooks            # Install repository Git hooks
dot git-identity     # Create or update ~/.gitconfig.local
dot config           # Manage local-only preferences (git-config format)
dot submodule status # Show private submodule revisions
dot submodule update # Fetch latest private submodule branches
dot package list     # List managed packages per group
dot package check    # Show missing packages
dot package add X    # Track and install a package (--cask, --group GROUP)
dot package unmanaged # Installed packages no bundle tracks
dot skills add U     # Add shared global Agent Skills from a URL/source
dot skills list      # List installed shared global Agent Skills
dot cliproxyapi      # Run CLIProxyAPI in the foreground with the stowed config
```

Use `dot --verbose doctor` when diagnostics need more detail. `-y`/`--yes`
answers yes to confirmations.

## KEY CONFIGS

| Tool | Entry | Notes |
| --- | --- | --- |
| Fish | `home/.config/fish/` | Primary shell startup and environment |
| Git | `home/.gitconfig` | Public config; private identity is local-only |
| Ghostty | `home/.config/ghostty/config` | Terminal settings |
| Starship | `home/.config/starship.toml` | Prompt |
| Homebrew | `packages/bundle*` | Base, fonts, personal, and optional work bundles |
| npm | `home/.npmrc` | Install policy, no auth |
| pnpm | `home/.config/pnpm/config.yaml` | Security policy and runtime behavior |
| Bun | `home/.bunfig.toml` | Install policy |
| OpenCode | `home/.config/opencode/` | Global config and local TypeScript plugins |
| CLIProxyAPI | `home/.config/cliproxyapi/config.yaml` | `dot stow` links it to `$(brew --prefix)/etc/cliproxyapi.conf`; `auth/` holds OAuth credentials and is git-ignored |

## NOTES

- The tracked pre-push hook runs `dot secret-scan` and `dot lint`.
- `dot stow` backs up anything blocking a managed link to
  `${XDG_STATE_HOME:-$HOME/.local/state}/dot/backups/<timestamp>/`. The old
  repo-local `backups/` directory is no longer written.
- mise is installed from the base Homebrew bundle and activated in Fish through
  `home/.config/fish/conf.d/mise.fish`. Do not pin global runtime versions in
  the repo; project runtime selections belong in each project's `.mise.toml`.
  Node.js currently remains managed by pnpm unless explicitly migrated.
- `dot init` stows package-manager policy before installing standalone pnpm and
  pnpm-managed runtime tools, so install policy is active during setup.
- Managed pnpm globals currently include Socket Firewall (`sfw`), npm 12, and
  Pi (`pi`). OpenCode v2 (`opencode`) is installed through the
  `anomalyco/tap/opencode-v2` Homebrew formula. `dot update` runs Pi's native
  self-updater and handles OpenCode updates through Homebrew.
- OpenCode local plugins are tracked under `home/.config/opencode/plugins/`.
  Restart OpenCode after editing config or plugins.
- The private OpenCode submodule is initialized and aligned to the parent
  gitlink by `dot init` / `dot stow`. Run `dot submodule update` to fetch its
  configured `main` branch, then commit the gitlink changes in the parent.
  Dependencies should install with `sfw pnpm install` from `private/opencode/`.
- Optional package groups are controlled by local-only preferences under
  `${XDG_STATE_HOME:-$HOME/.local/state}/dot/preferences`: fonts default to yes
  when first prompted, work packages default to no.
- Only custom/local Agent Skills should be edited directly. Install external
  skills with `dot skills add <url>` so files remain under
  `home/.agents/skills/`. Use `dot skills list` to inspect installed shared
  global Agent Skills; the wrapped skills CLI updates its lock/inventory.
- Track vendored skill provenance by source SHA, not per-skill metadata
  files. Record the upstream repository and commit (for example,
  pstack skills from `cursor/plugins@4612556`) in the commit message that
  adds or updates the skills; re-check that SHA when updating.
- `dot stow` also links `~/.claude/skills` to `~/.agents/skills` so Claude Code
  shares the same skills; `dot doctor` checks this link.
- `dot stow` links `$(brew --prefix)/etc/cliproxyapi.conf` to the stowed
  `~/.config/cliproxyapi/config.yaml` so the Homebrew service uses the tracked
  config; `dot doctor` checks this link. Never commit
  `home/.config/cliproxyapi/auth/` (OAuth credentials).
