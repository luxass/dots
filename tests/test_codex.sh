#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOT="$ROOT/dot"
readonly SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_STATE_HOME="$SANDBOX/state"
mkdir -p "$HOME"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  return 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  grep -Fqx "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fqx "$unexpected" "$file"; then
    fail "expected $file not to contain: $unexpected"
  fi
}

test_sync_bootstraps_local_config() {
  local config="$HOME/.codex/config.toml"

  "$DOT" codex sync >/dev/null

  [[ -f "$config" ]] || fail "Codex config was not created"
  [[ ! -L "$config" ]] || fail "Codex config should be a local file"
  assert_file_contains "$config" 'model = "gpt-5.6-sol"'
  assert_file_contains "$config" 'default_mode_request_user_input = true'
}

test_sync_preserves_codex_owned_state() {
  local config="$HOME/.codex/config.toml"
  mkdir -p "$(dirname "$config")"
  printf '%s\n' \
    'model = "old-model"' \
    'notify = ["/local/notifier"]' \
    '' \
    '[features]' \
    'default_mode_request_user_input = false' \
    'generated_feature = true' \
    '' \
    '[projects."/local/project"]' \
    'trust_level = "trusted"' > "$config"

  "$DOT" codex sync >/dev/null

  assert_file_contains "$config" 'model = "gpt-5.6-sol"'
  assert_file_contains "$config" 'personality = "pragmatic"'
  assert_file_not_contains "$config" 'model = "old-model"'
  assert_file_contains "$config" 'notify = ["/local/notifier"]'
  assert_file_contains "$config" 'default_mode_request_user_input = true'
  assert_file_contains "$config" 'generated_feature = true'
  assert_file_contains "$config" '[projects."/local/project"]'
  assert_file_contains "$config" 'trust_level = "trusted"'

  local first_sync
  first_sync="$(cksum < "$config")"
  "$DOT" codex sync >/dev/null
  [[ "$(cksum < "$config")" == "$first_sync" ]] || fail "Codex sync was not idempotent"
}

test_sync_migrates_legacy_stow_link() {
  local config="$HOME/.codex/config.toml"
  rm -f "$config"
  ln -s "$ROOT/home/.codex/config.toml" "$config"

  "$DOT" codex sync >/dev/null

  [[ -f "$config" ]] || fail "Migrated Codex config is missing"
  [[ ! -L "$config" ]] || fail "Legacy Codex config symlink was not replaced"
  assert_file_contains "$config" 'model = "gpt-5.6-sol"'
}

test_sync_refuses_unmanaged_symlink() {
  local config="$HOME/.codex/config.toml"
  local unmanaged="$SANDBOX/unmanaged-config.toml"
  printf '%s\n' 'unmanaged = true' > "$unmanaged"
  rm -f "$config"
  ln -s "$unmanaged" "$config"

  if "$DOT" codex sync >/dev/null 2>&1; then
    fail "Codex sync replaced an unmanaged symlink"
  fi

  [[ -L "$config" ]] || fail "Unmanaged Codex config symlink was removed"
  assert_file_contains "$unmanaged" 'unmanaged = true'
}

test_sync_keeps_defaults_in_their_table_before_array_tables() {
  local config="$HOME/.codex/config.toml"
  local preference_line hook_line
  rm -f "$config"
  printf '%s\n' \
    '[features]' \
    'generated_feature = true' \
    '' \
    '[[hooks.Stop]]' \
    'command = "keep-local-hook"' > "$config"

  "$DOT" codex sync >/dev/null

  preference_line="$(grep -nF 'default_mode_request_user_input = true' "$config" | cut -d: -f1)"
  hook_line="$(grep -nF '[[hooks.Stop]]' "$config" | cut -d: -f1)"
  [[ "$preference_line" -lt "$hook_line" ]] || fail "Feature preference escaped into an array table"
  assert_file_contains "$config" 'command = "keep-local-hook"'
}

test_sync_refuses_non_file_config_path() {
  local config="$HOME/.codex/config.toml"
  rm -f "$config"
  mkdir -p "$config"

  if "$DOT" codex sync >/dev/null 2>&1; then
    fail "Codex sync accepted a directory as config.toml"
  fi

  [[ -d "$config" ]] || fail "Codex config directory was unexpectedly replaced"
}

test_sync_bootstraps_local_config
test_sync_preserves_codex_owned_state
test_sync_migrates_legacy_stow_link
test_sync_refuses_unmanaged_symlink
test_sync_keeps_defaults_in_their_table_before_array_tables
test_sync_refuses_non_file_config_path
