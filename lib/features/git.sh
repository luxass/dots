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

# Scan tracked and unignored files, never printing credential values.
# Returns 0 for no findings, 1 for findings, and 2 for an execution error.
# Ignored files, submodules, and Git history are not scanned.
git_secret_scan() {
  local assignment url pattern matches_file findings status path number line finding
  assignment="(^|[^[:alnum:]_.$/-])(_?auth[_-]?token|([[:alnum:]_-]+[_-])?(api[_-]?key|access[_-]?key|passwd|password|secret)|(auth|access|refresh|bearer|api|session|oauth|github|gh|npm|openai|anthropic)[_-]?token|token|clientsecret|apikey|accesskey|idtoken)[\"']?[[:space:]]*[:=][[:space:]]*"
  url="://[^/[:space:]\"']*:[^/[:space:]\"']*@"
  pattern="($assignment|BEGIN [A-Z ]*PRIVATE KEY|$url)"

  matches_file="$(mktemp "${TMPDIR:-/tmp}/dot-secret-scan.XXXXXX")" || {
    print_error "Secret scan could not create its temporary file"
    return 2
  }
  # NUL-delimited paths keep colons and newlines in filenames unambiguous.
  if repo_git grep --untracked --no-color -nIizE "$pattern" >"$matches_file" 2>/dev/null; then
    :
  else
    status=$?
    rm -f "$matches_file" || return 2
    [[ "$status" -eq 1 ]] && return 0
    print_error "Secret scan could not read repository files"
    return 2
  fi

  if ! findings="$(
    while IFS= read -r -d '' path; do
      IFS= read -r -d '' number && IFS= read -r line || exit 2
      [[ "$number" =~ ^[0-9]+$ ]] || exit 2
      finding="$(printf '%s\n' "$line" | LC_ALL=C awk -v path="$path" -v assignment="$assignment" -v url="$url" '
    function placeholder(value) {
      return value == "" || value ~ /^\$[{A-Za-z_]/ || value ~ /^YOUR_[A-Z_]+$/ ||
        index(value, "process.env.") == 1 || index(value, "process.env[") == 1 ||
        index(value, "os.Getenv(") == 1 || index(value, "os.environ[") == 1 ||
        value ~ /^<[^<>]*>$/ || value ~ /^[xX]+$/ || value ~ /^[.][.][.]$/ || value == "…"
    }
    function value_of(text, quote, end) {
      sub(/^[[:space:]]+/, "", text)
      quote = substr(text, 1, 1)
      if (quote == "\"" || quote == sprintf("%c", 39) || quote == sprintf("%c", 96)) {
        text = substr(text, 2)
        end = index(text, quote)
        return end ? substr(text, 1, end - 1) : text
      }
      sub(/[[:space:],;)}`].*$/, "", text)
      return text
    }
    function category(line, path, rest, key, value, auth, colon) {
      if (toupper(line) ~ /BEGIN [A-Z ]*PRIVATE KEY/) return "private key"
      rest = line
      while (match(rest, url)) {
        auth = substr(rest, RSTART + 3, RLENGTH - 4)
        rest = substr(rest, RSTART + RLENGTH)
        colon = index(auth, ":")
        if (!placeholder(substr(auth, colon + 1))) return "credentials in URL"
      }
      rest = line
      while (match(tolower(rest), assignment)) {
        key = tolower(substr(rest, RSTART, RLENGTH))
        rest = substr(rest, RSTART + RLENGTH)
        # Equality tests and arrow functions are not credential assignments.
        if (rest ~ /^[=>]/) continue
        # YAML/JSON objects and lists are references, not scalar credentials.
        if (substr(rest, 1, 1) == "{" || substr(rest, 1, 1) == "[") continue
        # In source code, inspect literals, including typed defaults and backticks.
        if (path ~ /[.](ts|tsx|js|jsx|go)$/) {
          sub(/^[[:alnum:]_]+[[:space:]]*=[[:space:]]*/, "", rest)
          if (rest !~ /^[\"]/ && substr(rest, 1, 1) != sprintf("%c", 39) && substr(rest, 1, 1) != sprintf("%c", 96)) continue
        }
        value = value_of(rest)
        if (placeholder(value)) continue
        if (key ~ /password|passwd/) return "password assignment"
        if (key ~ /api[_-]?key|access[_-]?key/) return "API or access key assignment"
        return "token or secret assignment"
      }
      return ""
    }
    { print category($0, path) }
  ')" || exit 2
      if [[ -n "$finding" ]]; then
        printf '%s:%s: possible %s\n' "$path" "$number" "$finding"
      fi
    done <"$matches_file"
  )"; then
    rm -f "$matches_file" || return 2
    print_error "Secret scan could not classify repository files"
    return 2
  fi
  rm -f "$matches_file" || return 2
  [[ -z "$findings" ]] && return 0
  printf '%s\n' "$findings"
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
    if [[ "$?" -eq 1 ]]; then
      print_error "Possible secrets found"
    else
      print_error "Secret scan did not complete"
    fi
    failed=1
  fi
  return "$failed"
}
