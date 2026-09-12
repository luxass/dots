---
name: teach
description: Teach a concept, code change, or subsystem in plain language, adapting the explanation to the reader's knowledge and purpose.
disable-model-invocation: true
metadata:
  maintenance: local
---

# Teach

Help the person understand what something is, how it works, and why it matters.

Start from what the conversation tells you about their knowledge and purpose.
Explain unfamiliar concepts before relying on them. Skip background they already
understand.

Lead with the main point, then build a connected explanation. Describe the
mechanism using a concrete example or a walkthrough of what happens. Naming
functions and components is not enough.

Use `how` when understanding the code requires investigation. Use `why` when
historical rationale matters. Reuse findings already established in the
conversation, and preserve their uncertainty when simplifying the wording.

Match the depth to the request. Give a complete explanation of the question
asked. When the person wants an interactive lesson, work through it in manageable
parts and follow their questions. Do not quiz them unless they ask.

Use diagrams, examples, or demonstrations when they make an important relationship
easier to understand. Build a diagram gradually when the intermediate steps help;
otherwise one clear diagram is enough.

Write in plain, spoken English. Keep terminology consistent, explain necessary
jargon, and retain the detail that makes the idea click. Apply `unslop` for wording.

Deliver the explanation itself, without a report about the teaching process.
Keep the work read-only unless the user also requests changes.
