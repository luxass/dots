# dot

`dot` sets up, updates, and checks this Mac from the repository. It is Bash,
split into small files. It runs on the macOS system Bash (3.2) and needs no
managed language runtime.

```fish
dot init                    # install everything (new Mac)
dot update                  # pull the repository, then update everything
dot doctor                  # check everything; exits 1 on critical problems
dot components              # what dot manages, in run order
dot update --only rex,pi    # init, update, or doctor for some components
dot init --dry-run          # print the plan, change nothing
```

`dot help` lists every command. `dot <command> --help` shows its options.

## How it works

Everything `dot` sets up is a component: one file in
`lib/components/<name>.sh` with up to three steps.

| Step | Run by | Rule |
| --- | --- | --- |
| `component_<name>_install` | `dot init` | Required. Must be safe to run again: skip what is already there. |
| `component_<name>_update` | `dot update` | Optional. When it is missing, update runs install. |
| `component_<name>_check` | `dot doctor` | Required. Prints ✓, ⚠, or ✗ lines. Returns 1 only for real problems. |

`init`, `update`, and `doctor` walk the same ordered list
(`DOT_COMPONENT_ORDER` in `lib/component-registry.sh`). A tool cannot be
installed by `init` and then forgotten by `update` or `doctor`.

```text
dot init     -> for each component: install   (stop at a failed required one)
dot update   -> git pull (restart if dot/ changed) -> for each component: update
dot doctor   -> for each component: check     (exit 1 if a required one fails)
                then a summary table: ✓ ok, ⚠ warnings, ✗ failed
```

Each component is `required` or `optional`. A failed required step stops
`init` and `update`, and a failed required check fails `doctor`. Optional
components warn and continue. `dot components` shows the table.

`init` and `update` take a run lock in the local dot state directory
(`~/.local/state/dot/run.lock`), so two runs never change the Mac at the same time.

## Layout

```text
dot/
├── bin/dot                    # entry point: finds the repository, loads lib/, runs dot_main
├── lib/
│   ├── dot-lib.sh             # loads everything below in order
│   ├── dot-main.sh            # global options, command list, dispatch
│   ├── paths.sh               # repository paths and managed versions
│   ├── terminal-output.sh     # print_*, confirm, no_args
│   ├── file-links.sh          # backup_path, ensure_link, check_link
│   ├── dotfiles-repo.sh       # repo_git
│   ├── run-lock.sh            # acquire_run_lock, release_run_lock
│   ├── package-lists.sh       # packages/bundle and bundle.work: read, add, remove
│   ├── package-manager.sh     # Homebrew install, upgrade, uninstall, list
│   ├── migrations.sh          # one-time cleanups for older setups
│   ├── component-registry.sh  # define_component, DOT_COMPONENT_ORDER, --only/--skip
│   ├── component-runner.sh    # run_component_phase install|update|check, summary
│   ├── components/<name>.sh   # one per component, with <name>.md beside it
│   └── *.bats                 # tests, next to the code they cover
├── commands/<command>.sh      # cmd_<command> and cmd_<command>_usage (dashes become _)
└── tests/test-helpers.bash    # shared bats setup: a temporary HOME
```

Sourcing `dot/bin/dot` defines every function and runs nothing. The bats tests use that.

## Add a component

1. Create `lib/components/<name>.sh`:

   ```bash
   # shellcheck shell=bash
   # Zoxide: what it is and anything surprising about how it is installed.
   define_component zoxide optional "zoxide"

   component_zoxide_install() {
     if command_exists zoxide; then
       print_success "zoxide is installed"
       return 0
     fi
     brew_without_cleanup install --formula zoxide
   }

   component_zoxide_check() {
     if command_exists zoxide; then
       print_success "zoxide"
     else
       print_warning "zoxide is missing; run 'dot init --only zoxide'"
     fi
   }
   ```

2. Add `zoxide` to `DOT_COMPONENT_ORDER` in `lib/component-registry.sh`, after
   whatever it needs.
3. Run `dot lint`. The registry tests fail when a component file is not in the
   order list or a step is missing.

A plain Homebrew package is not a component: run `dot package add <name>`.

## Add a command

Create `commands/<command>.sh` with `cmd_<command>` and `cmd_<command>_usage`.
Add a line to `DOT_COMMAND_SUMMARIES` in `lib/dot-main.sh`, and add it to
`stow/fish/.config/fish/completions/dot.fish`. The CLI tests fail when a
listed command has no `--help`.

## Tests

`dot lint` runs shellcheck, shfmt, and every `*.bats` file at the versions
pinned in `.mise.toml`. The pre-push hook and CI run it. CI also links the
stow and skills components into an empty HOME, checks them, and unlinks them.
