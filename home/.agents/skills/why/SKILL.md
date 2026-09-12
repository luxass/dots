---
name: why
description: Investigate the history and rationale behind code or design decisions. Use when asking why an approach was chosen, what motivated a change, or where a constraint came from.
metadata:
  maintenance: local
---

# Why

Explain what evidence supports a decision's rationale, what can
reasonably be inferred, and what remains unknown.

## Investigate

Anchor the question in the relevant code, change, or decision.
Start with the closest evidence: comments explaining intent,
commit history, PR discussion, or linked design documents.

Follow leads into tickets, team discussions, incidents, metrics,
or analytics when they could resolve a material gap. Match the
breadth to the question; a clear answer in a PR may be enough.
For an explicitly broad investigation, search across the relevant
available sources.

Use [source playbooks](references/source-playbook.md) when you
need guidance for a particular source. Read only the playbooks
that apply.

Investigate directly by default. Delegate when independent
searches would materially help. Use the tools and models
available in the current environment.

## Evaluate the evidence

Code behavior alone does not establish historical intent.
Distinguish a reason an approach makes sense today from the
reason it was originally chosen.

Treat the user's suggested explanation as a hypothesis.
Check competing explanations when the evidence supports them.

Cite claims about intent. Label inferences and explain what
supports them. Surface contradictions rather than silently
choosing the tidier account.

An empty search means no relevant evidence was found through
that search. It does not prove that a discussion or decision
never happened.

For ambiguous or conflicting evidence, consult
[the confidence guide](references/epistemics.md).

## Explain

Lead with the best-supported answer. Include the context and
tradeoffs needed to understand it, with citations near the
claims they support.

Make uncertainty visible where it matters. When the answer
remains incomplete, name the unresolved question, what you
searched, and any relevant sources you could not access.

If the investigation informs a proposed code change, identify
which constraints still apply and which may no longer hold.

Keep the investigation read-only unless the user also requests
changes.
