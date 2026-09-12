---
name: typescript-best-practices
description: Guide TypeScript implementation and review when choosing types, API contracts, or validation boundaries.
metadata:
  maintenance: local
---

# TypeScript best practices

Follow the repository's conventions and lint rules. Change type design to solve
a demonstrated problem, not merely because another representation is possible.

- Use discriminated unions when variants otherwise permit contradictory states.
- Use branded primitives when mixing domain values is a realistic risk. Reuse the
  project's branding convention.
- Keep the simplest type that represents the contract honestly. Model empty or
  missing results explicitly instead of hiding them behind `!` or assertions.
- Treat unvalidated input as `unknown`; parse it at the relevant trust boundary.
  Reuse an established schema or parser. Avoid redundant validation inside code
  that already has a trustworthy domain type.
- Prefer inference, narrowing, and `satisfies` to assertions. An assertion must
  have a concrete justification; it does not validate data at runtime.
- Check exhaustiveness when missing a union variant would be a bug. Type guards
  must actually establish the condition they claim.
- Derive types from the owning schema or contract when that avoids duplication.
  Use a separate domain type when it intentionally hides transport details.
- Use named options when they clarify confusing arguments. Keep simple positional
  APIs and existing public contracts when they serve callers well.

Consult [patterns](references/patterns.md) for examples of these choices.
