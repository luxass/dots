#!/usr/bin/env bats
# Rex: the app is found by bundle ID, not by name.
# shellcheck disable=SC2329 # rex_app_running calls the lsappinfo stubs

setup() {
  load "../../tests/test-helpers"
  load_dot_for_test
}

teardown() {
  cleanup_dot_test
}

# make_test_app NAME BUNDLE_ID: an app bundle in the temporary ~/Applications.
make_test_app() {
  local plist="$HOME/Applications/$1.app/Contents/Info.plist"
  mkdir -p "$(dirname "$plist")"
  plutil -create xml1 "$plist"
  plutil -insert CFBundleIdentifier -string "$2" "$plist"
}

@test "rex_installed_apps finds a renamed Rex and ignores other apps" {
  make_test_app "Renamed Rex (test)" "$REX_BUNDLE_ID"
  make_test_app "Not Rex" com.example.other

  run rex_installed_apps
  [ "$status" -eq 0 ]
  [[ "$output" == *"$HOME/Applications/Renamed Rex (test).app"* ]]
  [[ "$output" != *"Not Rex"* ]]
}

@test "rex_app_running asks Launch Services by bundle ID" {
  lsappinfo() { :; }
  assert_fails rex_app_running

  lsappinfo() { printf 'ASN:0x0-0x1:\n'; }
  rex_app_running
}
