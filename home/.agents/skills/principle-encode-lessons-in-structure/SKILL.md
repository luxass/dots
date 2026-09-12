---
name: principle-encode-lessons-in-structure
description: Address a recurring, demonstrated failure with an appropriate check or representation.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Encode lessons in structure

For a recurring failure, consider whether a type, lint rule, runtime check, or
shared helper can prevent it more reliably than another instruction.

Choose a mechanism that catches the actual failure without rejecting legitimate
work. Account for false positives, maintenance cost, and repository conventions.
Use prose when the decision requires context or judgment.

Implement the mechanism when it is within the requested change. Otherwise propose
it with the evidence for recurrence. A single correction does not authorize new
tooling or edits to unrelated skills.

Remove a duplicated instruction only when the replacement actually covers it.
