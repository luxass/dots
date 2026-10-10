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
|   |-- .agents/        # Shared skills and the native global skills CLI lock
|   |-- .codex/         # Ignore policy only; Codex config stays local and unmanaged
|   |-- .config/
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
|   `-- opencode/       # Private OpenCode plugins submodule (voice, ...)
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
| Change Agent Skills | `sfw pnpx skills` directly; links in `lib/features/skills.sh`, files/lock in `home/.agents/` |
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
- Fish plugins are listed in `home/.config/fish/fish_plugins` and installed by
  Fisher into `fisher_path` (`~/.local/share/fisher`, set in
  `conf.d/fisher.fish`), never into `home/.config/fish/`. Add plugins to
  `fish_plugins` and run `dot stow`; do not commit plugin files.
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
sfw pnpx skills add U -g --skill N  # Import a shared global skill
sfw pnpx skills list -g            # List shared global skills and provenance
sfw pnpx skills update -g          # Update tracked upstream imports
sfw pnpx skills remove N -g        # Remove a skill and its global lock entry
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
- Managed pnpm globals currently include Socket Firewall (`sfw`), npm 12,
  Pi (`pi`), and `agent-browser`. Run `agent-browser install` once for its Chrome
  browser download. OpenCode v2 (`opencode`) is installed through the
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
- Shared skills live in `home/.agents/skills/`. Manage them directly with
  `sfw pnpx skills add/list/update/remove` and opt into global scope with `-g`.
  There is no `dot skills` command or scope-forcing wrapper. Project installs
  in other repositories remain project-local.
- The native global lock is tracked at `home/.agents/.skill-lock.json`.
  `dot stow` links both `~/.agents/.skill-lock.json` and
  `${XDG_STATE_HOME:-$HOME/.local/state}/skills/.skill-lock.json` to it. Never
  clear this inventory during stow or restore the archived stale records.
  Keep credentials, private sources, and machine-local paths out of the lock.
- Only locally maintained skills should be edited directly. Keep them out of
  the global lock so native upstream updates leave them alone. Before adapting
  an imported skill, remove its lock entry without deleting the files. There is
  no separate local inventory. Commit or stash skill edits before CLI updates,
  then review and commit the resulting diff.
- Record upstream source SHAs in import/update commit messages when known;
  the CLI maintains upstream/path/hash provenance in its native global lock.
- `dot stow` also links `~/.claude/skills` to `~/.agents/skills` so Claude Code
  shares the same skills; `dot doctor` checks this link.
