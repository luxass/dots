# Pi

Public [Pi customizations](../../../stow/pi/.pi/agent/) are linked into ~/.pi/agent/.
Auth, trust, sessions, logs, caches, and downloaded packages stay outside the checkout.
Shared skills use the [shared collection](skills.md), not duplicate Pi copies.

## Update Pi

Dot init installs the extension dependencies in stow/pi/.pi, because Pi resolves extension imports
from their real path in the repository. Git and Stow ignore the node_modules folders.
To run only that step, use dot init --only pi. Do not run a plain pnpm install there: it skips mpl's build.
Dot update runs Pi's native self-updater, reinstalls those dependencies, then offers extension package updates.
Both updates use a one-command release-age exception. Other installs keep the normal policy.
Managed global tools are declared in [paths.sh](../paths.sh).

Pi discovers linked extensions at startup. Do not commit local development package paths
in settings.json. Re-add them on each machine with pi install.
Dot hooks configures a Git clean filter that removes lastChangelogVersion from staged
settings content. Pi can keep writing the key locally. Doctor warns if the filter is missing.
For native computer use, see [Cua Driver](cua.md).

## Draw charts

The codemode tool mpl_render draws matplotlib-style charts. It is
[Dillon Mulroy's extension](../../../stow/pi/.pi/agent/extensions/mpl/README.md), copied with credit.
Charts follow Pi's light or dark theme (Catppuccin Latte or Macchiato).
Files go to ~/.pi/agent/work/charts/<date>/, outside the repository.
Dot doctor checks that the mpl library is built.

## Search sessions

/find searches the current session, every branch. /find-all searches every session on this Mac.
It is [Dillon Mulroy's session-finder](../../../stow/pi/.pi/agent/extensions/session-finder/README.md),
copied with credit. Its index is ~/.pi/agent/cache/session-finder/index.sqlite, outside the repository.
The index is safe to delete; it rebuilds.

## Review with Plannotator

Pi declares its review package in [settings.json](../../../stow/pi/.pi/agent/settings.json).
OpenCode declares its package in [opencode.jsonc](../../../stow/opencode/.config/opencode/opencode.jsonc).
Starting either host can download declared packages. Restart hosts after installation.

Use these host commands once installed:

- /plannotator-review opens code review.
- /plannotator-annotate <file.md> opens a document.
- /plannotator-last opens the last response.

In Pi, /plannotator-plan-mode toggles planning restrictions until approval.
Shared [review preferences](../../../stow/plannotator/.plannotator/config.json) select unified diffs,
wrapped lines, hidden whitespace changes, and focused feedback.
Reviews and credentials remain local and outside Git and Stow.
Reviews open in the browser. No extra command files are needed.

## Appearance

Pi follows its host terminal with Catppuccin Macchiato in dark mode and Latte in light mode.
Restart Pi to load the theme pair. Rex follows macOS appearance.
