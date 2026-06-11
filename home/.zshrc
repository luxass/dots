export ZSH="$HOME/.oh-my-zsh"
plugins=(git zsh-autosuggestions gh zsh-syntax-highlighting direnv)
source "$ZSH/oh-my-zsh.sh"

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:$HOME/.local/bin

if [[ -d /opt/homebrew/opt/fzf ]]; then
  source /opt/homebrew/opt/fzf/shell/completion.zsh
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# CF CLI completions
[[ -f "$HOME/.config/cf/completions/_cf.zsh" ]] && source "$HOME/.config/cf/completions/_cf.zsh"
