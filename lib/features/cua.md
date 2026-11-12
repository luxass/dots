# Cua Driver

Pi declares Cua Driver through native MCP in [mcp.json](../../stow/pi/.pi/agent/mcp.json).
It runs cua-driver mcp with standard permissions, without startup grants or approval bypasses.
No adapter extension, Cua Spaces, or VM is required.

## Set up permissions

Dot init installs Cua Driver through the [official installer](https://cua.ai/docs/cua-driver/quickstart).
The signed app goes in /Applications and the CLI in ~/.local/bin.
The installer does not edit shell startup files. You approve macOS permissions yourself.
If you skip the offered permission flow, run it later:

```fish
cua-driver permissions grant
cua-driver doctor
pi mcp list
```

In an existing Pi session, use /reload and inspect /mcp.
Use Cua for GUI work and ordinary tools for files and command-line work.
Ask before visible desktop takeover unless the task already authorizes it.

## Update safely

Dot update offers the native updater and preserves the selected release channel.
If the daemon is running, stopping it interrupts computer-use sessions.
Dot asks before stopping it and aborts if it does not stay stopped.
Reconnect Pi afterward. A changed signing identity can require permission grants again.
The --yes option cannot approve macOS dialogs.

Doctor inspects the CLI, signature, daemon, and permissions without starting the daemon
or opening permission prompts. A stopped daemon produces a warning.
Dot stow only links configuration and the skill. It never installs or launches Cua.

The imported [skill pack](../../shared/agents/skills/cua-driver/) keeps its native lock entry.
Restore LOCAL.md and the read-first note in SKILL.md after updates.
See [skills maintenance](skills.md).
