# Simplify repository documentation

## Context

The README mixes setup instructions, command reference, implementation details, and migration history. AGENTS.md repeats command lists, repository structure, and safety rules. The goal is less reading and less duplicated information without losing important warnings.

## Approach

Agreed direction: simplify README.md and AGENTS.md. Make the README a minimal landing page. Keep reference material in a separate location, not in the README.

- Keep a short introduction, setup commands, common maintenance commands, and links in README.md.
- Put operational reference in lib/features/<feature>.md beside its feature script. This placement is approved. Do not create a central docs directory or restructure feature scripts.
- The dot entrypoint sources only *.sh, so Markdown does not affect loading. Keep documentation outside stow packages to avoid deploying it into HOME.
- Aim for roughly 60–90 lines in README.md: platform and purpose, setup including Fish PATH, a small everyday-command block, essential safety notes, and feature-reference links.
- Delete obsolete migration history and duplicate command syntax already covered by CLI help.
- Keep essential safety warnings beside the affected commands and preserve detailed warnings with their reference instructions.
- Keep agent-only implementation rules in AGENTS.md. Consolidate repeated rules without removing unique constraints.
- Do not change application configuration, CLI behavior, dependencies, or imported skills.

## Files to modify

- README.md.
- AGENTS.md.
- New feature references: lib/features/homebrew.md, git.md, stow.md, fish.md, pnpm.md, skills.md, pi.md, cua.md, opencode.md, herdr.md, rex.md, and gh.md. Create only files with useful retained operating instructions. Fold short Rust notes into setup rather than adding a nearly empty guide.
- Put shared Plannotator instructions in lib/features/pi.md and link from the OpenCode and Herdr references. Do not duplicate the shared procedure.
- Keep CLI development rules in AGENTS.md rather than creating a second development guide.

## Reuse

- lib/commands/help.sh: top-level commands and options.
- lib/commands/brew.sh: complete package and bundle command help, including removal and selection behavior.
- lib/commands/config.sh: preference commands, keys, and storage location.
- lib/core/paths.sh: package selection, runtime versions, feature order, and local state paths. Link to it rather than duplicating changing inventories.
- Existing source paths in AGENTS.md as navigation instead of repeated implementation descriptions.

The full README includes useful private Git setup and application-specific operating instructions. Its obsolete skills re-registration narrative and migration descriptions can be removed rather than relocated.

## Steps

- [x] Scan README.md and AGENTS.md for overlap and unnecessary detail.
- [x] Agree on scope and how aggressively to cut.
- [x] Read the remaining README sections and relevant command help definitions.
- [x] Confirm feature-based reference placement beside implementation.
- [x] Extract current operating instructions into feature references. Use task headings and relative links to the tracked configuration. Do not copy changing version or package inventories.
- [x] Replace README.md with the minimal landing page and feature-reference links.
- [x] Simplify AGENTS.md by removing its duplicate command catalog and directory tree, consolidating repeated prohibitions, and linking feature references from its navigation table. Preserve Bash 3.2 requirements, hook design, validation rules, and all unique safety constraints.
- [x] Remove obsolete migration history, retired-command announcements, and skills re-registration instructions. Keep current recovery steps, backup paths, private Git setup, signing safeguards, and plugin restart warnings.
- [x] Review every removed section: retain current unique instructions in its feature reference or identify it as duplicate or obsolete.

## Section review

- Overview, feature list, and directory inventory: reduced to the introduction and agent navigation. Changing inventories remain in source.
- Setup, commands, Rust, troubleshooting, and safety: retained in the landing page, CLI help, and agent validation rules.
- Managed files and application state: retained in stow.md, including backup and old-install recovery instructions.
- Package management and local preferences: retained in homebrew.md and existing CLI help.
- Git identity, private profiles, certificates, and signing: retained in git.md. Completed identity migration narratives removed.
- Shell and runtime policy: retained in fish.md and pnpm.md.
- Pi, Cua, OpenCode, Plannotator, terminal appearance, Rex, GitHub CLI, Herdr, and skills: retained in feature references. Shared review procedures live in pi.md.
- Skills re-registration, retired package commands, and retired plugin setup: obsolete instructions removed.
- CLI development and hook/scanner behavior: consolidated in AGENTS.md; Pi clean-filter behavior lives in pi.md.

## Verification results

- All relative file links resolve across 14 documentation files.
- git diff --check passed.
- ./dot secret-scan passed.
- Only documentation changed. No setup, service, installation, or identity commands were executed.

## Verification

- Compare documented commands and behavior with CLI help and source. Use Fish syntax for runnable command examples.
- Check every new relative link and feature reference against files on disk.
- Review the diff for lost warnings and unintended changes outside README.md, AGENTS.md, and new feature Markdown files. No runtime or dependency changes.
- Run ./dot secret-scan after edits. Preserve exact-line allowlist behavior: do not add broad exclusions if moved examples trigger findings.
- Documentation-only changes do not require setup, Stow operations, or dot doctor. Do not execute installation, plugin updates, service changes, or identity examples during verification.
