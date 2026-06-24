---
name: commit
description: Create careful git commits using Conventional Commits with useful commit bodies. Use when the user asks to commit, split commits, stage changes, or write commit messages.
---

# Commit

Create git commits that are small, intentional, and easy to review.

## Rules

- Always use Conventional Commits: `<type>(<scope>): <summary>`.
- Use an imperative summary, no trailing period, and keep it under 72 characters.
- Include a commit body for non-trivial changes. Explain what changed and why.
- Do not add sign-offs.
- Do not push unless the user explicitly asks.
- Never stage unrelated files just because they are present.
- If changed files look unrelated, split the work into multiple commits or ask.
- If the user gives file paths, only stage those paths unless told otherwise.

## Common Types

- `feat`: new behavior or capability
- `fix`: bug fix
- `docs`: documentation only
- `test`: tests only
- `refactor`: code restructuring without behavior change
- `build`: dependency, package manager, or build configuration changes
- `chore`: maintenance that does not fit the other types

## Workflow

1. Run `git status --short --branch`.
2. Inspect the intended changes with `git diff` and, when staged files exist, `git diff --cached`.
3. Check recent commit style with `git log -n 20 --pretty=format:%s` when scope or type is unclear.
4. Decide whether the changes should be one commit or multiple commits.
5. Stage only the intended files.
6. Commit with a subject and body:

```sh
git commit -m "feat(scope): add useful behavior" \
  -m "Describe the important implementation details and why they matter."
```

## Body Guidance

Prefer a short body with one or two paragraphs. Mention:

- the behavioral change
- safety or compatibility considerations
- follow-up work only when it is directly relevant

Avoid restating the subject in longer words.
