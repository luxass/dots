# mpl_render (by Dillon Mulroy)

This extension is Dillon Mulroy's work, copied from his dotfiles:

- Source: [dmmulroy/.dotfiles `home/.pi/agent/extensions/mpl`](https://github.com/dmmulroy/.dotfiles/tree/b20510f297db5b0e91738f8a94220f8fd26bab72/home/.pi/agent/extensions/mpl)
  at commit `b20510f` (last changed in `3c2767d`, 2026-11-23).
- Author: [Dillon Mulroy](https://github.com/dmmulroy).

Credit and thanks to Dillon. To update, copy the folder from his repository again and keep this README.

Every file except this README is unchanged, with one exception. `package.json` pins mpl to the
latest upstream commit, `github:ivarvong/mpl#8befb5c`, instead of Dillon's fork at `54651f9`.
His fork pin was the head of [ivarvong/mpl#108](https://github.com/ivarvong/mpl/pull/108), which
was merged upstream on 2026-11-23. His `AGENTS.md` says to re-pin to upstream after that merge.

The chart library is [mpl](https://github.com/ivarvong/mpl) by Ivar Vong, ISC license.

## Differences in this repository

Dillon's `home/.pi` is an npm workspace. Here it is a pnpm workspace, `stow/pi/.pi`:

- `pnpm-workspace.yaml` lists `agent/extensions/*` as workspace packages. It allows mpl's build
  script for the pinned commit only, and denies esbuild's install check.
- Pi loads an extension from its real path in the repository, so dependencies install in
  `stow/pi/.pi`, not in `~/.pi`. Git and Stow ignore the `node_modules` folders.
- mpl builds itself in its `prepare` script. pnpm runs that build with npm, which reads
  `ignore-scripts=true` from `~/.npmrc`. `dot init --only pi` allows scripts for that one install.
  A plain `pnpm install` installs mpl without its build. `dot doctor` reports that.
- Dillon's tests import `typebox`, which his `home/.pi/package.json` lists. Ours does not, so
  `test/mpl.test.ts` does not run here yet. Pi provides `typebox` to the extension at runtime.

The paths in `AGENTS.md` (`home/.pi`, `npm run check`) are Dillon's.
