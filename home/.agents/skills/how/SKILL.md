---
name: how
description: Explain code behavior, runtime flow, and module ownership. Use for code walkthroughs and architectural placement or critique questions.
metadata:
  maintenance: local
---

# How

Help the reader understand how a subsystem works well enough to
reason about it or change it.

## Explain

Trace the relevant path from its entry point through the code.
Explain what triggers it, how data and state change, and where
responsibility passes between components.

Focus on the parts needed to answer the question. Include
non-obvious behavior and boundaries that a newcomer could
misunderstand. Distinguish what the code establishes from what
remains uncertain.

Investigate and explain directly by default. Delegate when
independent exploration of separate parts would materially help.
Use the tools and models available in the current environment.

Lead with the answer, then develop the explanation at the depth
the question needs. Cite the files and symbols that support it.
Use a diagram when it makes the flow easier to understand.

For ownership or placement questions, explain which component
owns the relevant knowledge and what dependencies the proposed
placement would create.

Historical motivation needs evidence beyond code behavior.
Consult `why` when that history matters to the question.

## Critique

When architectural critique is requested, read
[the critique rubric](references/critique-rubric.md) and apply
the relevant parts.

Ground findings in the actual code. Explain the consequence
of each issue and distinguish a demonstrated problem from an
accepted tradeoff or a speculative concern.

An explanation and critique can share one investigation.
Present enough context to understand the findings without
requiring a separate architecture report first.

Keep explanation and critique read-only unless the user also
requests changes.
