---
name: write-discoverable-code
description: Write code that is easy to find with text search and understand in context. Use when writing, reviewing, or refactoring code, especially names, module boundaries, types, doc comments, and diagnostic messages.
---

# Write discoverable code

Most readers of a codebase, human or agent, find code the same way: they search for a
word, open the file at the hit, and read a few dozen lines around it. Agents lean on this
even harder, because they rarely have hover info, go-to-definition, or memory of the last
session. Every rule below has one goal: **the first search should land on the right line.**

## Naming

### Name exports so they are unique across the repo

A name is a search query someone will type later. Short generic names return pages of hits.

```ts
// Bad: "parse" matches hundreds of lines
export function parse(input: string) {}

// Good: one search, one hit
export function parseInvoiceCsv(input: string) {}
```

- Aim for two to four words, and include at least one word from the domain
  (`invoice`, `webhook`, `tenant`).
- Stop when the name is unique. `parseInvoiceCsvFromUploadedFileForBilling` is too far.
  Put the extra detail in the doc comment.
- Before you add a name, search for it. If it already exists elsewhere, pick another one.

### Do not let the folder carry the meaning

`billing/format.ts` and `reports/format.ts` can both export `formatAmount`. A search hit
shows the line, not the folder, so the reader can't tell them apart. Put the context in
the symbol: `formatBillingAmount`, `formatReportAmount`.

The exception is a strict, repo-wide convention where every file in a known place exports
the same names, such as route handlers that each export `GET` and `POST`.

### Use one word for one concept

If the codebase says `workspace`, do not add `project` for the same thing. If it says
`accountId`, do not add `acctId`. Each synonym splits future searches in two. Before you
name something, check what the surrounding code already calls it.

### Rename when meaning changes

If a function's behavior, inputs, or callers change, update its name in the same change.
That includes visibility: a `_internal` helper that other modules now import needs a
public name.

### Keep one copy of each function

Do not copy a function to a second file. Move it, update the imports, and delete the old
one in the same change. A search that finds two near-identical definitions forces the
reader to diff them.

## Files and modules

### Give files domain names

Generic file names like `utils.ts`, `helpers.ts`, `types.ts`, or `constants.ts` appear in
every package, so they tell a reader nothing. Prefer `invoice-totals.ts` over `utils.ts`.

Follow the framework when it requires a fixed name: `page.tsx`, `route.ts`, `mod.rs`,
`__init__.py`, and `index.ts` used only to re-export are fine.

### One question, one file

If someone asks "where do we retry failed webhooks?", the answer should be a file named for
that, such as `webhook-retry.ts`. It should not be line 400 of a `WebhookService` class.

- Keep coordinators short. A pipeline or service should read as a list of calls into
  well-named modules.
- Do not overcorrect. A small helper used by only one module can stay in that module.
  Splitting every function into its own file scatters one answer across many reads.

### Keep tests near the code

Where the ecosystem allows it, put `invoice-totals.test.ts` next to `invoice-totals.ts`.
A search for the name then finds both the code and its expected behavior.

## Types

### Make wrong calls fail to compile

Two plain `string` IDs can be swapped with no error. Brand them so the compiler catches it.

```ts
type AccountId = string & { readonly __brand: "AccountId" };
type InvoiceId = string & { readonly __brand: "InvoiceId" };

function voidInvoice(accountId: AccountId, invoiceId: InvoiceId) {}
```

Use your validation library's brand helper if you have one (`z.string().brand<"AccountId">()`
in Zod, a newtype in Rust). If a function takes two values of the same type, such as
`fromAccountId` and `toAccountId`, use an options object so each one has a label at the call site.

### Encode permissions and states in types

- For privileged operations, require a parameter type that proves the caller is allowed,
  for example `TenantScopedDb` instead of a raw database client.
- Model states as a discriminated union (`{ status: "paid"; paidAt: Date } | { status: "open" }`)
  instead of several optional fields with unwritten rules.

### Choose type names for error messages

Type names show up in compiler errors, and agents fix code by reading those errors.
`TenantScopedDb` tells the reader what went wrong; `Ctx2` does not. Avoid `any`, because it
turns those errors off.

## Comments and strings

### Write a one-line doc comment on every export

Say the one thing the signature cannot: units, time zone, who owns the data, what order
results come in.

Use plain, spaced-out words, because people search in phrases. A search for
"invoice total" does not match `computeInvoiceTotal`, but it matches this comment:

```ts
/** Computes the invoice total in cents, including tax. */
export function computeInvoiceTotal(invoice: Invoice): number {}
```

### Write searchable strings in full

Event names, feature flags, and error codes must appear in the source exactly as they
appear in logs and dashboards.

```ts
// Bad: nobody can search for "invoice.paid"
emit(`invoice.${status}`);

// Good
emit(status === "paid" ? "invoice.paid" : "invoice.voided");
```

### Start every error message with a fixed phrase

Put the variable parts at the end, so a message copied from a log leads straight to the
`throw`:

```ts
throw new Error(`Invoice total mismatch: expected ${expected}, got ${actual}`);
```

### Mark old paths

When you replace something, mark the old one `@deprecated` and name the replacement.

## Before you commit

- [ ] Does a search for each new export return its definition first?
- [ ] Would swapping two arguments of a new function cause a type error?
- [ ] Does each new export's doc comment say what the signature cannot?
- [ ] Does every log line, event name, and error message appear in full in the source?
- [ ] Did you rename everything whose behavior changed?
- [ ] After moving code, is the old copy gone?
