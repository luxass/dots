# Cua Driver: local integration

Read this with the upstream `SKILL.md`. These are local integration rules, not
a replacement for the upstream guides or the installed tool schemas.

## Native Pi MCP

Use the persistent `computer` server in `~/.pi/agent/mcp.json`. It runs
`cua-driver mcp` through Pi's native MCP support. No adapter extension,
permission flags, or permission environment override is needed.

Tools have the `mcp__computer__` prefix and use `codemode` exposure. Discover
with `await searchTools("get_window_state", { namespace: "computer" })` and
inspect an unfamiliar tool with `await describeTool(name)`. Call it through
`tools`. Forward returned image blocks with `image(block)` to inspect them.
Do not print image base64 as text.

Keep the same MCP connection and session for a workflow. Use the CLI for
installation and diagnostics, not one-shot actions mixed into that workflow.
Read the upstream companion guides when needed. The installed schemas take
precedence when an example disagrees with the running driver.

## Browser and desktop

Use the user's running Chrome when requested. Do not silently substitute an
isolated browser or copy their profile. Ask if the account or profile is
ambiguous. Browser preparation, remote debugging, and existing-profile grants
are separate setup decisions, not automatic recovery steps.

Prefer background input and keep the agent cursor visible. Ask before visible
foreground or desktop takeover unless the user already authorized it for this
workflow. A refusal does not authorize AppleScript, global pointer injection,
new permissions, or an unrestricted runtime.

Use exact window IDs and fresh element tokens. Inspect the rendered result
before retrying text insertion or reporting success. For a tab-close action,
identify the exact tab and its own Close control. After the action, make sure
that the intended tab disappeared and unrelated tabs remain. Do not assume a
successful keyboard shortcut closed a tab.

Prefer existing APIs, CLI tools, and file tools for non-GUI outcomes. Use Cua
for browser interaction, native apps, and visual inspection. Do not enable
recording or history without a request. OS permission dialogs belong to the
human.

## Concurrent work

Session labels do not create independent MCP connections or isolate input.
Keep one controller per shared desktop. Do not borrow another session's
screenshot or reuse its handles. Cursor overlays demonstrate cursor feedback,
not independent parallel browser input. For an explicitly requested demo,
report connection count separately from successful actions and elapsed time.

## Ownership and updates

The upstream pack was imported with `sfw pnpx skills` from `trycua/cua`, tag
`cua-driver-rs-v0.36.0`, path `libs/cua-driver/rust/Skills/cua-driver`.
Its provenance stays in `~/.agents/.skill-lock.json`. Use the skills CLI for
imports and updates. Do not hand-edit the lock metadata.

Retain the upstream pack with two local additions: this `LOCAL.md` and the
read-first note in `SKILL.md`. Before a CLI update, commit or stash local
changes. After the update, review the diff and manually restore this file and
the note if overwritten. Review their guidance against the installed binary.
The CLI does not guarantee preservation of these additions.

Keep one shared copy under `~/.agents/skills/`, not a duplicate Pi skill.
