---
name: principle-guard-the-context-window
description: Reduce unnecessary context when handling large outputs, long documents, or repeated exploration.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Guard the context window

Keep the evidence needed for the current decision easy to find.

Search before reading large files. Bound tool output, inspect relevant sections,
and retain paths so omitted detail can be retrieved. Follow requirements to read
instruction files fully.

Read references when their topic becomes relevant. Reuse established findings
instead of repeating broad searches.

Delegate an independent investigation when a concise result would help more than
its raw output. Preserve decisions, constraints, evidence locations, and remaining
work across handoffs or compaction.
