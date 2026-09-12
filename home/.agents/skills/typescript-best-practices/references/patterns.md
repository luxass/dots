# TypeScript patterns

Use these examples when they solve the type-design problem at hand. Match the
project's existing conventions and validation tools.

## Variants

A discriminated union prevents combinations that the domain does not allow:

```ts
type LoadState<T> =
  | { kind: "loading" }
  | { kind: "ready"; value: T }
  | { kind: "error"; message: string };

function describeState(state: LoadState<string>): string {
  switch (state.kind) {
    case "loading":
      return "Loading";
    case "ready":
      return state.value;
    case "error":
      return state.message;
    default: {
      const exhaustive: never = state;
      return exhaustive;
    }
  }
}
```

Use an existing discriminant name when the project already has one.

## Empty inputs

Choose the contract the caller needs. A possibly empty collection can return a
possibly missing value; a required element can be expressed in the input type.

```ts
function first<T>(items: readonly T[]): T | undefined {
  return items[0];
}

type NonEmpty<T> = readonly [T, ...T[]];

function firstRequired<T>(items: NonEmpty<T>): T {
  return items[0];
}

function isNonEmpty<T>(items: readonly T[]): items is NonEmpty<T> {
  return items.length > 0;
}
```

A non-empty tuple makes its first element available. Arbitrary numeric indexing
can still produce `undefined`, so it does not prove every computed index is valid.

## Boundary parsing and assertions

Construct the validated value when practical. An assertion does not perform a
runtime check.

```ts
type User = { id: string };

function parseUser(input: unknown): User {
  if (
    typeof input !== "object" ||
    input === null ||
    !("id" in input) ||
    typeof input.id !== "string"
  ) {
    throw new Error("Expected a user with a string id");
  }
  return { id: input.id };
}
```

For larger contracts, use the project's schema or parser. Decide whether to
reject or ignore extra fields based on the protocol and compatibility needs.

A representation can simplify an invariant without enforcing it. For example,
`{ start: Date; durationMs: number }` still permits negative durations and invalid
dates. Validate those values when the contract requires it.

## Branded values

Brand a primitive when values with different meanings could otherwise be mixed.
Reuse the project's convention. A constructor or parser must establish any runtime
constraints; adding a brand alone does not validate the value.

## Checking a declaration

Use `satisfies` to check compatibility while retaining the expression's inferred
type. Literal inference depends on the expression and contextual type; use
`as const` when readonly literal values are intended.

```ts
type DisplayConfig = { theme: "dark" | "light"; columns: number };

const displayConfig = {
  theme: "dark",
  columns: 3,
} satisfies DisplayConfig;
```

## Ownership and arguments

Derive a type from its schema or owner when that avoids duplicate contracts.
Keep a separate domain type when it deliberately separates transport and business
logic.

Named options help when several positional arguments are easy to confuse.
A short positional API can be clearer when the arguments have distinct roles.
Respect public compatibility and the repository's lint policy.
