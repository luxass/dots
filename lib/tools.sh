readonly TOOL_NAMES=(
  "Homebrew" "Brewfile packages" "Stow dotfiles" "Fish shell" "Rustup"
  "Vite+" "Node.js runtime" "Vite+ globals" "Git hooks" "Git identity"
  "dot CLI" "Git" "GNU Stow" "Starship" "Zoxide" "Bun" "Socket Firewall"
)

readonly TOOL_CHECKS=(
  brew - - fish rustup vp node - - - dot git stow starship zoxide bun sfw
)

readonly TOOL_INSTALLERS=(
  ensure_homebrew _install_packages _stow_dotfiles _setup_fish_shell ensure_rustup
  ensure_vite_plus ensure_node_runtime ensure_vite_plus_globals ensure_git_hooks
  ensure_gitconfig_local _link_dot - ensure_stow - - - -
)

readonly TOOL_REQUIRED=(
  true true true false false true true true false false true true true false false false false
)

readonly TOOL_SKIP_FLAGS=(
  - - - - - - - - - - - - - - - - -
)

readonly TOOL_DOCTOR=(
  true false false true true true true false false false true true true true true true true
)

validate_tool_registry() {
  local expected="${#TOOL_NAMES[@]}"

  if [[ "${#TOOL_CHECKS[@]}" -ne "$expected" ||
        "${#TOOL_INSTALLERS[@]}" -ne "$expected" ||
        "${#TOOL_REQUIRED[@]}" -ne "$expected" ||
        "${#TOOL_SKIP_FLAGS[@]}" -ne "$expected" ||
        "${#TOOL_DOCTOR[@]}" -ne "$expected" ]]; then
    print_error "Tool registry columns have different lengths"
    return 1
  fi
}

tool_is_skipped() {
  local skip_flag="$1"
  [[ "$skip_flag" != "-" && "${!skip_flag:-}" == "true" ]]
}

for_each_tool() {
  local visitor="$1"
  local index

  for ((index = 0; index < ${#TOOL_NAMES[@]}; ++index)); do
    "$visitor" \
      "${TOOL_NAMES[$index]}" \
      "${TOOL_CHECKS[$index]}" \
      "${TOOL_INSTALLERS[$index]}" \
      "${TOOL_REQUIRED[$index]}" \
      "${TOOL_SKIP_FLAGS[$index]}" \
      "${TOOL_DOCTOR[$index]}" || return 1
  done
}
