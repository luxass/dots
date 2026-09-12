---
name: principle-laziness-protocol
description: Reduce the scope and complexity of a proposed refactor or abstraction.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Laziness protocol

Choose the smallest change that solves the demonstrated problem and leaves the
code understandable.

Before adding an abstraction or threading a new signal through several layers,
check whether existing ownership or a simpler data flow can express the behavior.
Compare maintenance cost, not just line count.

Keep useful boundaries. Remove a wrapper or duplicated decision when doing so
simplifies the requested change; do not expand a small task into unrelated cleanup.
