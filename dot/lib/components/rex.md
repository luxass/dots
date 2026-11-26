# Rex

Rex is not installed through Homebrew. Dot init offers a missing-app installation from
the Bleeding Edge appcast defined in [paths.sh](../paths.sh).
It validates the signature, team ID, bundle ID, and notarization before installing.
Dot looks for Rex by its bundle ID, the identifier inside the app, in `/Applications`
and `~/Applications`. The app name does not matter. Dot doctor warns if it finds more than one copy.
Dot never replaces an existing app. Rex updates itself. Dot never launches or restarts it.
Dot update only configures Rex. It never installs or updates the app.
The [official guide](https://www.superlogical.com/rex/docs/installation) is the fallback.

## Link configuration and themes

Launch Rex once to install its bundled CLI, then run dot update --only rex.
[init.lua](../../../stow/rex/.config/rex/init.lua) defines shortcuts and theme import actions.
[macos-defaults.conf](../../../stow/rex/.config/rex/macos-defaults.conf) defines app preferences.
The theme pair uses Catppuccin Macchiato and Latte and follows macOS appearance.
Rex and Ghostty use Monaspace Krypton at size 14 without ligatures.

Dot stow only links the files. The rex step in dot init and dot update checks init.lua,
reloads it if Rex is running, and writes app preferences.
Remote Control stays enabled for rex do actions.
Missing themes are imported through import_catppuccin_macchiato and import_catppuccin_latte.
Generated theme IDs and the imported registry stay local. Already imported files are skipped.
If Rex is stopped, launch it and run dot update --only rex again, or use the palette import actions.
Existing app preferences are backed up in the local dot backup directory.
Relaunch Rex to apply font, sidebar, and appearance preferences.

## Set up SSH and agent integration

The rex step in dot init and dot update offers rex terminfo setup.
It installs xterm-rex under ~/.terminfo, writes ~/.config/rex/ssh_config,
and adds an Include line to ~/.ssh/config.
The guard uses xterm-256color for hosts without xterm-rex. Generated files stay local.
Use rex terminfo remove to undo setup.

If the skill or hook is missing or outdated, the same step offers rex skill setup.
This writes the shared skill stub and ~/.claude/settings.json, which are tracked.
Review the diff before committing. Doctor warns, rather than fails, for missing setup.

The rex step also adds disable-model-invocation: true to the skill stub's front matter.
Agents then load the Rex skill only when asked, for example with /skill:rex.
Rex reports the edited stub as outdated, so doctor asks Rex about a copy without
that line in a temporary HOME. After rex skill setup rewrites the stub, the step adds
the line again.

## Transfer a Pi session to another host

In Pi, run /transfer, or /transfer HOST for a host from rex hosts list.
Pi asks where on the host to continue: a new Rex session, or a new window in an
existing one. Then it shows what moves and asks to confirm.

The host must be a Mac with these dotfiles and the same project under its home
folder. For a Git repository, push HEAD first. The host's checkout must not have
uncommitted changes.

Transfer moves the conversation, uncommitted changes to tracked files, and untracked
files that Git does not ignore. Ignored files, such as .env and node_modules, stay here.
On the host, the start script fetches the commit, checks out the branch or fast-forwards it,
applies the work, and starts pi --fork in the same folder. Your session here stays open.

Transfer uses rex cp and rex run, not SSH. The bundle goes to ~/.pi-transfer-ID on the host.
The script keeps the conversation in ~/.cache/pi-transfer/ and removes the bundle.
If a step fails, the script says why, opens a shell in the project, and keeps the bundle.
The extension is [rex-transfer](../../../stow/pi/.pi/agent/extensions/rex-transfer/).

## Change shortcuts

The prefix is Ctrl+B. Split, zoom, resize, session, and tab shortcuts follow Herdr.
Prefix+x closes the focused pane. If it is the last pane, it closes the tab.
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
