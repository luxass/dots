# shellcheck shell=bash
# dot link and dot unlink: the ~/.local/bin/dot symlink that puts dot on PATH.
# conf.d/paths.fish adds ~/.local/bin to PATH.

readonly DOT_LINK_PATH="$HOME/.local/bin/dot"

cmd_link_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot link

Symlink $(pretty_path "$DOT_LINK_PATH") to $(pretty_path "$DOT_ROOT/bin/dot").
An existing symlink is replaced. A regular file is never replaced.
EOF
}

cmd_unlink_usage() {
  cat <<EOF
${BOLD}USAGE${RESET}
  dot unlink

Remove $(pretty_path "$DOT_LINK_PATH") when it is a symlink into this repository.
EOF
}

cmd_link() {
  no_args "$@" || return 1
  if [[ -e "$DOT_LINK_PATH" && ! -L "$DOT_LINK_PATH" ]]; then
    print_error "Refusing to replace $(pretty_path "$DOT_LINK_PATH"): it is not a symlink"
    return 1
  fi
  mkdir -p "$(dirname "$DOT_LINK_PATH")" || return 1
  if ! ln -sfn "$DOT_ROOT/bin/dot" "$DOT_LINK_PATH"; then
    print_error "Failed to create $(pretty_path "$DOT_LINK_PATH")"
    return 1
  fi
  print_success "Linked $(pretty_path "$DOT_LINK_PATH") -> $(pretty_path "$DOT_ROOT/bin/dot")"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) print_warning "$(pretty_path "$HOME/.local/bin") is not on PATH" ;;
  esac
}

cmd_unlink() {
  local value

  no_args "$@" || return 1
  if [[ ! -L "$DOT_LINK_PATH" ]]; then
    print_warning "No dot symlink at $(pretty_path "$DOT_LINK_PATH")"
    return 0
  fi
  value="$(readlink "$DOT_LINK_PATH")"
  if [[ "$value" != "$DOTFILES_DIR"/* ]]; then
    print_error "$(pretty_path "$DOT_LINK_PATH") points outside this repository ($value); not removing it"
    return 1
  fi
  rm "$DOT_LINK_PATH" || return 1
  print_success "Removed $(pretty_path "$DOT_LINK_PATH")"
}
