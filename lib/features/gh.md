# GitHub CLI

Public preferences and aliases live in [config.yml](../../stow/gh/.config/gh/config.yml).
Commands such as gh config set and gh alias set change that tracked file.
Review the diff and keep private values out of it.

## Authenticate

On a new machine, authenticate separately:

```fish
gh auth login
```

Dots does not copy credentials or log in for you. Authentication stays in local hosts.yml,
excluded from Git and Stow. The HOME configuration directory stays local with managed file links.
If GH_CONFIG_DIR or XDG_CONFIG_HOME redirects gh elsewhere, doctor reports the missing link
at the managed ~/.config/gh/config.yml location.

## Manage extensions

Declare sources in [extensions.txt](../../stow/gh/.config/gh/extensions.txt).
Dot init and dot stow install missing extensions through Socket Firewall.
Dot update offers updates for listed sources only. Versions are not pinned.
Removing a source does not uninstall it. Downloaded code stays local.
Doctor checks the configuration link and missing extensions.
