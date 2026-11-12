# Rex

Rex is not installed through Homebrew. Dot init offers a missing-app installation from
the Bleeding Edge appcast defined in [paths.sh](../core/paths.sh).
It validates the signature, team ID, bundle ID, and notarization before installing.
It never replaces an existing app. Rex updates itself. Dot never launches or restarts it.
The [official guide](https://www.superlogical.com/rex/docs/installation) is the fallback.

## Link configuration and themes

Launch Rex once to install its bundled CLI, then run dot stow.
[init.lua](../../stow/rex/.config/rex/init.lua) defines shortcuts and theme import actions.
[macos-defaults.conf](../../stow/rex/.config/rex/macos-defaults.conf) defines app preferences.
The theme pair uses Catppuccin Macchiato and Latte and follows macOS appearance.
Rex and Ghostty use Monaspace Krypton at size 14 without ligatures.

Dot stow links files, reloads Lua if Rex is running, and writes app preferences.
Remote Control stays enabled for rex do actions.
Missing themes are imported through import_catppuccin_macchiato and import_catppuccin_latte.
Generated theme IDs and the imported registry stay local. Already imported files are skipped.
If Rex is stopped, launch it and run dot stow again, or use the palette import actions.
Existing app preferences are backed up in the local dot backup directory.
Relaunch Rex to apply font, sidebar, and appearance preferences.

## Set up SSH and agent integration

Dot stow offers rex terminfo setup. It installs xterm-rex under ~/.terminfo,
writes ~/.config/rex/ssh_config, and adds an Include line to ~/.ssh/config.
The guard uses xterm-256color for hosts without xterm-rex. Generated files stay local.
Use rex terminfo remove to undo setup.

If the skill or hook is missing or outdated, dot stow offers rex skill setup.
This writes the shared skill stub and ~/.claude/settings.json, which are tracked.
Review the diff before committing. Doctor warns, rather than fails, for missing setup.

## Change shortcuts

The prefix is Ctrl+B. Split, zoom, resize, session, and tab shortcuts follow Herdr.
Detach shortcuts close the window, not the server. Prefix+v opens Find.
Herdr Annotate and agent/worktree navigation have no mapped equivalents.
Do not bind a theme shortcut or add Neovim or Twitch integration.

After Lua edits, run:

```fish
rex config check
rex config reload
```

Rex does not watch the file. Fish adds the bundled CLI to PATH and prefers
the running server's CLI inside Rex.
