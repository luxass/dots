# shellcheck shell=bash
# Repository hooks, the private ~/.gitconfig.local identity, and secret scanning.

git_install_hooks() {
  repo_is_git || {
    print_error "$DOTFILES_DIR is not a Git repository"
    return 1
  }
  repo_git config core.hooksPath .githooks || return 1
  print_success "Git hooks path set to .githooks"
}

# git_write_identity [force]: create ~/.gitconfig.local, prompting for values.
git_write_identity() {
  local force="${1:-false}" file="$HOME/.gitconfig.local"
  local name email key default_name default_email default_key

  if [[ -f "$file" && "$force" != true ]]; then
    print_success "Git identity exists"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    print_warning "Missing $(pretty_path "$file"); run 'dot git-identity'"
    return 1
  fi

  default_name="$(git config --global --includes --get user.name || true)"
  default_email="$(git config --global --includes --get user.email || true)"
  default_key="$(git config --global --includes --get user.signingkey || true)"

  read -r -p "Git user.name${default_name:+ [$default_name]}: " name || true
  read -r -p "Git user.email${default_email:+ [$default_email]}: " email || true
  print_info "For 1Password SSH signing keys, enable the 1Password SSH agent and run: ssh-add -L"
  read -r -p "Git user.signingkey${default_key:+ [$default_key]}: " key || true
  name="${name:-$default_name}"
  email="${email:-$default_email}"
  key="${key:-$default_key}"

  if [[ -z "$name" || -z "$email" ]]; then
    print_warning "Git identity skipped"
    return 1
  fi

  touch "$file" && chmod 600 "$file" || return 1
  git config --file "$file" user.name "$name" || return 1
  git config --file "$file" user.email "$email" || return 1
  if [[ -n "$key" ]]; then
    git config --file "$file" user.signingkey "$key" || return 1
  fi
  print_success "Wrote $(pretty_path "$file")"
}

git_setup() {
  local failed=0
  git_install_hooks || failed=1
  git_write_identity || failed=1
  return "$failed"
}

# git_secret_scan: print likely secrets in tracked and unignored files.
# Returns 1 when something is found. Submodules are separate repos and are
# not scanned.
git_secret_scan() {
  local pattern placeholder matches
  pattern='(_auth''Token|BEGIN [A-Z ]*PRIVATE KEY|OPENAI_''API_KEY|ANTHROPIC_''API_KEY|GITHUB_''TOKEN|GH_''TOKEN|AWS_SECRET_''ACCESS_KEY|password[[:space:]]*=|secret[[:space:]]*=|://[^/[:space:]"'"'"']*:[^/[:space:]"'"'"']*@)'
  # Placeholders in docs and examples (env var refs, YOUR_* tokens) are not secrets.
  placeholder='\$[{A-Za-z_]|YOUR_[A-Z_]+|process\.env|[Ee]xample|xxxx|XXXX|<[^<>]*>'

  matches="$(repo_git grep --untracked -nIE "$pattern" | grep -vE "$placeholder" || true)"
  [[ -z "$matches" ]] && return 0
  printf '%s\n' "$matches"
  return 1
}

git_check() {
  local failed=0

  if [[ "$(repo_git config --get core.hooksPath || true)" == .githooks ]]; then
    print_success "Git hooks path"
  else
    print_warning "Git hooks path is not .githooks; run 'dot hooks'"
  fi
  if [[ ! -x "$DOTFILES_DIR/.githooks/pre-push" ]]; then
    print_error "pre-push hook is not executable"
    failed=1
  fi
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    print_success "Git identity"
  else
    print_warning "Missing ~/.gitconfig.local; run 'dot git-identity'"
  fi
  if git_secret_scan; then
    print_success "Secret scan"
  else
    print_error "Possible secrets found"
    failed=1
  fi
  return "$failed"
}
