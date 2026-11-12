# Herdr

Managed plugin sources live in [plugins.txt](../../stow/herdr/.config/herdr/plugins.txt).
Dot init and dot stow install missing plugins through Socket Firewall.
Dot update offers updates for listed sources. Removing a source does not uninstall it.
Setup does not re-enable disabled plugins or restart the server.
Doctor checks registration and configuration.

## Reload shortcuts

After installing, reload without stopping the server:

```fish
herdr server reload-config
```

The prefix is Ctrl+B. Press it, then:

- a comments on selected terminal text.
- Shift+A copies annotations as context.
- Shift+M manages annotations. Lowercase m remains pane zoom.
- o reviews documents in the current folder.
- Shift+O reviews recent agent replies.
- i opens the notification target.

In document review, select text, press c to comment, and E to send feedback.
Markdown file:// links use the normal opener, not document review.
The shared plannotator-tui skill can open reviews through the plugin.
See [shared review instructions](pi.md#review-with-plannotator).

Plugin code, registry files, local plugin configuration, logs, and sessions stay outside Git and Stow.
Herdr Annotate bundles its TUI, so it needs no separate Homebrew package.

## Appearance

Herdr uses its terminal theme to inherit host colors. Its own theme selector stays off
because appearance detection can misreport dark terminals as light
([upstream issue](https://github.com/herdrdev/herdr/issues/3198)).
Colors still follow automatic appearance changes in the host terminal.
