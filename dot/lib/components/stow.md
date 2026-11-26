# Managed links and local state

Use dot stow and dot unstow, not bare Stow. Neither command takes package names.
The selected packages are defined in [paths.sh](../paths.sh).
Dot stow only re-links the packages. Dot init and dot update run the same step.
Plugins, shared skills links, Git starter files, and Rex configuration belong to
their components. Run dot init --only COMPONENT for those. Dot unstow also removes
the shared skills links.
Each stow package mirrors paths under HOME. Names starting with dot- become hidden files.
For example, stow/git/dot-gitignore links to ~/.gitignore.

## Repair links

```fish
dot doctor --only stow,skills
dot stow
dot init --only skills
```

Dot doctor exits 1 only when a required component's check fails.
Stow and skills are required components.

Doctor also warns about two problems that GNU Stow's simulate mode does not report:

- Uncommitted or untracked files under stow/. An installer that edits its
  configuration writes through the link into the repository, and Stow links
  untracked files into HOME. Review them with git -C ~/dots status -- stow.
- Links into the repository that point at missing files, for example after a
  rename. Doctor names the fix for each link: dot stow, dot link, or
  dot init --only skills. It looks in the directories that hold managed links
  and one level below them.

Before replacing a blocking path, the stow step moves it to the backups directory under
the local dot state directory. The default is ~/.local/state/dot/backups/<timestamp>/.
If XDG_STATE_HOME is set, backups use its dot/backups/ directory instead.

Every file inside a selected package can deploy, even if Git ignores it.
The shared [.stow-local-ignore](../../../.stow-local-ignore) excludes node_modules,
.DS_Store, and private Git paths. It replaces Stow's built-in exclusions,
so README.md and .gitignore files can deploy too. No git add is required before stowing.

## Keep application state outside the checkout

Do not put auth, sessions, logs, caches, sockets, or downloaded plugins in packages.
Pi state stays under ~/.pi/agent/. Fish variables and Herdr state also stay local.
Git ignores prevent accidental staging, not deployment.
[Shared skills](skills.md) use explicit links rather than Stow.
Restart apps that cache checkout paths if they recreate state in the repo.
