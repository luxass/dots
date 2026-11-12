# Managed links and local state

Use dot stow and dot unstow, not bare Stow. Neither command takes package names.
The selected packages are defined in [paths.sh](../core/paths.sh).
Each stow package mirrors paths under HOME. Names starting with dot- become hidden files.
For example, stow/git/dot-gitignore links to ~/.gitignore.

## Repair links

```fish
dot doctor
dot stow
```

Before replacing a blocking path, dot stow moves it to the backups directory under
the local dot state directory. The default is ~/.local/state/dot/backups/<timestamp>/.
If XDG_STATE_HOME is set, backups use its dot/backups/ directory instead.

Every file inside a selected package can deploy, even if Git ignores it.
The shared [.stow-local-ignore](../../.stow-local-ignore) excludes node_modules,
.DS_Store, and private Git paths. It replaces Stow's built-in exclusions,
so README.md and .gitignore files can deploy too. No git add is required before stowing.

## Keep application state outside the checkout

Do not put auth, sessions, logs, caches, sockets, or downloaded plugins in packages.
Pi state stays under ~/.pi/agent/. Fish variables and Herdr state also stay local.
Git ignores prevent accidental staging, not deployment.
[Shared skills](skills.md) use explicit links rather than Stow.

For older installations, dot stow moves repo-backed state to its normal HOME paths.
It merges directories, preserves existing HOME files, and backs up duplicate checkout copies.
It does not require closing sessions and leaves existing sockets in place.
Restart apps that cache checkout paths if they recreate state in the repo.
