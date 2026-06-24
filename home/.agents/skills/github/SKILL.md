---
name: github
description: Work with GitHub repositories using the gh CLI. Use when the user asks about pull requests, CI checks, workflow runs, issues, releases, or GitHub API data.
---

# GitHub

Use the `gh` CLI for GitHub work. Prefer structured output and explicit repository targeting.

## Rules

- Use `gh` instead of scraping GitHub pages when possible.
- Use `--repo owner/repo` when outside the repository or when the target repo is ambiguous.
- Use `--json` and `--jq` for machine-readable queries.
- Do not create, edit, close, merge, or approve PRs/issues unless the user asked.
- Do not push branches unless the user explicitly asked to publish changes.
- Keep PR text public-safe: no secrets, tokens, private identity values, or local-only paths.

## Pull Requests

Inspect a PR:

```sh
gh pr view <number-or-url> --json title,state,author,baseRefName,headRefName,url
```

Check PR CI:

```sh
gh pr checks <number-or-url>
```

Create a PR after the user asks:

```sh
gh pr create --title "<title>" --body "<body>"
```

Update an existing PR body:

```sh
gh pr edit <number-or-url> --body-file <path>
```

## Workflow Runs

List recent runs:

```sh
gh run list --limit 10
```

Inspect a run:

```sh
gh run view <run-id>
```

Show failed logs:

```sh
gh run view <run-id> --log-failed
```

## Issues

List issues with structured output:

```sh
gh issue list --json number,title,state,labels --jq '.[] | "\(.number): \(.title)"'
```

Create or edit issues only when requested by the user.

## API

Use `gh api` for fields not exposed by a subcommand:

```sh
gh api repos/owner/repo/pulls/<number> --jq '.title, .state, .user.login'
```

Prefer the narrowest API call that answers the question.
