---
name: principle-prove-it-works
description: Choose direct evidence for a task's result when a build, cached output, or agent report is insufficient.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Prove it works

Choose verification that checks the behavior or artifact the user asked for.

A build establishes that code builds; it may not establish runtime behavior.
Exercise the relevant feature path when that is necessary to answer the remaining
correctness question. A documentation edit may only need an accurate diff and
valid references.

Inspect delegated output before relying on its summary. Check actual values or
current state when a cached or indirect observation could mislead.

Use an existing check when it provides the needed evidence. Add a focused script
or test when its repeatability justifies the cost. Once the relevant checks pass,
repeat them only if new changes or unresolved concerns warrant it.

Report failures and meaningful verification gaps without presenting untested
assumptions as established results.
