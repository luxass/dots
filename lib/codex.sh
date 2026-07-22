codex_config_file() {
  printf '%s\n' "$HOME/.codex/config.toml"
}

codex_resolve_symlink() {
  local link="$1"
  local target parent
  target="$(readlink "$link")"

  if [[ "$target" == /* ]]; then
    parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || return 1
  else
    parent="$(cd "$(dirname "$link")/$(dirname "$target")" 2>/dev/null && pwd -P)" || return 1
  fi

  printf '%s/%s\n' "$parent" "$(basename "$target")"
}

codex_config_is_legacy_link() {
  local config="$1"
  local resolved
  [[ -L "$config" ]] || return 1
  resolved="$(codex_resolve_symlink "$config")" || return 1
  [[ "$resolved" == "$HOME_DIR/.codex/config.toml" ]]
}

render_codex_config() {
  local defaults="$1"
  local current="$2"
  local output="$3"

  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    function table_name(line, value) {
      value = line
      sub(/^[[:space:]]*\[/, "", value)
      sub(/\][[:space:]]*(#.*)?$/, "", value)
      return value
    }

    function array_table_name(line, value) {
      value = line
      sub(/^[[:space:]]*\[\[/, "", value)
      sub(/\]\][[:space:]]*(#.*)?$/, "", value)
      return value
    }

    function assignment_key(line, separator) {
      separator = index(line, "=")
      if (separator == 0) return ""
      return trim(substr(line, 1, separator - 1))
    }

    function emit_missing(section, position, key) {
      for (position = 1; position <= default_count[section]; ++position) {
        key = default_key[section, position]
        if (!emitted[section, key]) {
          print default_line[section, key]
          emitted[section, key] = 1
        }
      }
    }

    FNR == NR {
      if ($0 ~ /^[[:space:]]*($|#)/) next

      if ($0 ~ /^[[:space:]]*\[[^][]+\][[:space:]]*(#.*)?$/) {
        defaults_section = table_name($0)
        if (!(defaults_section in default_section_seen)) {
          default_section_seen[defaults_section] = 1
          default_section_order[++default_section_total] = defaults_section
        }
        next
      }

      key = assignment_key($0)
      if (key == "") {
        print "Invalid portable Codex default: " $0 > "/dev/stderr"
        invalid_defaults = 1
        next
      }

      default_key[defaults_section, ++default_count[defaults_section]] = key
      default_line[defaults_section, key] = $0
      next
    }

    {
      if ($0 ~ /^[[:space:]]*\[\[[^][]+\]\][[:space:]]*(#.*)?$/) {
        if (!root_flushed) {
          emit_missing("")
          root_flushed = 1
        }
        if (current_section != "") emit_missing(current_section)

        current_section = "@array:" array_table_name($0)
        print
        next
      }

      if ($0 ~ /^[[:space:]]*\[[^][]+\][[:space:]]*(#.*)?$/) {
        if (!root_flushed) {
          emit_missing("")
          root_flushed = 1
        }
        if (current_section != "") emit_missing(current_section)

        current_section = table_name($0)
        section_present[current_section] = 1
        print
        next
      }

      key = assignment_key($0)
      if (key != "" && ((current_section SUBSEP key) in default_line)) {
        if (!emitted[current_section, key]) print default_line[current_section, key]
        emitted[current_section, key] = 1
        next
      }

      print
    }

    END {
      if (invalid_defaults) exit 2

      if (!root_flushed) emit_missing("")
      if (current_section != "") emit_missing(current_section)

      for (section_index = 1; section_index <= default_section_total; ++section_index) {
        section = default_section_order[section_index]
        if (!section_present[section]) {
          print ""
          print "[" section "]"
          emit_missing(section)
        }
      }
    }
  ' "$defaults" "$current" > "$output"
}

sync_codex_config() {
  local config config_dir tmp
  config="$(codex_config_file)"
  config_dir="$(dirname "$config")"

  [[ -f "$CODEX_DEFAULTS_FILE" ]] || {
    print_error "Missing Codex defaults: $CODEX_DEFAULTS_FILE"
    return 1
  }

  if [[ -L "$config" ]] && ! codex_config_is_legacy_link "$config"; then
    print_error "Refusing to replace unmanaged Codex config symlink: $config"
    return 1
  fi

  if [[ -e "$config" && ! -f "$config" ]]; then
    print_error "Codex config path is not a file: $config"
    return 1
  fi

  mkdir -p "$config_dir" || return 1
  umask 077
  tmp="$(mktemp "$config_dir/.config.toml.tmp.XXXXXX")" || return 1

  if [[ -f "$config" ]]; then
    if ! render_codex_config "$CODEX_DEFAULTS_FILE" "$config" "$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  else
    if ! cp "$CODEX_DEFAULTS_FILE" "$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  fi

  if ! chmod 600 "$tmp" || ! mv -f "$tmp" "$config"; then
    rm -f "$tmp"
    return 1
  fi
  print_success "Synchronized portable Codex preferences"
}

check_codex_config() {
  local config tmp
  config="$(codex_config_file)"

  if [[ ! -f "$CODEX_DEFAULTS_FILE" ]]; then
    print_error "Missing Codex defaults: $CODEX_DEFAULTS_FILE"
    return 1
  fi

  if [[ -L "$config" ]]; then
    print_error "Codex config is still a symlink; run 'dot codex sync'"
    return 1
  fi

  if [[ ! -f "$config" ]]; then
    print_error "Missing Codex config; run 'dot codex sync'"
    return 1
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/dot-codex-check.XXXXXX")" || return 1
  if ! render_codex_config "$CODEX_DEFAULTS_FILE" "$config" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if cmp -s "$config" "$tmp"; then
    rm -f "$tmp"
    print_success "Codex config"
    return 0
  fi

  rm -f "$tmp"
  print_error "Codex portable preferences are out of sync; run 'dot codex sync'"
  return 1
}

cmd_codex_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} codex${RESET}

Usage:
  ${SCRIPT_NAME} codex sync

Synchronize tracked portable preferences into Codex's local config while
preserving machine-local and generated state.
EOF
}

cmd_codex() {
  local subcommand="${1:-help}"
  shift || true

  case "$subcommand" in
    sync)
      [[ "$#" -eq 0 ]] || { print_error "Usage: ${SCRIPT_NAME} codex sync"; return 1; }
      sync_codex_config
      ;;
    help|-h|--help)
      cmd_codex_help
      ;;
    *)
      print_error "Unknown codex command: $subcommand"
      cmd_codex_help
      return 1
      ;;
  esac
}
