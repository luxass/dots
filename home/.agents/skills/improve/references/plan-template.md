# Handoff plan

Write enough context for an executor that has not seen the conversation. Match
detail to the complexity of the work and the intended executor. Use the sections
below when they contribute to execution; omit empty or irrelevant sections.

Use `plans/NNN-short-slug.md`, or the existing plan directory. Keep numbering
consistent with the index.

## Goal and evidence

Describe the observable behavior to deliver, the current problem, and the evidence
supporting it. Include file and symbol references and concise excerpts where they
help identify the relevant code.

## Baseline and dependencies

Record the inspected commit and any prerequisite plans. Before execution, compare
the relevant current code with the baseline, including working-tree changes.
Ordinary drift calls for reassessment; it is not automatically a reason to stop.

Include applicable repository conventions, contracts, and decisions. Point to
resources available to the executor and inline essential context that would
otherwise be inaccessible.

## Scope and approach

Name the areas expected to change and the contracts that must remain intact.
Describe the intended approach and meaningful tradeoffs. Give ordered steps when
their sequence matters, while leaving routine implementation choices to the
executor.

Allow necessary supporting edits within the user's requested scope. Ask for
direction before expanding the outcome or changing an explicitly excluded area.

## Verification and completion

Give real commands and the behavior they establish. Include environment setup
only when needed, using the repository's package manager and install policy.
State checks that were not run rather than presenting guessed commands as verified.

Add a regression test when it provides useful evidence at proportionate cost.
Define completion in observable terms, including important failure behavior.
Do not require a separate check for every small step when one check covers the
result.

## Decisions requiring direction

Name specific conditions that require user input: missing requirements, conflicting
contracts, unexpected external effects, or a material change to the objective.
Routine test failures and fixable setup issues stay within implementation.

## Handoff and status

Record effort, dependencies, current status, and any remaining limitation. Follow
the user's authorization for commits, PRs, or publication. A plan does not itself
authorize those actions.

Use an index for multiple plans with columns for plan, goal, dependencies, and
status. Keep rejected or superseded decisions only when they prevent repeated work.
