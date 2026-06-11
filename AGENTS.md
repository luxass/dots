# Agent Notes

This is a personal macOS dotfiles repository.

- Keep the repo public-safe: no tokens, auth files, shell histories, or private
  Git identity values.
- Keep platform assumptions macOS-only unless explicitly asked otherwise.
- Prefer the existing `dot` CLI over ad hoc commands for setup, package checks,
  symlink checks, and diagnostics.
- Run `dot doctor` after behavior changes.
- Use GNU Stow semantics. Files under `home/` map to `$HOME`; `dot-*` names map
  to hidden files through `stow --dotfiles`.
- Do not reintroduce removed configs such as Neovim, tmux, skhd, lazygit, k9s,
  wezterm, or custom alias/function files unless explicitly requested.
- Keep personal Git identity in `~/.gitconfig.local`, not in tracked files.
