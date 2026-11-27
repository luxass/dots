# Credits

Everything in this folder is Dillon Mulroy's work, copied unchanged from his dotfiles,
[dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles) at commit
[`b20510f`](https://github.com/dmmulroy/.dotfiles/tree/b20510f297db5b0e91738f8a94220f8fd26bab72/home/.config/rex/dmmulroy).
Credit and thanks to [Dillon Mulroy](https://github.com/dmmulroy).

- `transfer_pi_session/`: from `home/.config/rex/dmmulroy/transfer_pi_session/`. Read its README.md first.
- Its Pi half, `stow/pi/.pi/agent/extensions/rex-transfer.ts`, is his
  `home/.pi/agent/extensions/rex-transfer.ts`, also unchanged.

The folder keeps his name because the code loads itself from `~/.config/rex/dmmulroy/`.
`init.lua` loads it with `require("dmmulroy.transfer_pi_session")`.
To update, copy both from his repository again and keep this file.
