# shellcheck shell=bash
# Homebrew and the packages/bundle* Brewfiles.

homebrew_require() {
  command_exists brew && return 0
  print_error "Homebrew is missing. Install it with:"
  # shellcheck disable=SC2016 # printed for the user, not expanded
  printf '  %s\n' '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
  return 1
}

# bundle_file GROUP: the Brewfile for a bundle group.
bundle_file() {
  case "$1" in
    base) printf '%s\n' "$PACKAGES_DIR/bundle" ;;
    fonts | work | personal) printf '%s\n' "$PACKAGES_DIR/bundle.$1" ;;
    *)
      print_error "Unknown bundle group: $1 (use: ${BUNDLE_GROUPS[*]})"
      return 1
      ;;
  esac
}

bundle_pref_key() { printf 'packages.brew.%s.enabled\n' "$1"; }

# bundle_state GROUP: enabled, disabled, or unset (not chosen on this machine yet).
bundle_state() {
  local value status
  bundle_file "$1" >/dev/null || return 2
  if [[ "$1" == base ]]; then
    echo enabled
  elif value="$(prefs_get "$(bundle_pref_key "$1")")"; then
    if [[ "$value" == true ]]; then echo enabled; else echo disabled; fi
  else
    status=$?
    [[ "$status" -eq 1 ]] || return 2
    echo unset
  fi
}

# Keep source names: native bundle list strips cask tap qualifiers. Reports
# read plain declarations locally; validation also checks syntax with Homebrew.

bundle_entries() {
  if [[ ! -f "$1" || ! -r "$1" ]]; then
    print_error "Cannot read Brewfile: $(pretty_path "$1")"
    return 1
  fi
  if [[ "${2:-validate}" != report ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --file "$1" --formula >/dev/null || return 1
  fi
  awk '
    /^[[:space:]]*(#|$)/ { next }
    /^[[:space:]]*tap "[A-Za-z0-9_.+\/-]+"/ { next }
    {
      if ($0 !~ /^[[:space:]]*(brew|cask) "[A-Za-z0-9@._+\/-]+"[[:space:]]*(#.*)?$/) {
        printf "%s:%d: unsupported package declaration\n", FILENAME, FNR > "/dev/stderr"
        failed = 1
        next
      }
      type = $1 == "brew" ? "formula" : "cask"
      split($0, parts, "\"")
      print type, parts[2]
    }
    END { exit failed }
  ' "$1"
}

# Resolve choices before any package/runtime mutation. Report every unresolved key.
bundles_resolve() {
  local group state status failed=0
  for group in "${BUNDLE_GROUPS[@]}"; do
    state="$(bundle_state "$group")" || return 1
    [[ "$state" == unset ]] || continue
    if preference_enabled "$(bundle_pref_key "$group")" "Enable the $group bundle on this machine?"; then
      :
    else
      status=$?
      [[ "$status" -eq 1 ]] || failed=1
    fi
  done
  return "$failed"
}

# GROUPS is newline-delimited; omitted means all. Rows: GROUP TYPE NAME.
# Never hide a failed file read, including on the lightweight reporting path.
bundle_read() {
  local groups="${1:-$(printf '%s\n' "${BUNDLE_GROUPS[@]}")}" group file entries type name
  BUNDLE_DECLARATIONS=''
  while IFS= read -r group; do
    file="$(bundle_file "$group")" || return 1
    entries="$(bundle_entries "$file" "${2:-validate}")" || return 1
    while read -r type name; do
      [[ -n "$type" ]] || continue
      BUNDLE_DECLARATIONS+="$group"$'\t'"$type"$'\t'"$name"$'\n'
    done <<<"$entries"
  done <<<"$groups"
}

# Index Homebrew identities and aliases: TYPE LOOKUP_NAME CANONICAL_NAME.
brew_metadata_index() {
  jq -r '
    if (.formulae | type) != "array" or (.casks | type) != "array" then
      error("Invalid Homebrew metadata")
    else . end
    | (.formulae[] | . as $f
      | if (.name | type) != "string" or (.full_name | type) != "string" then
          error("Invalid formula identity") else . end
      | (if (.full_name | contains("/")) then (.full_name | split("/") | .[0:-1] | join("/")) + "/" else "homebrew/core/" end) as $prefix
      | ([.name, .full_name, ($prefix + .name)] + (.aliases // []) + (.oldnames // [])
        + [((.aliases // []) + (.oldnames // []))[] | if contains("/") then . else $prefix + . end])
      | unique[] | ["formula", ., $f.full_name] | @tsv),
      (.casks[] | . as $c
      | if (.token | type) != "string" or (.full_token | type) != "string" then
          error("Invalid cask identity") else . end
      | (if (.full_token | contains("/")) then (.full_token | split("/") | .[0:-1] | join("/")) + "/" else "homebrew/cask/" end) as $prefix
      | ([.token, .full_token, ($prefix + .token)] + (.old_tokens // [])
        + [(.old_tokens // [])[] | if contains("/") then . else $prefix + . end])
      | unique[] | ["cask", ., $c.full_token] | @tsv)
  '
}

brew_identity() {
  awk -F '\t' -v type="$1" -v name="$2" '
    $1 == type && $2 == name { identities[$3] = 1 }
    END {
      for (identity in identities) { result = identity; count++ }
      if (count == 1) print result
      else exit (count ? 2 : 1)
    }
  ' <<<"$BREW_NAMES"
}

# Validate all bundles, including disabled ones, against native Homebrew names.
# BUNDLE_ROWS adds canonical identity as its fourth field.
bundle_load() {
  local group type name identity data index old_group old_type old_name old_identity
  local formulae=() casks=()
  command_exists jq || {
    print_error "jq is required to read Homebrew metadata; install the declared jq formula first"
    return 1
  }
  bundle_read || return 1
  BREW_NAMES=''
  BUNDLE_ROWS=''
  while IFS=$'\t' read -r group type name; do
    [[ -n "$group" ]] || continue
    if [[ "$type" == formula ]]; then formulae+=("$name"); else casks+=("$name"); fi
  done <<<"$BUNDLE_DECLARATIONS"
  for type in formula cask; do
    if [[ "$type" == formula ]]; then
      [[ "${#formulae[@]}" -gt 0 ]] || continue
      data="$(HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 --formula "${formulae[@]}")" || return 1
    else
      [[ "${#casks[@]}" -gt 0 ]] || continue
      data="$(HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 --cask "${casks[@]}")" || return 1
    fi
    index="$(brew_metadata_index <<<"$data")" || return 1
    BREW_NAMES+="$index"$'\n'
  done
  while IFS=$'\t' read -r group type name; do
    [[ -n "$group" ]] || continue
    identity="$(brew_identity "$type" "$name")" || {
      print_error "Cannot uniquely resolve $type $name in $(pretty_path "$(bundle_file "$group")")"
      return 1
    }
    while IFS=$'\t' read -r old_group old_type old_name old_identity; do
      [[ "$old_type" == "$type" && "$old_identity" == "$identity" ]] || continue
      print_error "Duplicate $type $identity: $(pretty_path "$(bundle_file "$old_group")") ($old_name) and $(pretty_path "$(bundle_file "$group")") ($name)"
      return 1
    done <<<"$BUNDLE_ROWS"
    BUNDLE_ROWS+="$group"$'\t'"$type"$'\t'"$name"$'\t'"$identity"$'\n'
  done <<<"$BUNDLE_DECLARATIONS"
}

# Shared by doctor and the package check command. Inventory is loaded by caller.
bundles_check() {
  local group state row_group type name identity failed=0
  for group in "${BUNDLE_GROUPS[@]}"; do
    state="$(bundle_state "$group")" || return 1
    if [[ "$state" == unset ]]; then
      print_error "$group is unset; run 'dot brew bundle enable $group' or 'dot brew bundle disable $group'"
      failed=1
    elif [[ "$state" == enabled ]]; then
      while IFS=$'\t' read -r row_group type name identity; do
        [[ "$row_group" == "$group" ]] || continue
        if ! package_installed "$type" "$identity"; then
          print_error "$group: missing $type $name"
          failed=1
        fi
      done <<<"$BUNDLE_ROWS"
    fi
  done
  [[ "$failed" -ne 0 ]] || print_success "All enabled bundles are installed"
  return "$failed"
}

# bundle_sort FILE: keep the leading comment block, then sorted tap, brew,
# and cask sections, then any other entries in their original order.
bundle_sort() {
  local file="$1" tmp kind lines
  tmp="$(mktemp "$file.XXXXXX")" || return 1
  {
    sed -n '/^#/!q;p' "$file"
    for kind in tap brew cask; do
      lines="$(grep -E "^$kind \"" "$file" | LC_ALL=C sort -u || true)"
      if [[ -n "$lines" ]]; then
        printf '\n%s\n' "$lines"
      fi
    done
    lines="$(grep -vE '^(#|(tap|brew|cask) "|[[:space:]]*$)' "$file" || true)"
    if [[ -n "$lines" ]]; then
      printf '\n%s\n' "$lines"
    fi
  } | sed '1{/^$/d;}' >"$tmp" && mv "$tmp" "$file"
}

# Choices and syntax must be valid before runtime or package changes.
packages_preflight() {
  homebrew_require || return 1
  prefs_validate || return 1
  bundle_read || return 1
  bundles_resolve || return 1
  if ! command_exists jq; then
    # jq is already a declared base dependency. Bootstrap it only for fresh setups,
    # after all choices and source files have been checked, not during reports.
    if ! awk -F '\t' '$1 == "base" && $2 == "formula" && $3 == "jq" { found = 1 } END { exit !found }' <<<"$BUNDLE_DECLARATIONS"; then
      print_error "Metadata validation needs the declared base jq formula"
      return 1
    fi
    print_info "Installing the declared base jq formula for Homebrew metadata"
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_AUTOREMOVE=1 \
      brew install --formula jq || return 1
  fi
  bundle_load
}

# Install missing packages in selected bundles without requesting upgrades.
packages_install() {
  local group state row_group type name identity missing failed=0 file
  packages_preflight || return 1
  PACKAGE_LOADED=false
  package_load_installed || return 1
  for group in "${BUNDLE_GROUPS[@]}"; do
    state="$(bundle_state "$group")" || return 1
    [[ "$state" == enabled ]] || continue
    missing=false
    while IFS=$'\t' read -r row_group type name identity; do
      [[ "$row_group" == "$group" ]] || continue
      if ! package_installed "$type" "$identity"; then missing=true; fi
    done <<<"$BUNDLE_ROWS"
    if [[ "$missing" == false ]]; then
      print_success "$group packages are installed"
      continue
    fi
    file="$(bundle_file "$group")" || return 1
    print_info "Installing missing $group packages (no requested upgrades)"
    if ! HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_AUTOREMOVE=1 \
      brew bundle install --no-upgrade --file "$file"; then
      print_error "Some $group packages failed to install; run 'dot brew check'"
      failed=1
    fi
  done

  migrate_pnpm_opencode
  return "$failed"
}

# homebrew_upgrade: show outdated packages and offer to upgrade them.
homebrew_upgrade() {
  local formulae casks count

  formulae="$(brew outdated --formula --quiet)" || return 1
  casks="$(brew outdated --cask --quiet)" || return 1
  count="$(printf '%s\n%s\n' "$formulae" "$casks" | grep -c . || true)"

  if [[ "$count" -eq 0 ]]; then
    print_success "Homebrew packages are current"
    return 0
  fi

  print_info "$count Homebrew updates are available across all installed packages (including disabled bundles and untracked packages)"
  if [[ -n "$formulae" ]]; then
    print_section "Formulae"
    indent <<<"$formulae"
  fi
  if [[ -n "$casks" ]]; then
    print_section "Casks"
    indent <<<"$casks"
  fi
  echo

  if ! confirm "Upgrade these Homebrew packages?" n; then
    print_info "Skipping Homebrew upgrades"
    return 0
  fi
  if [[ -n "$formulae" ]]; then
    HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade --formula --yes || return 1
  fi
  if [[ -n "$casks" ]]; then
    HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade --cask --yes || return 1
  fi
}

homebrew_check() {
  homebrew_require || return 1
  package_check
}
