is_repo_path() {
  local target="$1"
  local source="$2"

  [[ -e "$target" ]] && [[ "$(realpath "$target")" == "$(realpath "$source")" ]]
}

backup_path() {
  local target="$1"
  local backup_dir="$2"
  local rel="${target#$HOME/}"
  local dest="$backup_dir/$rel"

  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
  print_info "Backed up $target -> $dest"
}
