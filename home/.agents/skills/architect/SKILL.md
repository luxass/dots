---
name: architect
description: Design interfaces and module boundaries before implementation when a change needs an architectural decision.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Architect

Produce a design that makes the caller's usage, ownership, and important
invariants clear enough to implement.

## Ground the decision

Establish the requested behavior and the constraints of the surrounding code.
Trace the parts that the design changes or depends on. Use `how` for a subsystem
investigation and `why` when historical rationale could change the decision.

## Sketch the design

Start with a realistic caller example. Derive the types, signatures, module
boundaries, and data flow needed to support it. Use pseudocode or a small sketch
when that makes the contract easier to assess; avoid adding unfinished production
code solely to illustrate a proposal.

Compare structurally different alternatives when the choice has meaningful
tradeoffs. A second candidate or independent review is useful when it could
change the decision, not a prerequisite for every design.

Consult [design red flags](references/design-red-flags.md) when assessing
abstraction boundaries. Prefer interfaces that hide important decisions and make
invalid usage difficult. Account for failure, concurrency, or recovery where the
requested behavior makes them relevant.

For a written design proposal, use the relevant parts of the
[rationale template](references/rationale-template.md).

## Implement when requested

A design-only request ends with the proposal. If implementation is included,
continue through the requested implementation and relevant verification.
Honor an explicit checkpoint before implementing.

Treat the sketch as a working design. Adapt it when implementation reveals new
facts, and explain material deviations. Revisit the architecture when the same
workaround recurs across independent parts; a single edge case need not trigger
a redesign.

Report the chosen design, the tradeoffs that matter, and any unresolved decision
that prevents completing the requested work.
