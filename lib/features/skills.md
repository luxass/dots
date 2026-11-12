# Shared Agent Skills

Manage skills through the upstream CLI, not a dot wrapper:

```fish
sfw pnpx skills list -g
sfw pnpx skills add SOURCE -g --skill NAME -a universal --copy
sfw pnpx skills update -g
sfw pnpx skills remove NAME -g
```

Global operations change tracked files in [shared/agents/](../../shared/agents/).
Review the diff. Commit or stash local edits before updates because the CLI can overwrite them.
Keep credentials, private sources, and machine-local paths out of the native lock.

## Links and scope

Dot maintains these links without clearing lock entries:

```text
~/.agents/skills                       -> shared/agents/skills/
~/.claude/skills                       -> ~/.agents/skills/
~/.agents/.skill-lock.json             -> shared/agents/.skill-lock.json
```

The skills/.skill-lock.json path under XDG_STATE_HOME points to the same tracked lock.
The default state root is ~/.local/state.

Always use -g for this shared collection. Without it, commands use project scope.
Running project operations from HOME can reach the same skill directory with a different lock.
The CLI can also change agent-specific links. Inspect them after updates.

## Maintain local adaptations

Edit only locally maintained skills. Before adapting an imported skill, remove its lock
entry without deleting its files. The native remove command deletes files too.
No separate local inventory is needed. Record upstream SHAs in update commits when known.

Cua Driver is the exception: keep its native lock entry. Local changes are limited to
LOCAL.md and the read-first note in SKILL.md. Restore both after upstream updates.
See [Cua Driver](cua.md).
