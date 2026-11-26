#!/usr/bin/env bats
# Stow doctor checks: broken links into the repository.

setup() {
  load "../../tests/test-helpers"
  load_dot_for_test
}

teardown() {
  cleanup_dot_test
}

@test "stow_broken_links reports only broken links into the repository" {
  local conf_dir="$HOME/.config/fish/conf.d"
  mkdir -p "$HOME/.local/bin" "$HOME/.agents" "$conf_dir"

  # Broken links into the repository: absolute, relative, and a moved entry point.
  ln -s "$DOTFILES_DIR/dot-entry-that-moved" "$HOME/.local/bin/dot"
  ln -s "$(relative_path_to_root "$HOME/.agents")${DOTFILES_DIR#/}/shared/missing-skills" "$HOME/.agents/skills"
  ln -s "$(relative_path_to_root "$conf_dir")${DOTFILES_DIR#/}/stow/fish/.config/fish/conf.d/removed.fish" "$conf_dir/removed.fish"
  # Not reported: a working link into the repository, and a broken link elsewhere.
  ln -s "$DOTFILES_DIR/README.md" "$HOME/.local/bin/readme"
  ln -s /elsewhere/missing "$HOME/.local/bin/other"

  run stow_broken_links
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.agents/skills
$conf_dir/removed.fish
$HOME/.local/bin/dot" ]
}

@test "stow_broken_links prints nothing when every link works" {
  mkdir -p "$HOME/.local/bin"
  ln -s "$DOTFILES_DIR/README.md" "$HOME/.local/bin/readme"
  [ -z "$(stow_broken_links)" ]
}

@test "broken_link_fix names the command that owns each link" {
  [ "$(broken_link_fix "$HOME/.local/bin/dot")" = "dot link" ]
  [ "$(broken_link_fix "$HOME/.agents/skills")" = "dot init --only skills" ]
  [ "$(broken_link_fix "$SKILLS_STATE_LOCK")" = "dot init --only skills" ]
  [ "$(broken_link_fix "$HOME/.config/fish/conf.d/removed.fish")" = "dot stow" ]
}
