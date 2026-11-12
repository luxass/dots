# Git configuration

Edit the public defaults in [the tracked configuration](../../stow/git/.config/git/config).
Git reads it through ~/.config/git/config. Keep private identities and credentials
outside the repo. Automatic commit signing and the 1Password signing program stay enabled.

## Set a public signing key

Enable the 1Password SSH agent, then list its public keys:

```fish
ssh-add -L
```

Set user.signingkey to the relevant public key in the tracked configuration.
Never copy private keys or a work-only identity into that file.
Review the diff before committing.

## Add a private identity

Run dot stow to create comment-only starter files if they are absent:

```text
~/.config/git/local.conf
~/.config/git/extras/work.conf
```

Existing files and symlinks are preserved. These paths are excluded from Git and Stow.
The public configuration includes local.conf last.

Fill in and uncomment name, email, and signingkey together in extras/work.conf.
Use a public signing key or key reference. Keep private keys in your agent or 1Password.
Then enable the appropriate folder or remote include examples in local.conf.
Replace example paths and organizations with your own local values.

Folder rules match Git's metadata directory. For linked worktrees, that directory
can belong to the main repository. Remote-matched profiles must not define remote URLs.
Relative include paths resolve beside the including file. The last matching value wins,
so put more specific rules last. Keep identity overrides inside conditional profiles.
Unconditional overrides apply to every repository.

From the affected repository, inspect the selected identity before committing:

```fish
git config --show-origin --get user.name
git config --show-origin --get user.email
git config --show-origin --get user.signingkey
git config --show-origin --get commit.gpgsign
```

Do not paste private identity output into public reports. An independent ~/.gitconfig
is read after the XDG configuration and can override it. dot stow leaves independent
files unchanged. Doctor accepts local identities without printing their values.

## Certificates

Git uses Homebrew's ca-certificates bundle at
/opt/homebrew/etc/ca-certificates/cert.pem. Homebrew maintains it in place.
Do not change Apple's system bundle or disable TLS verification.
Repository configuration and environment variables can override the global setting.
This configuration does not change curl or Python.
