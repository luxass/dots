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

# Keep a configuration directory local. Stow relinks its tracked children.
local_config_dir() {
  local rel="$1"
  local target="$HOME/$rel" source="$HOME_DIR/$rel"

  if [[ -L "$target" ]] && same_path "$target" "$source"; then
    rm "$target" || return 1
    mkdir -p "$target" || return 1
  elif [[ -L "$target" || (-e "$target" && ! -d "$target") ]]; then
    print_error "Cannot keep $(pretty_path "$target") local; it belongs to another setup"
    return 1
  else
    mkdir -p "$target" || return 1
  fi
}

# Move runtime data out of home/. Merge directories and back up conflicting sources.
local_state_move() {
  local rel="$1" entry
  local source="$HOME_DIR/$rel" target="$HOME/$rel" linked=false

  [[ -e "$source" || -L "$source" ]] || return 0
  if [[ -S "$source" ]]; then
    print_warning "Leaving socket in place: $(pretty_path "$source")"
    return 0
  fi
  if [[ -L "$target" ]] && same_path "$target" "$source"; then
    linked=true
  elif [[ -d "$source" && ! -L "$source" && -d "$target" && ! -L "$target" ]]; then
    for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      local_state_move "$rel/${entry##*/}" || return 1
    done
    # Skipped sockets can leave the source directory nonempty.
    if [[ -z "$(find "$source" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      rmdir "$source" || return 1
    fi
    return 0
  elif [[ -e "$target" || -L "$target" ]]; then
    print_info "Keeping existing local state at $(pretty_path "$target")"
    backup_path "$source" || return 1
    return 0
  fi

  mkdir -p "$(dirname "$target")" || return 1
  if [[ "$linked" == true ]]; then
    rm "$target" || return 1
  fi
  if ! mv "$source" "$target"; then
    if [[ "$linked" == true ]]; then
      ln -s "$source" "$target" || return 1
    fi
    return 1
  fi
  print_info "Moved runtime state to $(pretty_path "$target")"
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
