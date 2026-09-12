---
name: principle-subtract-before-you-add
description: Sequence a replacement or migration so obsolete behavior and its supporting code are removed.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Subtract before you add

Identify what the replacement makes obsolete: code paths, dependencies,
configuration, validators, documentation, and temporary compatibility logic.

Remove independent dead weight early. Keep required behavior working while
introducing a replacement; migrate callers before removing a path they still use.

Finish by checking that obsolete references and temporary migration code are gone,
or explain the compatibility requirement that keeps them.
