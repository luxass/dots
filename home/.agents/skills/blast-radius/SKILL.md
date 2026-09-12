---
name: blast-radius
description: Review the downstream effects of a change, including contracts and consumers outside its diff.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Blast radius

Find concrete ways a change could break its consumers or surrounding behavior.

Read the change and trace the contracts it affects. Look beyond direct callers
when data crosses a boundary: serialized output, database fields, external APIs,
feature flags, callbacks, or another language consuming the same representation.
Check the pinned dependency version and local patches when behavior depends on
a library.

Identify the assumptions that determine whether the change is safe. Check the
most consequential ones against source or a focused executable reproduction.
Use an existing test, a temporary script, or the running app when it provides
useful evidence at reasonable cost. Do not create a test harness just to satisfy
the review.

Distinguish confirmed breakage, credible risks, and cases checked and cleared.
State the triggering conditions and consequences without inventing numeric
probabilities. Mark important assumptions that remain unverified.

Return findings with code references and evidence. Explain what changed, what
could break, and the cheapest useful check for any unresolved risk. An empty
finding list is valid when the evidence supports it.

Keep the review read-only. Use temporary locations for diagnostic artifacts.
Implement fixes or add repository tests only when the user requests them.
