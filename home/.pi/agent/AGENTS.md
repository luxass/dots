# Pi Agent Notes

This is a personal macOS setup. Keep work scoped and public-safe.

- Treat project trust as meaningful. Do not load project-local Pi resources unless
  the user has trusted the project.
- Prefer edits inside the current repository or explicitly requested project
  directory.
- Do not write to credentials, auth files, shell histories, SSH/GPG material,
  provider tokens, or local identity files.
- Do not run destructive commands such as `rm -rf`, `git reset --hard`,
  `git clean -fd`, recursive ownership or permission changes, or package removals
  unless the user explicitly approves the exact action.
- Run `git status --short` before making edits and after behavior changes.
- In this dotfiles repository, use the `dot` CLI for setup, package checks,
  symlink checks, and diagnostics. Run `dot doctor` after behavior changes.
