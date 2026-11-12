# DOTFILES

Personal macOS development environment managed with GNU Stow and the `dot` CLI.
This repo is public-facing. [README.md](README.md) is the entry point.
Operational references live beside feature scripts in `lib/features/*.md`.

## WHERE TO LOOK

| Task | Source | Reference |
| --- | --- | --- |
| Setup and update flow | `lib/commands/setup.sh` | [README](README.md) |
| Packages and bundle choices | `lib/features/homebrew.sh`, `lib/commands/brew.sh`, `packages/bundle*` | [Homebrew](lib/features/homebrew.md) |
| Paths, versions, feature order | `lib/core/paths.sh` | |
| Managed links | `lib/features/stow.sh`, `lib/core/fs.sh` | [Stow](lib/features/stow.md) |
| Runtime policy and global tools | `lib/features/pnpm.sh`, `stow/runtime-policy/` | [pnpm](lib/features/pnpm.md) |
| Public Git configuration | `stow/git/.config/git/config`, `lib/features/git.sh` | [Git](lib/features/git.md) |
| GitHub CLI | `stow/gh/.config/gh/`, `lib/features/gh.sh` | [gh](lib/features/gh.md) |
| Shell, prompt, terminal | `stow/fish/`, `stow/starship/`, `stow/ghostty/` | [Fish](lib/features/fish.md) |
| Rex configuration | `stow/rex/.config/rex/`, `lib/features/rex.sh` | [Rex](lib/features/rex.md) |
| Herdr plugins and shortcuts | `stow/herdr/.config/herdr/`, `lib/features/herdr.sh` | [Herdr](lib/features/herdr.md) |
| OpenCode configuration and plugins | `stow/opencode/.config/opencode/`, `lib/features/opencode.sh` | [OpenCode](lib/features/opencode.md) |
| Pi customizations and reviews | `stow/pi/.pi/agent/`, `stow/plannotator/` | [Pi](lib/features/pi.md) |
| Cua Driver | `lib/features/cua.sh` | [Cua](lib/features/cua.md) |
| Shared Agent Skills | `shared/agents/`, `lib/features/skills.sh` | [Skills](lib/features/skills.md) |
| One-time migrations | `lib/core/migrations.sh` | |

## CLI DESIGN

- `dot` sources `lib/core/*.sh`, `lib/features/*.sh`, and `lib/commands/*.sh`, then calls `main`.
- Target macOS system Bash 3.2. Do not use associative arrays, `mapfile`, `${x,,}`,
  `[[ -v ]]`, or globstar. Guard empty-array expansion under `set -u`.
  Runtime code must not require Node.js, Python, Ruby, or another managed language runtime.
- Add a feature as `lib/features/<name>.sh` and register it in `FEATURES` in `lib/core/paths.sh`.
  Remove both to remove a feature. Put useful operating instructions beside it as `<name>.md`.
- Features expose `<name>_prestow`, `<name>_poststow`, `<name>_deps`, `<name>_unstow`,
  or `<name>_check`. `run_hook` calls them in `FEATURES` order.
  Doctor prints one section per `_check`.
- Add commands as `cmd_<name>` in `lib/commands/`. `dot foo-bar` runs `cmd_foo_bar`.
  Update `cmd_help` and the `dot.fish` completions when adding a command.
- Return status explicitly with `|| return 1`. Do not rely on `set -e` in functions:
  it is disabled for functions called from `if`, `&&`, or `||`.
- Use `x=$((x + 1))`, not `((x++))`, which fails under `set -e` at zero.
- Use `print_*` helpers and `pretty_path`. Warnings and errors go to stderr.
  Disable colors for non-terminal output and `NO_COLOR`.
- Use `ensure_link` and `check_link` for managed symlinks. Call `backup_path` before replacing anything.

## SAFETY AND LOCAL STATE

- Target macOS on Apple Silicon unless asked otherwise. Prefer the `dot` CLI, never bare Stow.
- Edit files under `stow/`, not symlink targets in HOME. Do not stage or commit unless asked.
- Never track or stow tokens, auth, private keys, private identities, histories, sessions,
  logs, caches, sockets, downloaded plugins, or machine-local secrets. Never print sensitive
  auth or local identity values while debugging or reporting diagnostics.
- Each `stow/<package>/` mirrors HOME. `dot-*` names become hidden files.
  `STOW_PACKAGES` deploys with `--dotfiles --no-folding`.
  Git ignores do not affect Stow. Keep runtime state physically outside packages.
  Shared Stow exclusions cover `node_modules`, `.DS_Store`, and private Git paths.
- Keep gh `hosts.yml`, OpenCode `service*.json`, Herdr `plugins/`, `plugins.json`,
  `.plugins.lock`, and Rex generated state local. Codex config stays local too:
  `stow/codex/` contains ignore policy only.
- Public Git defaults belong in `stow/git/.config/git/config`, which includes
  `~/.config/git/local.conf` last. Private profiles belong there and under `~/.config/git/extras/`.
  Keep work name, email, and signing key together. Keep private paths in Git and Stow ignores
  and out of `stow_sources`. Preserve signing behavior.
- Use Homebrew's CA bundle. Never modify Apple's system bundle or disable TLS verification.
- Runtime policy holds install rules, never auth. Keep release-age overrides scoped to a command.
  Never relax the global policy. Use Socket Firewall for package-manager installs
  (`sfw pnpm install`, `sfw npm install`, etc.). Only standalone pnpm and sfw bootstraps are exempt.
- Use HOME, repo-relative paths, or existing helpers instead of hardcoded user paths.
  Do not create nested Git repositories or unmanaged dependency installs inside Stow packages.
- Do not reintroduce tmux, skhd, lazygit, wezterm, Neovim configuration, or custom alias/function
  files unless requested. Do not add Linux setup or casks in `packages/bundle.work` unless asked.

## FEATURE CONSTRAINTS

Read the relevant feature reference before changing its behavior. These constraints also apply:

- Homebrew: use `dot brew add/remove` first. Each package belongs to one bundle and base stays enabled.
  Preserve `packages.brew.<group>.enabled` keys. Selection never installs or uninstalls.
  Remove changes declarations only. Uninstall refuses declared packages and active apps or services.
  Unattended installs fail on unset choices, even with `--yes`. Reports never prompt or change
  preferences. Never add automatic cleanup or delete user data.
- Pi: Git allow-lists customizations. Expect Pi to rewrite `settings.json`.
  Never include credentials or local development package paths. Re-add local packages with `pi install`.
- OpenCode v2: register `@luxass/opencode-voice` once in `opencode.jsonc`'s `plugins` array,
  not `cli.json`. Never run `opencode service set ...` automatically: it stops the server.
  Restart OpenCode after configuration or plugin edits.
- Rex: install only when missing, from the Bleeding Edge appcast, after signature, team ID,
  bundle ID, and notarization checks. Never replace, launch, or restart an existing app.
  Rex's updater owns updates. Keep Remote Control enabled and import missing themes with
  `init.lua`'s `import_*` actions. Preserve terminfo and missing-skill setup offers.
  Keep generated theme IDs, the registry, `ssh_config`, and `terminfo-hosts` local.
  Do not bind a theme shortcut or add Neovim or Twitch integration.
- Herdr: preserve `prefix+m` for zoom, `prefix+o` for document review, and `prefix+i` for
  notifications. Never stop a running server.
- Fish: Fisher installs declared `fish_plugins` outside the repo. Never commit plugin files,
  `fish_variables`, or generated completions.
- Cua Driver: ask before stopping a running daemon and warn about interrupted computer-use
  sessions. Abort if it does not stop. Stow never installs or launches it.
  The human approves macOS permission dialogs.
- Mise: never pin global runtime versions here. Node.js stays with pnpm unless explicitly migrated.
- Skills: use `sfw pnpx skills add/list/update/remove -g`. There is no `dot skills` command.
  Explicit links, not Stow, manage shared skills and their tracked native lock.
  Never clear the lock during stow. Edit only locally maintained skills.
  Before adapting imports, remove their lock entry without deleting files.
  Exception: keep Cua Driver's lock entry and limit local edits to `LOCAL.md` and the read-first
  note in `SKILL.md`. Restore those after updates. Commit or stash edits before CLI updates.
  Record upstream SHAs in import/update commit messages when known.

## VALIDATION

- `dot lint` must pass. Shellcheck and shfmt are pinned in `.mise.toml` and run through
  `mise exec`. Run `mise trust` once per machine. Style comes from `.editorconfig`
  and `.shellcheckrc`.
- Run `dot doctor` after setup behavior changes. Use `dot info` for paths, runtimes, and status.
- `dot hooks` installs the tracked pre-push hook and repo filters. The hook runs
  `dot secret-scan` and `dot lint`. CI also tests Stow link/unlink into an empty HOME
  without installing plugin dependencies.
- The secret scanner never prints values. It skips ignored files, submodules, and history.
  Execution errors must fail the command. Reviewed exceptions in `.secret-scan-allowlist`
  match an exact source-line SHA-256 plus path. Never use whole-file or directory exclusions.
- Stow backs up blocking paths under the local dot state directory's `backups/<timestamp>/`.
  See [Stow](lib/features/stow.md) for locations and state recovery.
