# Pi

Public [Pi customizations](../../stow/pi/.pi/agent/) are linked into ~/.pi/agent/.
Auth, trust, sessions, logs, caches, and downloaded packages stay outside the checkout.
Shared skills use the [shared collection](skills.md), not duplicate Pi copies.

## Update Pi

Dot update runs Pi's native self-updater, then offers extension package updates after restowing.
Both updates use a one-command release-age exception. Other installs keep the normal policy.
Managed global tools are declared in [paths.sh](../core/paths.sh).

Pi discovers linked extensions at startup. Do not commit local development package paths
in settings.json. Re-add them on each machine with pi install.
Dot hooks configures a Git clean filter that removes lastChangelogVersion from staged
settings content. Pi can keep writing the key locally. Doctor warns if the filter is missing.
For native computer use, see [Cua Driver](cua.md).

## Review with Plannotator

Pi declares its review package in [settings.json](../../stow/pi/.pi/agent/settings.json).
OpenCode declares its package in [opencode.jsonc](../../stow/opencode/.config/opencode/opencode.jsonc).
Starting either host can download declared packages. Restart hosts after installation.

Use these host commands once installed:

- /plannotator-review opens code review.
- /plannotator-annotate <file.md> opens a document.
- /plannotator-last opens the last response.

In Pi, /plannotator-plan-mode toggles planning restrictions until approval.
Shared [review preferences](../../stow/plannotator/.plannotator/config.json) select unified diffs,
wrapped lines, hidden whitespace changes, and focused feedback.
Reviews and credentials remain local and outside Git and Stow.

Terminal reviews use Herdr Annotate and its bundled plannotator-tui.
Its [preferences](../../stow/plannotator/.config/plannotator-tui/config.toml) select a full-tab overlay.
Browser reviews do not require the Herdr plugin. No extra command files are needed.

## Appearance

Pi follows its host terminal with Catppuccin Macchiato in dark mode and Latte in light mode.
Restart Pi to load the theme pair. Ghostty follows macOS appearance.
