# OpenCode

OpenCode is installed through Homebrew. Public configuration and local plugins live in
[stow/opencode/](../../stow/opencode/.config/opencode/), linked into ~/.config/opencode/.
Keep service*.json local because it can contain passwords and private remote URLs.

## Refresh local plugins

Dot stow and dot update refresh tracked plugin dependencies through Socket Firewall.
For a manual refresh:

```fish
cd ~/.config/opencode
sfw pnpm install
```

Keep node_modules local and outside Stow links. Doctor checks the plugin types.
Restart OpenCode after editing configuration or plugins. Running sessions keep startup code loaded.

Voice is registered once in the plugins array of opencode.jsonc, not cli.json.
After restarting, run /voice setup and select an API profile.
Local transcription is unsupported on Bun. Keep API keys in environment variables.
No private plugin checkout is needed.

## Update downloaded plugins

Dot update offers OpenCode's native plugin update with a temporary CLI release-age override.
Pinned revisions and local plugin files remain unchanged.
The background server has its own environment. A CLI override does not change it.

If setup reports that the server release-age setting is missing, close active OpenCode
sessions before this one-time command. It stops the background server and disables
the age filter only for OpenCode's future server starts:

```fish
set opencode_binary (brew --prefix opencode-v2)/bin/opencode
$opencode_binary service set env NPM_CONFIG_MIN_RELEASE_AGE 0
```

Reopen OpenCode afterward. Dot never runs this service change automatically.
Tracked plugin dependency setup uses a scoped exception. Other installs keep the five-day policy.

For browser and terminal reviews, see [Plannotator](pi.md#review-with-plannotator).
