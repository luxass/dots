# shellcheck shell=bash
# Path, link, and backup helpers.

# Backups from one dot run share a timestamped directory.
DOT_RUN_ID="$(date +%Y%m%d-%H%M%S)"

# same_path A B: both exist and resolve to the same file.
same_path() {
  [[ -e "$1" && -e "$2" ]] && [[ "$(realpath "$1")" == "$(realpath "$2")" ]]
}

# backup_path PATH: move PATH into this run's backup directory.
backup_path() {
  local target="$1" dest
  dest="$BACKUP_ROOT/$DOT_RUN_ID/${target#"$HOME"/}"
  mkdir -p "$(dirname "$dest")" || return 1
  mv "$target" "$dest" || return 1
  print_info "Backed up $(pretty_path "$target") -> $(pretty_path "$dest")"
}

# ensure_link TARGET VALUE: make TARGET a symlink to VALUE. Anything else at
# TARGET is backed up first. Quiet when the link is already correct.
ensure_link() {
  local target="$1" value="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$value" ]]; then
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup_path "$target" || return 1
  fi

  mkdir -p "$(dirname "$target")" || return 1
  ln -s "$value" "$target" || return 1
  print_success "Linked $(pretty_path "$target") -> $(pretty_path "$value")"
}

# check_link TARGET SOURCE LABEL: TARGET is a symlink that resolves to SOURCE.
check_link() {
  local target="$1" source="$2" label="$3"

  if [[ -L "$target" ]] && same_path "$target" "$source"; then
    print_success "$label"
    return 0
  fi
  print_error "$label is missing at $(pretty_path "$target"); run 'dot stow'"
  return 1
}
