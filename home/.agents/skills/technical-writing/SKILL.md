---
name: technical-writing
description: Write or review technical docs, READMEs, RFCs, PR descriptions, and commit messages for clear structure, accurate instructions, and consistent terminology.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Technical writing

Write so the intended reader can find the answer and use it correctly.

## Structure around the reader's task

Identify what the reader needs to do or understand from the request and existing
document. Preserve useful repo conventions and the requested format. Ask only when
the missing audience or purpose would materially change the result.

For tutorials, how-to guides, reference pages, explanations, or mixed document sets,
read [document modes](references/document-modes.md). Short PR descriptions and commit
messages do not need a documentation framework.

Lead with the result, task, or decision. Keep prerequisites and warnings before the
steps they affect. Use numbered lists for ordered actions and tables for repeated
comparisons when those formats make the information easier to use.

## Make the meaning precise

- Use actual symbols, paths, flags, and UI labels. Call each concept by one name.
- Say who does what. Prefer direct commands for instructions.
- Keep conditions close to the action they qualify. Make pronouns and words such as
  "only" unambiguous.
- Split overloaded instructions and long noun strings. Keep small connecting words
  when they prevent misreading.
- Distinguish facts, recommendations, uncertainty, and future plans. Do not turn
  incomplete evidence into a confident claim.
- Follow the repository's code formatting in examples. Do not impose tabs or spaces
  independently of the language and project.
- Use descriptive link labels and sentence-case headings unless the supplied format
  requires otherwise.

Apply [unslop](../unslop/SKILL.md) for voice and filler; its catalog lives there.

## Check the actual document

Check relevant commands, symbols, links, and examples against their source. Verify
dynamic counts or generated claims with the real artifact where practical, and say
when a check could not run. Avoid unrelated wording churn.

A documentation request does not authorize changing the implementation or other skills.
If the text exposes a behavior bug, report it unless fixing it is also requested.

This local guide adapts ideas from Diátaxis, Google's developer style guide,
ASD-STE100, and John R. Kohl's *The Global English Style Guide*. It is not a claim
of compliance with any of those standards.
