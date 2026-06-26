# Pi Agent Notes

These are global Pi instructions and may be loaded in any project. Keep them
project-agnostic, public-safe, and lightweight.

## DEFAULT BEHAVIOR

- Do not assume the current repository is this dotfiles repo. Follow the nearest
  project instructions first, then these global notes.
- Treat project trust as meaningful. Do not load project-local Pi resources,
  skills, extensions, or hidden agent state unless the project is trusted or the
  user explicitly asks.
- Prefer small, focused changes. Read the relevant files before editing, and ask
  when requirements are unclear.
- Run `git status --short` before making edits in a Git repository. Do not touch
  unrelated user changes unless asked.
- Use focused validation for the thing changed. Do not run broad diagnostics just
  because this file was loaded.

## SAFETY AND PRIVACY

- Keep tracked content public-safe. Do not add tokens, auth config, shell
  histories, SSH/GPG material, provider credentials, private Git identity, or
  work-only details.
- Do not read or print sensitive local files unless the user explicitly requests
  it and the task requires it.
- Do not run destructive commands such as `rm -rf`, `git reset --hard`,
  `git clean -fd`, recursive ownership/permission changes, or package removals
  unless the user explicitly approves the exact action.
- Do not install global tools, change system settings, or modify files outside
  the current repository unless the user asks.

## WORKING STYLE

- Prefer repository-provided commands, scripts, and package managers over ad hoc
  commands.
- Keep edits minimal and idiomatic for the existing project.
- When changing behavior, update nearby docs or comments only if they remain
  useful and accurate.
- If validation is skipped, say why briefly.
- Be concise in final responses: summarize what changed, list validation, and
  call out any unrelated working-tree changes.

## WRITING STYLE

- Never use em dashes. Use commas, parentheses, colons, semicolons, or separate
  sentences instead.
- Keep prose direct, calm, and practical. Avoid hype, filler, and corporate
  polish.
- Prefer short paragraphs and bullets for status updates.
- Do not over-explain unless the user asks for rationale or tradeoffs.

## DOTFILES REPOSITORY

These rules apply only when intentionally working in `/Users/luxass/dots` or when
the user asks about this dotfiles setup.

- Use files under `home/` rather than editing stowed symlink targets in `$HOME`.
- Use the `dot` CLI for setup, package checks, symlink checks, Pi management, and
  diagnostics when relevant.
- Do not run `dot doctor` automatically. Run it when the user asks for
  diagnostics, or when validating changes to the `dot` CLI, setup flow, package
  management, Stow behavior, runtime setup, or Pi management behavior.
- For package changes, prefer `dot package ...` or the appropriate
  `packages/bundle*` file.
- Keep `home/.gitconfig` free of private identity. Private Git identity belongs
  in `~/.gitconfig.local`, never tracked files.
- Do not reintroduce removed configs or tools such as tmux, skhd, lazygit,
  wezterm, Neovim config, or custom alias/function files unless explicitly
  requested.

## PI CONFIG IN THIS DOTFILES REPO

- Managed Pi files live under `home/.pi/` and are intended to be stowed into
  `$HOME/.pi`.
- Prefer editing tracked configuration, extensions, themes, or package metadata.
- Avoid reading or modifying local runtime/auth state such as auth files, crash
  logs, caches, or generated dependency directories unless explicitly required.
- If changing Pi extensions or package metadata, run the narrowest relevant
  package/typecheck/test command before considering broader dotfiles diagnostics.
