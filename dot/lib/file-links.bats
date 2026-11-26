#!/usr/bin/env bats
# File link helpers: lexical paths and links into the repository.

setup() {
  load "../tests/test-helpers"
  load_dot_for_test
}

teardown() {
  cleanup_dot_test
}

@test "lexical_path removes dot segments and repeated slashes without reading the disk" {
  [ "$(lexical_path /a/b/../c)" = /a/c ]
  [ "$(lexical_path /a/./b//c/)" = /a/b/c ]
  [ "$(lexical_path /../a)" = /a ]
  [ "$(lexical_path /missing/dir/../file)" = /missing/file ]
  [ "$(lexical_path /)" = / ]
}

@test "link_points_into_repo resolves absolute and relative targets, even when missing" {
  mkdir -p "$HOME/links"
  ln -s "$DOTFILES_DIR/missing-file" "$HOME/links/absolute"
  ln -s "$(relative_path_to_root "$HOME/links")${DOTFILES_DIR#/}/missing-file" "$HOME/links/relative"
  ln -s /elsewhere/missing-file "$HOME/links/outside"

  link_points_into_repo "$HOME/links/absolute"
  link_points_into_repo "$HOME/links/relative"
  assert_fails link_points_into_repo "$HOME/links/outside"
}
