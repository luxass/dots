# JavaScript runtimes and install policy

[paths.sh](../core/paths.sh) defines managed runtime versions and global tools.
Node.js belongs to pnpm. Do not select a competing global Node.js version with mise
unless you intend to migrate that ownership.

## Install packages

Use Socket Firewall for package-manager installs:

```fish
sfw pnpm install
sfw npm install
sfw pnpm add -g PACKAGE
```

[Runtime policy](../../stow/runtime-policy/) requires packages to be at least five days old.
Npm and Bun disable lifecycle scripts. Pnpm denies unreviewed builds.
Release-age exceptions stay scoped to the affected command or documented tool.
Never put auth tokens in policy files or relax the policy globally.

Dot init links policy before installing standalone pnpm, Node.js, npm, or global tools.
Doctor checks that managed global commands resolve from PNPM_HOME.
OpenCode belongs to Homebrew rather than the pnpm global installation.

## Update Node.js

Dot update offers updates within the managed Node.js release line, not the next major.
Restart Node.js applications after updating. Project runtimes, containers, and bundled
Node.js copies need separate updates. Use mise for other project runtimes.
