---
name: principle-minimize-reader-load
description: Review code that is hard to trace for unnecessary indirection and hidden mutable state.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Minimize reader load

Ask what a reader must trace to find a value's origin and what can change it.

Keep related decisions together. Collapse forwarding layers that add no policy
or adaptation, while retaining boundaries that hide meaningful complexity.

Keep mutable state in the narrowest useful scope. Prefer deriving a value from
its owner over synchronizing duplicate copies.

Judge a change by whether the reader can explain the behavior with fewer hidden
assumptions. A fixed number of files, callers, or seconds is not a useful limit.
