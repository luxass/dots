secret_scan() {
  local token_pattern='(_auth''Token|BEGIN [A-Z ]*PRIVATE KEY|OPENAI_''API_KEY|ANTHROPIC_''API_KEY|GITHUB_''TOKEN|GH_''TOKEN|AWS_SECRET_''ACCESS_KEY|password[[:space:]]*=|secret[[:space:]]*=)'

  if command_exists rg; then
    rg -n --hidden --glob '!.git/**' --glob '!backups/**' --glob '!packages/failed_packages_*.txt' "$token_pattern" "$DOTFILES_DIR"
  else
    grep -RInE "$token_pattern" "$DOTFILES_DIR" --exclude-dir=.git --exclude-dir=backups
  fi
}

ensure_git_hooks() {
  if ! git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_warning "$DOTFILES_DIR is not a git repository"
    return 1
  fi

  git -C "$DOTFILES_DIR" config core.hooksPath .githooks
  print_success "Git hooks path set to .githooks"
}

git_hooks_enabled() {
  [[ "$(git -C "$DOTFILES_DIR" config --get core.hooksPath 2>/dev/null || true)" == ".githooks" ]]
}

ensure_gitconfig_local() {
  local force="${1:-false}"
  local file="$HOME/.gitconfig.local"

  if [[ -f "$file" && "$force" != "true" ]]; then
    print_success "Git identity config exists"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    print_warning "Missing $file; run 'dot git-identity' to create it"
    return 1
  fi

  local default_name default_email default_signingkey name email signingkey
  default_name="$(git config --global --includes --get user.name 2>/dev/null || true)"
  default_email="$(git config --global --includes --get user.email 2>/dev/null || true)"
  default_signingkey="$(git config --global --includes --get user.signingkey 2>/dev/null || true)"

  read -r -p "Git user.name${default_name:+ [$default_name]}: " name
  name="${name:-$default_name}"

  read -r -p "Git user.email${default_email:+ [$default_email]}: " email
  email="${email:-$default_email}"

  print_info "For 1Password SSH signing keys, enable the 1Password SSH agent and run: ssh-add -L"
  read -r -p "Git user.signingkey${default_signingkey:+ [$default_signingkey]}: " signingkey
  signingkey="${signingkey:-$default_signingkey}"

  if [[ -z "$name" || -z "$email" ]]; then
    print_warning "Git identity skipped"
    return 1
  fi

  umask 077
  {
    echo "[user]"
    printf "\tname = %s\n" "$name"
    printf "\temail = %s\n" "$email"
    if [[ -n "$signingkey" ]]; then
      printf "\tsigningkey = %s\n" "$signingkey"
    fi
  } > "$file"

  print_success "Created $file"
}

cmd_git_identity() {
  print_header "Configuring Git identity"
  ensure_gitconfig_local true
}

cmd_hooks() {
  print_header "Configuring Git hooks"
  ensure_git_hooks
}

cmd_secret_scan() {
  print_header "Scanning for secrets"

  if secret_scan; then
    print_error "Possible secrets found"
    return 1
  fi

  print_success "Secret scan passed"
}
