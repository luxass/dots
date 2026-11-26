#!/usr/bin/env bats
# Package lists: Brewfile parsing and editing.

setup() {
  load "../tests/test-helpers"
  load_dot_for_test
  BREWFILE="$DOT_PACKAGES_DIR/bundle"
  cat >"$BREWFILE" <<'EOF'
# Base packages.
tap "example/tap", trusted: true

brew "bat"
brew "fd"

cask "ghostty"
EOF
}

teardown() {
  cleanup_dot_test
}

@test "parse_brewfile_entry reads formulas and casks, and skips comments and taps" {
  [ "$(parse_brewfile_entry 'brew "ripgrep"')" = $'brew\tripgrep' ]
  [ "$(parse_brewfile_entry '  cask "slack"')" = $'cask\tslack' ]
  assert_fails parse_brewfile_entry '# brew "commented"'
  assert_fails parse_brewfile_entry 'tap "example/tap", trusted: true'
  assert_fails parse_brewfile_entry ''
}

@test "package_list_add keeps formulas sorted and before casks" {
  package_list_add "$BREWFILE" brew cat
  package_list_add "$BREWFILE" brew zoxide
  package_list_add "$BREWFILE" cask arc

  [ "$(read_package_list "$BREWFILE" | tr '\t' ' ')" = $'brew bat\nbrew cat\nbrew fd\nbrew zoxide\ncask arc\ncask ghostty' ]
  grep -qx '# Base packages.' "$BREWFILE"
  grep -qx 'tap "example/tap", trusted: true' "$BREWFILE"
}

@test "package_list_remove prints the removed type and keeps other lines" {
  [ "$(package_list_remove "$BREWFILE" ghostty)" = cask ]
  assert_fails grep -q ghostty "$BREWFILE"
  grep -qx 'brew "fd"' "$BREWFILE"
  grep -qx 'tap "example/tap", trusted: true' "$BREWFILE"

  run package_list_remove "$BREWFILE" missing
  [ "$status" -eq 1 ]
}

@test "the work Brewfile takes formulas only" {
  printf 'brew "kind"\ncask "slack"\n' >"$DOT_PACKAGES_DIR/bundle.work"
  run validate_work_brewfile "$DOT_PACKAGES_DIR/bundle.work"
  [ "$status" -eq 1 ]
  [[ "$output" == *"casks belong in packages/bundle"* ]]
}

@test "the tracked work Brewfile has no casks" {
  validate_work_brewfile "$DOTFILES_DIR/packages/bundle.work"
}

@test "package_list_names lists work only when its Brewfile exists" {
  [ "$(package_list_names)" = base ]
  touch "$DOT_PACKAGES_DIR/bundle.work"
  [ "$(package_list_names)" = $'base\nwork' ]
}
