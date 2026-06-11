# dots

Personal macOS dotfiles.

The repo uses GNU Stow. Files under `home/` mirror `$HOME`, and `dot` is the
command wrapper for package install, linking, updates, checks, and bundle
package management.

## Install

```sh
git clone git@github.com:luxass/dots.git ~/dots
cd ~/dots
./dot init
```

## Commands

```sh
./dot init     # install Homebrew packages, back up conflicts, stow config
./dot stow     # restow home/
./dot unstow   # remove stowed links
./dot update   # pull, brew bundle, restow
./dot doctor   # dependency, link, package, and secret checks
./dot package  # list/add/remove/update Homebrew bundle entries
./dot link     # link dot into ~/.local/bin
./dot unlink   # remove the ~/.local/bin/dot link
./dot edit     # open the repo
```

`dot init` and `dot stow` move conflicting files into `backups/<timestamp>/`
before creating symlinks.

## Layout

```text
dot
home/
packages/bundle
```

## Safety

This repo is intended to be public-safe. Do not commit tokens, auth files,
shell histories, generated app state, or machine caches.
