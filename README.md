# dots

Personal macOS dotfiles managed with GNU Stow and a small `dot` CLI.

## Overview

This repository contains a reproducible macOS development setup. Files under
`home/` mirror `$HOME`, packages live in `packages/`, and `dot` handles setup,
maintenance, package checks, symlinks, and public Git identity configuration.

The repo is intentionally small: Fish, Git, Ghostty, Homebrew packages,
and JavaScript runtime policy. It does not try to manage Linux, Neovim, tmux,
or other configs that are not currently wanted.

## Key Features

- One-command setup through `./dot init`
- GNU Stow symlink management from `home/` to `$HOME`
- Homebrew bundles with optional per-machine groups (fonts, work, personal)
- Homebrew-installed mise with Fish activation for project and language runtimes
- Standalone pnpm 12 with pnpm-managed Node.js and npm 12
- Managed pnpm global tools, including Socket Firewall (`sfw`)
- Public Git settings and identity in `home/.config/git/config`
- Tracked pre-push hook that runs secret scanning before publishing
- npm, pnpm, and Bun install policy for build approvals and release age checks
- Diagnostics for required tools, package state, managed links, and secrets
- shellcheck and shfmt linting for the `dot` CLI itself

## Quick Start

```sh
git clone git@github.com:luxass/dots.git ~/dots
cd ~/dots
./dot init
```

Run `dot` directly from the repository by keeping `~/dots` on your PATH.
If needed, run `fish_add_path ~/dots` once in Fish. Setup does not create a
second CLI link in `~/.local/bin/`.

## Repository Structure

```text
~/dots/
├── dot                 # CLI entrypoint: loads lib/ and runs main
├── lib/
│   ├── core/           # Output, prompts, paths, preferences, links, dispatch
│   ├── features/       # One file per managed thing, with setup and check hooks
│   └── commands/       # The CLI surface: cmd_* functions
├── home/               # Files stowed into $HOME
│   ├── .codex/         # Ignore policy only; Codex config stays local
│   ├── .config/
│   │   ├── fish/
│   │   ├── ghostty/
│   │   ├── git/         # Public Git settings and identity
│   │   ├── opencode/
│   │   └── pnpm/
│   ├── .npmrc          # Public npm policy only; no auth
│   ├── .pi/            # Lean Pi agent config (settings, keybindings, notes)
│   └── dot-gitignore   # Stowed as ~/.gitignore via --dotfiles
├── packages/
│   ├── bundle          # Base Brewfile
│   ├── bundle.fonts    # Optional font casks
│   ├── bundle.personal # Optional personal-only Brewfile
│   └── bundle.work     # Optional work-only Brewfile
├── AGENTS.md           # Notes for AI/code agents
└── README.md
```

## Commands

Global options: `-v` / `--verbose` prints extra diagnostics, and `-y` /
`--yes` answers yes to confirmations. Without a terminal, prompts use their
default answer.

```sh
dot init             # install packages, link dotfiles, set up runtimes and hooks
dot update           # pull, update Pi, offer pnpm/Homebrew/Pi extension upgrades, relink
dot stow             # link home/ and install plugin dependencies
dot unstow           # remove stowed symlinks
dot doctor           # check every feature, including a secret scan
dot info             # show paths, runtime versions, and git status
dot secret-scan      # scan tracked and unignored files for secrets
dot lint             # run shellcheck and shfmt on dot itself
dot package ...      # Homebrew packages (see below)
dot config ...       # local-only preferences
dot hooks            # point Git at .githooks
```

## Package Management

The base package list is `packages/bundle`. Fonts live in
`packages/bundle.fonts`, optional work-only packages in `packages/bundle.work`,
and personal-only packages (installed only on machines that opt in) in
`packages/bundle.personal`. `dot init` prompts for optional groups only when
their local preference is unset. Answers are saved under XDG state so future
runs know whether fonts, work, or personal packages are enabled or
intentionally skipped.

```sh
dot package list [GROUP]                   # every package and whether it is installed
dot package check                          # only what is missing
dot package add NAME [--cask|--formula] [--group GROUP]
dot package remove NAME [--group GROUP]
dot package unmanaged                      # installed but not in any bundle
dot package update [NAME]
```

`add` detects whether NAME is a formula or a cask (pass `--cask` or
`--formula` when it is both), writes the entry with `brew bundle add`, keeps the
Brewfile sorted under its header comment, and installs it when the group is
enabled on this machine. `remove` uses `brew bundle remove` and then offers to
uninstall. `brew bundle install` keeps going past a failed package and reports
it at the end; run `dot package check` afterwards to see what is missing.

## Local-Only Configuration

Machine-local dot preferences are stored outside the repo at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dot/preferences
```

The file uses git-config format. Manage it with:

```sh
dot config list
dot config get packages.brew.fonts.enabled
dot config set packages.brew.fonts.enabled true
dot config unset packages.brew.fonts.enabled
dot config reset
dot config help   # lists every known key
```

Known keys:

```text
packages.brew.fonts.enabled
packages.brew.work.enabled
packages.brew.personal.enabled
```

Unset keys are asked about once, interactively, when `dot` needs them.

## Git Identity

Git reads the tracked configuration from `~/.config/git/config`. It contains
the public name, email, and SSH signing public key. Private keys and credentials
stay outside this repository. The 1Password SSH signing program and automatic
commit signing remain enabled.

To change the public identity, edit `home/.config/git/config` directly.

For 1Password SSH signing, enable the 1Password SSH agent and use:

```sh
ssh-add -L
```

Set `user.signingkey` to the relevant public key. Do not copy a private key,
credential, or work-only identity into the tracked file. Review the diff before
committing.

The old `~/.gitconfig.local` identity was merged by copying only the public
name, email, and signing key. The original file was moved to
`${XDG_STATE_HOME:-$HOME/.local/state}/dot/backups/<timestamp>/.gitconfig.local`.
The tracked configuration no longer includes it. Setup does not import local
identity files automatically.

`dot doctor` checks the configuration link, required public name and email,
and global identity overrides. Keep work-only identity in a separate local
repository configuration, never in the tracked file.

Git uses Homebrew’s `ca-certificates` bundle through `http.sslCAInfo` in
`home/.config/git/config`. These dots target Apple Silicon, so the path is
`/opt/homebrew/etc/ca-certificates/cert.pem`. Homebrew updates the bundle in
place. `dot doctor` checks the bundle and the global Git setting. This leaves
Apple’s system certificate files unchanged and does not change curl or Python.
Repository settings and environment variables can override the global setting.

`dot stow` backs up the old managed `~/.gitconfig` symlink before linking the
new location. It leaves independent `~/.gitconfig` files unchanged. Git reads
those files too, and their values can override `~/.config/git/config`.

## Shell

Fish is the primary interactive shell. The tracked Fish config keeps a small
`config.fish` plus modular `conf.d/*.fish` style:

- `home/.config/fish/config.fish` stays small.
- `home/.config/fish/conf.d/*.fish` contains environment, paths, Homebrew,
  Starship, Zoxide, Direnv, pnpm, Bun, and OrbStack setup.
- `home/.config/fish/completions/` contains Fish completions.
- `home/.config/fish/fish_plugins` lists Fisher plugins (currently
  `jhillyerd/plugin-git`, which adds oh-my-zsh style git abbreviations such as
  `gst` and `gco`). `conf.d/fisher.fish` installs them to
  `~/.local/share/fisher` instead of the folded `~/.config/fish`, so plugin
  files never land in the repo. `dot init` and `dot stow` install missing
  plugins, `dot update` updates them, and `dot doctor` checks them.

`dot init` installs Fish through Homebrew, adds it to `/etc/shells` when needed,
and sets it as the login shell with `chsh`. Restart the terminal after the
change.

## Git Hooks

`dot init` installs repository hooks by setting:

```sh
git config core.hooksPath .githooks
```

The tracked `pre-push` hook runs:

```sh
dot secret-scan
dot lint
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

These require packages to be at least five days old before installation. npm
and Bun disable lifecycle scripts. pnpm denies unreviewed builds and keeps the
release-age exception for OpenCode plugin packages. Auth tokens must stay out of
the repo.

`mise` is installed from the base Homebrew bundle and activated automatically
in Fish by `home/.config/fish/conf.d/mise.fish`. Use `mise use` in a project to
select a runtime and record its version in `.mise.toml`. Node.js is managed by
pnpm and defaults to the latest Node 24 release. `dot update` offers Node updates
within that release line; it does not move to the next major automatically.
Restart Node.js applications after updating. Project-specific runtimes, containers,
and bundled Node copies need separate updates. Do not select a competing Node.js
version with mise unless you intend to migrate that ownership.

`dot init` stows these configs before installing standalone pnpm 12, the
pnpm-managed Node.js runtime, npm 12, or pnpm global tools, so package-manager
policy is active during setup.

`dot doctor` verifies that `pnpm`, `node`, `npm`, `pi`, and other managed global
commands resolve from `PNPM_HOME`. It checks that OpenCode is installed through
Homebrew and checks the tracked npm, pnpm, and Bun policy files.

`dot init` installs managed pnpm globals:

```text
sfw
npm 12
pi (@earendil-works/pi-coding-agent)
cf
coderabbit
```

Global CLI installs go through `sfw pnpm add -g`.

OpenCode v2 is installed from `anomalyco/tap/opencode-v2` through
`packages/bundle`. `dot update` runs Pi's native self-updater, which detects
how Pi was installed and updates it directly. Homebrew upgrades use the usual
package prompt. Before installing the base Brewfile, setup or update removes
any installed formula or cask listed in `BREW_PACKAGE_REPLACEMENTS` in
`lib/core/migrations.sh`. This migrates the old `opencode` formula to `opencode-v2`.
Setup or update also removes the old pnpm-managed OpenCode package if found.

Socket Firewall can be used by prefixing supported package-manager commands:

```sh
sfw pnpm install
sfw npm install
```

## OpenCode

Global OpenCode config is tracked under `home/.config/opencode/` and stowed to
`~/.config/opencode/`.

Tracked files include:

- `opencode.jsonc` for shared global OpenCode settings.
- `plugins/notification.ts`, a small AppleScript notification plugin that fires
  when a session becomes idle.
- `package.json` and `pnpm-lock.yaml` for TypeScript plugin types.

Keep `node_modules/` local-only. It is ignored by Git and by Stow through
`home/.stow-local-ignore`, but can exist in the source tree for editor/type
resolution. `dot stow` and `dot update` install or refresh plugin dependencies
with Socket Firewall (`sfw pnpm install` in `~/.config/opencode/`), and
`dot doctor` verifies that
`@opencode/plugin` is installed. Manual refresh is still available:

```sh
cd ~/.config/opencode
sfw pnpm install
```

Restart OpenCode after changing `opencode.jsonc`, `cli.json`, or plugin files;
running sessions keep the config and plugin code loaded from startup.

OpenCode v2 registers `@luxass/opencode-voice` in the `plugins` array in
`opencode.jsonc`. Use the plural `plugins` key. OpenCode loads the package's
terminal UI component in the local client. Its server component does no work.
Do not also register Voice in `cli.json`. That file is an alternative for
client-only plugins that must stay available with a different server.

Restart OpenCode, then run `/voice setup`. Choose an API profile because local
transcription is currently unsupported on Bun. Keep API keys in environment
variables, not tracked configuration. No private submodule or private
dependency install is needed.

OpenCode's internal npm resolver reads the global npm release-age policy.
Server plugins install and update in its background server. A CLI environment
override alone does not change the policy of an existing server.

Close active OpenCode sessions before this one-time command. It stops the
background server and sets its npm release age to zero for future starts:

```sh
"$(brew --prefix opencode-v2)/bin/opencode" service set env NPM_CONFIG_MIN_RELEASE_AGE 0
```

The setting applies only to OpenCode. Keep `service.json` and `service-*.json`
local because they can also contain passwords and private remote URLs. Git
and Stow ignore them. Reopen OpenCode after the command.

`dot update` offers to run OpenCode's native `plugin update`, like the Pi
extension update step. It uses the managed Homebrew binary and a temporary
`NPM_CONFIG_MIN_RELEASE_AGE=0` override for CLI-only plugin updates. It checks
the server setting first and does not stop or reconfigure a running server.
Local plugin files and pinned package revisions remain unchanged.

`dot stow` and setup also bypass the age filter for the tracked local OpenCode
plugin dependencies. Normal cached-plugin sessions need no special launcher.
Unrelated npm and pnpm installs keep the five-day policy.

Stow backs up leftover links from the retired private plugin setup. Other local
plugins are left alone.

## Pi

Pi (`@earendil-works/pi-coding-agent`, binary `pi`) is installed as a managed
pnpm global. `dot update` runs Pi's native self-updater, then offers to update
installed Pi extension packages after restowing. Both Pi update commands use a
one-command pnpm release-age override; other pnpm installs keep the five-day
age rule.

- The binary is managed through `PNPM_GLOBAL_PACKAGES` in `lib/core/paths.sh` and
  installed with Socket Firewall (`sfw pnpm add -g`).
- Public Pi extensions live under `home/.pi/agent/extensions/` and are stowed
  to `~/.pi/agent/extensions/`. Pi discovers them automatically at startup.
- Auth, trust, sessions, logs, caches, and packages stay local through
  `home/dot-gitignore`. Shared Agent Skills live under `home/.agents/skills/`
  and are not duplicated here.

### Computer use

`home/.pi/agent/mcp.json` declares Cua Driver as the `computer` server through
[Pi's native MCP support](https://pi.dev/docs/latest/mcp). No MCP adapter
extension is needed. Tools use `codemode` exposure and the
`mcp__computer__` prefix. The driver starts with standard permissions, without
existing-browser-profile access or approval bypasses.

`dot init` installs Cua Driver through its official stable
[macOS installer](https://cua.ai/docs/cua-driver/quickstart). The installer
places the signed `CuaDriver.app` in `/Applications` and its CLI in
`~/.local/bin`. It does not edit shell startup files. The upstream skill pack
is imported separately through `sfw pnpx skills` and tracked in this repo.

`dot init` offers to open the macOS permission flow, including for an existing
installation. You approve Accessibility and Screen Recording permissions
yourself. If you decline, run it later:

```sh
cua-driver permissions grant
cua-driver doctor
```

Once the configuration is linked and the driver is installed, run
`pi mcp list` to test the connection. In an existing Pi session, run `/reload`
and inspect `/mcp`. Cua Spaces and a VM are not required.

`dot update` checks for Cua Driver releases and offers its native updater.
If its daemon is running, dots asks before stopping it and warns that connected
computer-use sessions will be interrupted. If the daemon does not stop or
restarts immediately, the update fails without running the installer.
Reconnect Pi afterward. The native updater preserves the selected release
channel. A replacement signing identity can require permission grants again,
so dots also offers the permission flow after an update. Declining that offer
leaves the installation intact. `--yes` accepts these offers, but cannot approve
macOS dialogs for you.

`dot doctor` checks the CLI, app signature, daemon, and permissions without
starting the daemon or opening permission prompts. A stopped daemon produces
a warning because its permissions cannot be read reliably. `dot stow` only
links the Cua configuration and skill. It does not install or launch Cua.

The upstream skill pack at `home/.agents/skills/cua-driver/` is pinned to
`cua-driver-rs-v0.36.0` in the native skills lock. Manage it through
`sfw pnpx skills`. Local integration rules live in `LOCAL.md` alongside the
pack. A read-first note in `SKILL.md` tells agents to load that file. These are
the only local additions to the upstream pack. Commit or stash local changes
before a skills CLI update. Afterward, review the diff and manually restore
`LOCAL.md` and the note if overwritten. Do not rely on the CLI to preserve them
automatically. Keep the native lock entry as upstream provenance.

Use Cua for browser and native GUI work. Keep ordinary file and command-line
tasks on their existing tools. Ask before visible desktop takeover unless the
task already authorizes it.

## Plannotator

Pi declares `npm:@plannotator/pi-extension` in `home/.pi/agent/settings.json`.
OpenCode v2 declares `@plannotator/opencode@latest` in the plural `plugins`
array in `home/.config/opencode/opencode.jsonc`. Its `plan` agent can submit
plans for browser review. These declarations do not bundle installed packages.
Starting either host can download its declared packages.

Once the packages are installed, use `/plannotator-review` for code review,
`/plannotator-annotate <file.md>` for a document, or `/plannotator-last` for the
last response. In Pi, `/plannotator-plan-mode` toggles planning restrictions
until you approve the plan. Restart the hosts after installing the packages.

Shared review preferences live in `home/.plannotator/config.json`. They use
unified diffs, wrap long lines, hide whitespace changes, and keep reviewer
feedback focused on the requested corrections. Reviews and credentials stay
local and are excluded from Git and Stow.

Terminal reviews use Herdr Annotate, which bundles `plannotator-tui`. Its
preferences in `home/.config/plannotator-tui/config.toml` select a full-tab
Herdr overlay. Browser reviews do not require this plugin. No additional
command files or skills are required for the current Pi and OpenCode v2 plugins.

## Terminal themes and Rex

Ghostty, Herdr, Pi, and Rex use Catppuccin Macchiato in dark mode and
Catppuccin Latte in light mode. Ghostty and Rex follow macOS appearance.
Herdr and Pi follow their host terminal. Ghostty and Rex keep Monaspace
Krypton at size 14 with ligatures disabled. Pi loads the theme pair on its
next start. Herdr uses its `terminal` theme to inherit the host colors.
Herdr's own theme selector stays off because its appearance detection can
report light mode for a dark terminal ([upstream issue #3198](https://github.com/herdrdev/herdr/issues/3198)).
Terminal colors still follow the host's automatic appearance changes.

Install Rex manually using the [official installation guide](https://www.superlogical.com/rex/docs/installation).
If Rex is missing, `dot init`, `dot stow`, and `dot update` offer to open
the guide. Declining skips Rex setup without failing the command.
Launch Rex once to install its bundled CLI, then run `dot stow`.
`dot doctor` prints the installation link without prompting or opening it.
Dots does not install, update, launch, or restart Rex.
Its tracked configuration lives under `home/.config/rex/`:

- `init.lua` defines shortcuts.
- `macos-defaults.conf` defines app preferences and both theme names.
- `themes/` holds Macchiato and Latte in Ghostty format.

Import both files from `~/.config/rex/themes/` through Rex once on each Mac.
Run `dot stow` after the imports. It resolves each theme name to the local
ID that Rex generates. The IDs and imported theme registry stay out of Git.
If either import is missing, dots leaves app preferences unchanged and prints
the path to import. No theme shortcut or custom action is needed.

`dot stow` links the files, applies app preferences, and reloads Lua when
the Rex server is running. Existing app preferences are backed up under the
local dot backup directory before changes. Relaunch Rex to apply font,
sidebar, and appearance preferences. Dots leaves Remote Control unchanged.

The prefix remains Ctrl+B. Split, zoom, resize, session, and tab shortcuts
follow the Herdr configuration. The detach shortcuts close the Rex window,
not its server. Find replaces keyboard copy mode on `prefix+v`.
Herdr Annotate and agent/worktree navigation have no mapped equivalents.

Check Lua changes with `rex config check`, then apply them with
`rex config reload`. Rex does not watch the file. The Fish configuration
adds the bundled CLI to PATH and prefers the running server's CLI inside Rex.

## GitHub CLI

`home/.config/gh/config.yml` holds public preferences and aliases. Commands such
as `gh config set` and `gh alias set` change this tracked file after stowing.
Review these changes before committing. Keep private values out of this file.
Authentication in `hosts.yml` stays local and is excluded from Git and Stow.
The GitHub CLI setup keeps `~/.config/gh` as a local directory and links its
managed files, so new authentication files stay outside the repository.

`home/.config/gh/extensions.txt` lists `github/gh-stack` and `luxass/gh-zizmor`.
`dot init` and `dot stow` install missing extensions through Socket Firewall.
`dot update` offers updates for the listed extensions only. Versions are not
pinned. Removing a source does not uninstall it. Downloaded code stays local.
`dot doctor` checks the configuration link and missing extensions.

On a new Mac, run `gh auth login` to authenticate separately. Dots does not
copy credentials or log in for you. If `GH_CONFIG_DIR` or `XDG_CONFIG_HOME`
redirects GitHub CLI elsewhere, `dot doctor` reports the missing configuration
link. The managed location is `~/.config/gh/config.yml`.

## Herdr plugins

`home/.config/herdr/plugins.txt` declares the managed GitHub plugin sources.
`dot init` and `dot stow` install missing plugins through Socket Firewall.
`dot update` offers to update these sources. Removing a source does not
uninstall it, and setup does not re-enable a disabled plugin.
`dot doctor` checks that the sources are registered and the configuration is valid.

The list includes Herdr Annotate. Annotate bundles its own TUI, so no
separate Homebrew package is needed for these reviews. Plugin downloads, registry files, and local plugin configuration
remain outside Git and Stow. No plugin installation restarts the Herdr server.

After installing, reload the shortcuts with `herdr server reload-config`.
The prefix remains `Ctrl+B`. Press the prefix, then one of these keys:

- `a`: Comment on selected terminal text.
- `Shift+A`: Copy annotations as context.
- `Shift+M`: Manage annotations. Pane zoom remains `prefix+m`.
- `o`: Review documents in the current folder.
- `Shift+O`: Review the agent's recent replies.
- `i`: Open the notification target, moved from `prefix+o`.

Markdown `file://` links use Herdr's normal opener. To review a document,
use `prefix+o`. In a document review, select text, press `c` to comment,
and press `E` to send feedback to the agent. The shared `plannotator-tui` skill lets an agent open reviews too,
using the Herdr plugin when no standalone TUI executable is on `PATH`.

## Agent Skills

Use the upstream CLI directly. Dot only maintains these links:

```text
~/.agents/skills                         -> home/.agents/skills/
~/.claude/skills                         -> ~/.agents/skills/
~/.agents/.skill-lock.json               -> home/.agents/.skill-lock.json
$XDG_STATE_HOME/skills/.skill-lock.json   -> home/.agents/.skill-lock.json
```

The XDG link uses `~/.local/state` when `XDG_STATE_HOME` is unset. Both global
lock locations point to the same native lock. Stowing never clears its entries.
No alias or wrapper forces global scope.

```sh
sfw pnpx skills add <source> -g --skill <name> -a universal --copy
sfw pnpx skills list -g
sfw pnpx skills update -g
sfw pnpx skills remove <name> -g
```

Global operations change the shared files and lock inside this repo. Review and
commit the Git diff. Commit or stash edits before updating; the upstream CLI
can overwrite skill files and change agent-specific links.

Without `-g`, commands use project scope by default. Interactive `add` can
also ask you to choose a scope. Project installs in other repositories stay
there with their own `skills-lock.json`; they are not redirected into dots.
Running from `~` is a special case: project and global skill directories both
resolve to `~/.agents/skills`, but their lock files are still different. Use
`-g` to manage this shared collection.

### Re-register the existing external imports

The wrapper's project inventory has been removed. Existing skill files are
unchanged, and the native global lock starts empty. Re-add only the selected
imports below to populate their upstream/path/hash metadata. These commands
also refresh their contents from upstream; review the resulting diff.

```sh
sfw pnpx skills add cursor/plugins/pstack/skills -g -a universal --copy \
  --skill architect blast-radius bro how \
  principle-encode-lessons-in-structure principle-guard-the-context-window \
  principle-laziness-protocol principle-minimize-reader-load \
  principle-prove-it-works principle-subtract-before-you-add \
  tdd teach technical-writing typescript-best-practices unslop why

sfw pnpx skills add mattpocock/skills/skills/productivity -g -a universal --copy \
  --skill grill-me grilling
```

Both `tdd` and `teach` come from pstack in `cursor/plugins`, not Matt Pocock.
Do not restore the archived stale inventory; it contains intentionally removed
skills and incorrect upstreams.

Locally maintained/adapted skills remain in `home/.agents/skills/` without
entries in the global lock, so the CLI updater does not manage them. Currently
these are `commit`, `gh-stack`, `github`, `herdr`, `install-anti-slop`,
`tailscale`, and `writing-great-skills`. No separate local inventory is needed.
To keep an imported skill locally, remove its entry from the global lock without
deleting its files before editing it. Native `remove` deletes the files too.

The lock is public tracked content. Keep credentials, private sources, and
machine-local paths out of it. CLI prompt preferences and installation timestamps
may produce normal lock-file churn.

## CLI development

`dot` runs on the Bash 3.2 included with macOS. Runtime code must not depend on
newer Bash features or on Node.js, Python, Ruby, or another separately managed
language runtime.

The `dot` executable sources every file in `lib/core/`, `lib/features/`, and
`lib/commands/`, then calls `main`:

- `lib/core/` holds shared plumbing: output, prompts, paths and versions
  (`paths.sh`), preferences, link helpers, one-time migrations, and dispatch.
- `lib/features/<name>.sh` owns one managed thing (Homebrew, Stow, pnpm, Pi,
  OpenCode, and so on). A feature defines any of the hooks `<name>_prestow`,
  `<name>_poststow`, `<name>_deps`, `<name>_unstow`, and `<name>_check`, and is
  listed in `FEATURES` in `lib/core/paths.sh`. Removing a feature means deleting
  its file and its `FEATURES` entry.
- `lib/commands/` defines the CLI. `dot foo-bar` runs `cmd_foo_bar`.

Conventions: functions return their status explicitly (`|| return 1`) instead of
relying on `set -e`, warnings and errors go to stderr, and colors are off for
non-terminal output or when `NO_COLOR` is set. Style comes from `.editorconfig`
and `.shellcheckrc`; `dot lint` must pass. shellcheck and shfmt are pinned in
the repo's `.mise.toml` rather than the Brewfile, and `dot lint` runs them with
`mise exec`. Run `mise trust` in the repo once per machine. Run `dot doctor` after changes that
affect setup behavior.

## Troubleshooting

Run diagnostics first:

```sh
dot doctor
```

Run the publish safety scan:

```sh
dot secret-scan
```

Repair managed symlinks:

```sh
dot stow
```

`dot doctor` verifies managed symlinks as part of its diagnostics.

Check package drift:

```sh
dot package check
dot package unmanaged
```

`dot stow` moves anything in the way of a managed link to
`${XDG_STATE_HOME:-$HOME/.local/state}/dot/backups/<timestamp>/`.

## Safety

This repository is intended to be public-safe. Do not commit tokens, auth files,
shell histories, generated app state, machine caches, or private identity files.
