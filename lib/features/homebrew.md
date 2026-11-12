# Homebrew packages

Package declarations live in [packages/](../../packages/). Base is always enabled.
Fonts, work, and personal are optional bundles selected per machine.
Each package belongs to one bundle.

## Choose bundles

Use these commands to inspect and save choices:

```fish
dot brew bundle list
dot brew bundle enable personal
dot brew bundle disable work
```

These commands never install or uninstall packages. Setup asks for unset choices.
Unattended installation stops on unset choices, even with --yes.
Reports and doctor never prompt or change preferences.

Preferences stay outside the repo. Use dot config path to find the file.
Use dot config help for keys and commands. Resetting or unsetting a choice
makes it unresolved again. Invalid values and failed reads or saves are errors.

## Manage packages

Use dot brew help for full syntax. The important differences are:

- add declares a package and installs it if its bundle is enabled.
- remove changes the declaration only.
- uninstall refuses packages declared in any bundle, including disabled bundles.
- install installs missing enabled packages without requesting upgrades.
- update covers installed packages, including disabled bundles and undeclared packages.

Close active apps and stop services explicitly before uninstalling them.
If a name matches both a formula and a cask, specify --formula or --cask.
Review the upgrade preview. There is no automatic cleanup or removal of user data.
Homebrew can update dependencies required by a new installation.

## Inspect package state

```fish
dot brew list
dot brew check
dot brew unmanaged
```

Reports distinguish declarations, local selection, and actual installation.
Unmanaged packages include explicitly requested formulae and installed casks,
not dependency-only libraries. list GROUP reads only that bundle.
Check, doctor, and package changes validate all bundle declarations.
Read-only reports require jq. Fresh setup installs it after explicit choices
and Brewfile syntax checks.
