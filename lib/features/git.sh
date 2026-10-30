# shellcheck shell=bash
# Repository hooks, public Git identity, and secret scanning.

# Retire only the old Stow link; leave independently managed ~/.gitconfig alone.
git_prestow() {
  local old="$HOME/.gitconfig" target
  [[ -L "$old" ]] || return 0
  target="$(readlink "$old")" || return 1
  [[ "$target" == /* ]] || target="$HOME/$target"
  if [[ "$target" == "$DOTFILES_DIR/home/.gitconfig" ]]; then
    backup_path "$old" || return 1
  fi
  return 0
}

git_install_hooks() {
  repo_is_git || {
    print_error "$DOTFILES_DIR is not a Git repository"
    return 1
  }
  repo_git config core.hooksPath .githooks || return 1
  print_success "Git hooks path set to .githooks"
}

# git_secret_scan: print likely secrets in tracked and unignored files.
# Returns 1 when something is found. Submodules are separate repos and are
# not scanned.
git_secret_scan() {
  local pattern placeholder matches
  # Match auth token assignments, not bare key names or ellipsis-only values.
  pattern='(_auth''Token["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[[:alnum:]_+/-]|BEGIN [A-Z ]*PRIVATE KEY|OPENAI_''API_KEY|ANTHROPIC_''API_KEY|GITHUB_''TOKEN|GH_''TOKEN|AWS_SECRET_''ACCESS_KEY|password[[:space:]]*=|secret[[:space:]]*=|://[^/[:space:]"'"'"']*:[^/[:space:]"'"'"']*@)'
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
  local file="$HOME_DIR/.config/git/config" field expected actual
  check_link "$HOME/.config/git/config" "$file" "Git configuration link" || failed=1
  for field in user.name user.email user.signingkey; do
    expected="$(git config --file "$file" --get "$field" || true)"
    actual="$(git config --global --includes --get "$field" || true)"
    if [[ -z "$expected" && "$field" != user.signingkey ]]; then
      print_error "Missing public Git $field; edit home/.config/git/config"
      failed=1
    elif [[ "$actual" != "$expected" ]]; then
      print_error "Global Git $field differs from the tracked public identity; check local overrides"
      failed=1
    else
      print_success "Public Git $field"
    fi
  done
  local bundle configured
  bundle="$(git config --file "$HOME_DIR/.config/git/config" --path --get http.sslCAInfo)" || return 1
  configured="$(git config --global --includes --path --get http.sslCAInfo || true)"
  if [[ "$configured" == "$bundle" && -s "$bundle" && -r "$bundle" ]]; then
    print_success "Git Homebrew CA bundle"
  else
    print_error "Git CA bundle is missing or overridden; check Homebrew ca-certificates and ~/.config/git/config"
    failed=1
  fi
  if git_secret_scan; then
    print_success "Secret scan"
  else
    print_error "Possible secrets found"
    failed=1
  fi
  return "$failed"
}
