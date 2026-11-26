# Homebrew packages

Install Homebrew by hand first. If it is missing, dot prints the official install command.
Package declarations live in two Brewfiles in [packages/](../../../packages/):

- packages/bundle is the base list. Every machine installs it.
- packages/bundle.work is the work list. It takes formulas only. Casks belong in the base list.

## Install and update

Dot init runs brew bundle for the base list. Brew bundle can also upgrade listed packages
that are outdated. Then dot init asks whether to install the work list. The default is no.
Dot does not save the answer, so it asks again on each run.

Dot update runs brew update, then upgrades every outdated Homebrew package without asking.
This includes packages that are not in a list. Use dot update --skip packages to skip it.

Homebrew's automatic cleanup and autoremove stay off for every change dot makes.
Dot never runs brew cleanup.

## Manage packages

Use dot package help for full syntax:

```fish
dot package list
dot package add ripgrep
dot package add docker cask
dot package add kubectl brew work
dot package remove docker
dot package update all base
```

- add installs the package, then adds it to a list in sorted order. A failed install leaves the list unchanged.
- remove takes the package out of the lists, then asks before uninstalling it. The default is no.
- update upgrades one package, one list, or every outdated package.

The type is detected when you omit it. If a name matches both a formula and a cask,
detection picks the formula, so pass cask to add the cask.

## Inspect package state

```fish
dot check-packages
dot retry-failed
```

Check-packages reports installed and missing packages for each list.
Doctor warns about missing packages but does not fail for them.
If packages fail during dot init, dot records them in failed-packages/ under the local
dot state directory. The default is ~/.local/state/dot/failed-packages/. It is never in Git.
Retry-failed installs them again and records the packages that still fail.
