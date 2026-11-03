# shellcheck shell=bash
# Path, link, and backup helpers.

# Backups from one dot run share a timestamped directory.
DOT_RUN_ID="$(date +%Y%m%d-%H%M%S)"

# same_path A B: both exist and resolve to the same file.
same_path() {
  [[ -e "$1" && -e "$2" ]] && [[ "$(realpath "$1")" == "$(realpath "$2")" ]]
}

# Normalize a path without requiring its destination to still exist.
lexical_path() {
  local path="$1" part result=''
  [[ "$path" == /* ]] || path="$PWD/$path"
  while [[ -n "$path" ]]; do
    part="${path%%/*}"
    if [[ "$path" == */* ]]; then
      path="${path#*/}"
    else
      path=''
    fi
    case "$part" in
      '' | .) ;;
      ..) result="${result%/*}" ;;
      *) result="$result/$part" ;;
    esac
  done
  printf '%s\n' "${result:-/}"
}

# Recognize legacy repo links even after their old sources have moved.
link_points_to() {
  local target="$1" source="$2" value
  [[ -L "$target" ]] || return 1
  same_path "$target" "$source" && return 0
  value="$(readlink "$target")" || return 1
  [[ "$value" == /* ]] || value="$(dirname "$target")/$value"
  [[ "$(lexical_path "$value")" == "$(lexical_path "$source")" ]]
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

# Unfold a legacy directory link. Native Stow relinks its managed children.
local_config_dir() {
  local rel="$1"
  local target="$HOME/$rel" source="$LEGACY_HOME_DIR/$rel"

  if link_points_to "$target" "$source"; then
    rm "$target" || return 1
    mkdir -p "$target" || return 1
  elif [[ -L "$target" || (-e "$target" && ! -d "$target") ]]; then
    print_error "Cannot keep $(pretty_path "$target") local; it belongs to another setup"
    return 1
  else
    mkdir -p "$target" || return 1
  fi
}

# Move legacy data locally, or to an explicit destination for shared skills.
# Existing destination files win; duplicate legacy copies are backed up.
local_state_move() {
  local rel="$1" entry sockets=''
  local source="$LEGACY_HOME_DIR/$rel" target="${2:-$HOME/$rel}" linked=false

  [[ -e "$source" || -L "$source" ]] || return 0
  if [[ -S "$source" ]]; then
    # Preserve access after an old parent directory link has been unfolded.
    if [[ ! -e "$target" && ! -L "$target" ]]; then
      mkdir -p "$(dirname "$target")" || return 1
      ln -s "$source" "$target" || return 1
    fi
    print_warning "Leaving socket in place: $(pretty_path "$source")"
    return 0
  fi
  if [[ -d "$source" && ! -L "$source" ]]; then
    sockets="$(find "$source" -type s -print -quit)" || return 1
  fi

  if link_points_to "$target" "$source"; then
    linked=true
  elif [[ -d "$source" && ! -L "$source" && -d "$target" && ! -L "$target" ]]; then
    : # Merge the directories below.
  elif [[ -e "$target" || -L "$target" ]]; then
    print_info "Keeping existing local state at $(pretty_path "$target")"
    if [[ -n "$sockets" ]]; then
      print_warning "Leaving legacy directory with sockets in place: $(pretty_path "$source")"
      return 0
    fi
    backup_path "$source" || return 1
    return 0
  fi

  if [[ -d "$source" && ! -L "$source" ]] && { [[ -d "$target" && ! -L "$target" ]] || [[ -n "$sockets" ]]; }; then
    if [[ "$linked" == true ]]; then
      rm "$target" || return 1
    fi
    mkdir -p "$target" || return 1
    for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      local_state_move "$rel/${entry##*/}" "$target/${entry##*/}" || return 1
    done
    if [[ -z "$(find "$source" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      rmdir "$source" || return 1
    fi
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
  print_info "Moved legacy data to $(pretty_path "$target")"
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
