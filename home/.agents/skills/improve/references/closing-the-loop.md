# Follow-through

Read the section matching the requested action.

## Execute a plan

Check the plan against current code and dependencies before implementing. Refresh
stale details when the intended behavior and scope are clear. Ask for direction
when a changed assumption materially changes the requested outcome.

Implement directly unless a delegated execution workflow is requested or useful.
If delegating, use the current environment's capabilities and an isolated worktree
when it protects unrelated work. Ensure the executor can read the plan, including
uncommitted plan files; pass the content when its path is not accessible.

Give an executor the objective, relevant constraints, evidence, and done criteria.
Allow routine implementation adjustments within scope. Request a report of changed
behavior, verification, and material deviations.

For a fresh worktree, account for missing dependencies and build artifacts. Follow
the repository's installation policy, including Socket Firewall where required.

Inspect the resulting diff and relevant checks. Rerun checks when reported evidence
is insufficient or the code changed afterwards. Resolve fixable failures rather
than stopping after an arbitrary number of attempts. Report a blocker when it
requires new authority, missing information, or an external change.

Mark the plan done only when its requested outcome is achieved. Commit, publish,
or integrate the result according to the user's authorization.

## Reconcile plans

Inspect the index and plans whose status or assumptions need refreshing.

- **DONE:** verify when there is reason to suspect regression or stale evidence.
- **BLOCKED:** investigate the recorded blocker and update the next action.
- **IN PROGRESS:** check the active work before assuming it was abandoned.
- **TODO:** check relevant code for drift; refresh the plan or retire a finding
  that no longer applies.

Keep the history of decisions and avoid duplicating existing plans. Report what
changed in the backlog and which work is ready.

## Publish issues

Use this workflow when the user asks to publish plans as issues, including
`--issues`. An audit or planning request alone does not authorize publication.

Confirm the target repository and its visibility. Prepare concise issue content
for the intended audience. If a public issue would expose sensitive findings,
prepare a suitable summary and resolve disclosure with the user before publishing.

Check for an existing issue before creating another. Use `gh issue create` with
`--body-file` and record the resulting URL in the plan or index. Reuse existing
labels where appropriate; do not create a label taxonomy as a side task.
