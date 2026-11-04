# DOTFILES

Personal macOS development environment managed with GNU Stow and the `dot` CLI.

This repo is public-facing. Keep tokens, auth files, shell histories,
work-only details, and machine-local secrets out of tracked content.
`README.md` has the user-facing details; this file holds the rules.

## STRUCTURE

```text
dots/
|-- dot                 # CLI entrypoint: sources lib/ and runs main
|-- lib/
|   |-- core/           # Output, prompts, paths/versions, prefs, links, dispatch, migrations
|   |-- features/       # One file per managed thing, exposing hooks (see CLI DESIGN)
|   `-- commands/       # CLI surface: `dot foo-bar` runs cmd_foo_bar
|-- stow/               # Native GNU Stow packages (STOW_PACKAGES); paths mirror $HOME
|-- shared/agents/      # Shared skills and the native global skills CLI lock
|-- packages/           # Brewfiles: bundle (base), bundle.fonts, bundle.personal, bundle.work
|-- .githooks/          # Tracked repository hooks (pre-push: secret-scan, lint)
|-- .github/workflows/  # CI: lint, secret scan, Stow link/unlink into an empty HOME
|-- .mise.toml          # Pinned lint tools for this repo (shellcheck, shfmt)
`-- .editorconfig       # Shell style, also read by shfmt
```

## WHERE TO LOOK

| Task | Location |
| --- | --- |
| Add or remove packages | `dot brew add/remove ...` first, or edit `packages/bundle*` |
| Change Homebrew behavior | `lib/features/homebrew.sh`, `lib/commands/brew.sh` |
| Diagnose setup | `dot doctor`, `dot info` |
| Change setup/update flow | `lib/commands/setup.sh` |
| Change what a managed thing does | `lib/features/<name>.sh` |
| Add a managed thing | new `lib/features/<name>.sh` + `FEATURES` in `lib/core/paths.sh` |
| Add a command | `cmd_<name>` in `lib/commands/`, plus `cmd_help` and `dot.fish` completions |
| Change paths or managed versions | `lib/core/paths.sh` |
| Change symlink/Stow behavior | `lib/features/stow.sh`, `lib/core/fs.sh` |
| Change runtime tools and install policy | `lib/features/pnpm.sh`, `stow/runtime-policy/`, `stow/fish/.config/fish/conf.d/` |
| Change Git defaults and public identity | `stow/git/.config/git/config` (public config only) |
| Change GitHub CLI config/extensions | `stow/gh/.config/gh/`, `lib/features/gh.sh` |
| Change shell, prompt, terminal | `stow/fish/`, `stow/starship/`, `stow/ghostty/` |
| Change Rex configuration | `stow/rex/.config/rex/`, `lib/features/rex.sh` |
| Change Herdr plugins/shortcuts | `stow/herdr/.config/herdr/plugins.txt`, `config.toml`, `lib/features/herdr.sh` |
| Change OpenCode config/plugins | `stow/opencode/.config/opencode/`, `lib/features/opencode.sh` |
| Change Pi agent config | `stow/pi/.pi/agent/` (settings, extensions, themes, notes) |
| Change Agent Skills | `sfw pnpx skills` directly; links in `lib/features/skills.sh` |
| Remove a one-time migration | `lib/core/migrations.sh` |

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
- `dot lint` (shellcheck + shfmt) must pass. The tools are pinned in
  `.mise.toml` and run through `mise exec`; each machine needs `mise trust` once.
- After behavior changes, run `dot doctor`.

## CONVENTIONS

General:

- macOS on Apple Silicon only, unless explicitly asked otherwise.
- Prefer the `dot` CLI over ad hoc commands, and never run bare Stow.
- Do not stage or commit files on the user's behalf unless asked.

Stow:

- Each `stow/<package>/` mirrors `$HOME`; `dot-*` names become hidden files.
  `dot` stows every package in `STOW_PACKAGES` with `--dotfiles --no-folding`.
- Everything inside a package deploys except the shared `.stow-local-ignore`
  rules (`node_modules`, `.DS_Store`, private Git paths). Git ignores do not
  affect Stow selection, so keep runtime state physically outside packages.
- Shared skills and their lock are linked by `lib/features/skills.sh`, not Stow.

Secrets and local state:

- Never track or stow auth, credentials, sessions, logs, caches, sockets, or
  downloaded plugin code. This covers gh `hosts.yml`, OpenCode `service*.json`,
  Herdr `plugins/`, `plugins.json`, `.plugins.lock`, and Rex state.
- Git: public defaults only in `stow/git/.config/git/config`, which includes
  `~/.config/git/local.conf` last. Work identities live in that file and
  `~/.config/git/extras/`; keep work name, email, and signing key together.
  Keep those paths in both Git and Stow ignores and out of `stow_sources`.
  Never print local identity values in diagnostics.
- Git uses Homebrew's `ca-certificates` bundle. Never modify Apple's system
  bundle or disable TLS verification.
- Runtime policy files (`.npmrc`, pnpm, Bun) hold install policy, never auth.
  Release-age overrides stay scoped to one command; never relax the policy globally.
- Codex config (`~/.codex/config.toml`) is local; `stow/codex/` is ignore policy only.

Tool-specific rules:

- Pi: Git allow-lists customization under `stow/pi/.pi/agent/`. Pi rewrites
  `settings.json` unprompted; expect churn. Never put credentials (such as a
  proxy URL with a password) in it. Do not commit local dev package paths;
  re-add them per machine with `pi install`.
- OpenCode v2: register `@luxass/opencode-voice` once, in the `plugins` array
  of `opencode.jsonc`, not `cli.json`. Never run `opencode service set ...`
  automatically; it stops the background server. Restart OpenCode after
  editing its config or plugins.
- Rex: configuration only. `dot` never installs, updates, launches, or restarts
  Rex. Never track generated theme IDs or the imported theme registry.
  Keep Remote Control unchanged. Do not add a theme shortcut or action, or
  Neovim or Twitch integration.
- Herdr: keep `prefix+m` for pane zoom, `prefix+o` for document review, and
  `prefix+i` for notifications. Never stop a running Herdr server.
- Fish: plugins are listed in `fish_plugins` and installed by Fisher outside
  the repo. Never commit plugin files, `fish_variables`, or generated completions.
- Homebrew: each package belongs to one bundle; base is always enabled.
  Optional bundles are chosen per machine through the existing
  `packages.brew.<group>.enabled` preference keys; keep those keys. Enabling or
  disabling a bundle never installs or uninstalls. `dot brew remove` changes
  declarations only; `dot brew uninstall` refuses declared packages and active
  apps or services. Unattended installs fail on unset choices, even with
  `--yes`. Reports never prompt or change preferences. Never add automatic
  cleanup or delete user data.
- Cua Driver: ask before stopping a running daemon and warn that computer-use
  sessions will be interrupted; abort if it does not stop. `dot stow` never
  installs or launches it. The human approves macOS permission dialogs.
- mise: never pin global runtime versions in the repo. Node.js stays managed by
  pnpm unless explicitly migrated.

Skills:

- Manage shared skills with `sfw pnpx skills add/list/update/remove -g`.
  There is no `dot skills` command.
- The native lock is tracked at `shared/agents/.skill-lock.json`. Never clear
  it during stow, and keep credentials and machine-local paths out of it.
- Edit only locally maintained skills. Before adapting an imported skill,
  remove its lock entry without deleting the files.
- Exception: `cua-driver` keeps its lock entry. Local edits stay limited to
  `LOCAL.md` and the read-first note in `SKILL.md`; restore both after updates.
- Commit or stash skill edits before CLI updates. Record upstream SHAs in
  import/update commit messages when known.

## ANTI-PATTERNS

- Editing symlink targets in `$HOME` instead of files under `stow/`.
- Adding tokens, auth files, shell histories, private keys, private Git identity,
  or machine-local secrets to tracked files.
- Printing or exposing sensitive local auth content while debugging.
- Reintroducing removed tools or configs (tmux, skhd, lazygit, wezterm, Neovim
  config, custom alias/function files) unless explicitly requested.
- Hardcoding absolute user paths instead of `$HOME`, repo-relative paths, or
  existing helper variables.
- Adding Linux-specific setup, or casks in `packages/bundle.work`, unless asked.
- Creating nested Git repositories or unmanaged dependency installs inside
  stowed config directories.
- Running package-manager installs without Socket Firewall (`sfw pnpm install`,
  `sfw npm install`, ...). Only the standalone pnpm and `sfw` bootstraps are exempt.

## COMMANDS

```sh
dot init             # Install packages, link dotfiles, set up runtimes and hooks
dot update           # Pull changes, offer upgrades, relink
dot stow / unstow    # Link or remove all Stow packages
dot doctor           # Diagnostics and secret scan (--verbose for details)
dot info             # Repo paths, runtime tools, git status
dot secret-scan      # Scan tracked and unignored files for secrets
dot lint             # shellcheck + shfmt over dot, lib/, .githooks/
dot hooks            # Install repository Git hooks
dot config           # Local-only preferences (git-config format)
dot brew list|check|install|unmanaged|update  # Report, install missing, upgrade
dot brew add|remove|uninstall X     # remove changes the declaration only
dot brew bundle list|enable|disable # Local bundle choice; never installs
```

`-y`/`--yes` answers yes to confirmations, but never answers unset bundle choices.

## NOTES

- The pre-push hook runs `dot secret-scan` and `dot lint`. The scanner never
  prints values and skips ignored files, submodules, and history. Reviewed
  exceptions live in `.secret-scan-allowlist` as an exact source-line SHA-256
  plus path; never replace them with whole-file or directory exclusions.
- `dot stow` backs up anything blocking a managed link to
  `${XDG_STATE_HOME:-$HOME/.local/state}/dot/backups/<timestamp>/`.
