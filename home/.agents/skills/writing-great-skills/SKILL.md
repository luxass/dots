---
name: writing-great-skills
description: Review skill instructions for precise triggers, useful guidance, clear boundaries, and selective reference loading.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Writing great skills

A skill should improve decisions and results for a specific task. Consistent
outcomes matter more than forcing the same process on every run.

Keep instructions that contribute project knowledge, user preferences, fragile
tool behavior, or a real decision boundary. Remove generic advice the model
already follows, duplicated rules, and remedies for hypothetical failures.

## Scope and discovery

Keep the description short and specific about when the skill applies. Test it
against both an intended request and a nearby request that should not trigger it.

Preserve the intended invocation policy. In Codex, explicit-only selection uses
`policy.allow_implicit_invocation: false` in `agents/openai.yaml`.
Keep `disable-model-invocation: true` in frontmatter where another host uses it.
Both names and descriptions remain required; do not promise that metadata has
identical context or invocation effects in every host.

## Instructions and references

State the desired result, the constraints that matter, and how to recognize
completion. Use a fixed sequence only when order protects correctness or the user
explicitly wants that workflow.

Put shared guidance in the root and substantial conditional material in references.
Link each reference with the condition for reading it. A short, self-contained
skill needs no extra files.

Use available tools and capabilities. Remove missing dependencies and hardcoded
agent configurations. Optional delegation should earn its cost.

Honor the user's current scope and authorization. A review remains read-only,
but a later implementation request can authorize implementation.

## Review and maintenance

Keep each rule in one place. When pruning a root, check its references for
contradictory instructions and obsolete links. Retain useful examples and any
required license or attribution notices.

Validate metadata and references, then use realistic tasks when behavioral testing
would add confidence. Check the result and unnecessary work, not just whether
the agent followed the prescribed steps.

For local adaptations, use `metadata.maintenance: local` and record upstream
provenance in Git history according to this repository's policy.
