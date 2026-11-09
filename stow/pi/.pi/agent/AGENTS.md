## Codemode readability

Write codemode scripts for human review, not compactness.
- Use normal multiline JavaScript with two-space indentation.
- Put each statement on its own line.
- Expand tool arguments, objects, and arrays across lines.
- Use descriptive variable names and blank lines between steps.
- Use template literals for multiline replacement text.
- Never minify scripts or collapse them to save tokens.

## Shell

The user's shell is fish. Write every command you give the user in fish syntax (`for … end`, `; and`, `set -x`), never bash or zsh syntax.
