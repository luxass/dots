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

### Attribution

- End every PR description you create with `Made with {model} in {agent}.`
- Apply this to every creation method, including `gh pr create`, `gh stack`, other CLIs, and APIs. Include every PR in a stack.
- Use verified runtime details. The agent is the coding tool, such as Pi or Claude Code. Use the current footer supplied by a runtime extension when available.
- Omit unknown fields and their connecting words. Do not guess model names, versions, or agents. Do not add a host name.
- If only the agent is known, use `Made with {agent}.` If no details are known, use `This PR was created with the help of an agent.`
- Preserve existing attribution when updating descriptions. Add missing attribution for your contribution without replacing earlier credits or duplicating the same footer.
- Before finishing, read each created or updated PR description and make sure that its attribution is present and accurate.

For example, use `Made with Pi.` when Pi is known but the model is not.

### Commands

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
