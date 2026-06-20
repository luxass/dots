dot_config_dir() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/dot"
}

dot_config_file() {
  printf '%s\n' "$(dot_config_dir)/preferences"
}

config_key_valid() {
  local key="$1"
  [[ "$key" =~ ^[a-z0-9]+(\.[a-z0-9]+)*$ ]]
}

config_require_key() {
  local key="$1"

  if ! config_key_valid "$key"; then
    print_error "Invalid config key: $key"
    print_info "Use lowercase/digit dotted keys, for example: packages.brew.fonts.enabled"
    return 1
  fi
}

config_normalize_value() {
  local key="$1"
  local value="$2"

  case "$value" in
    *$'\n'*|*$'\r'*)
      print_error "Config values cannot contain newlines"
      return 1
      ;;
  esac

  if [[ "$key" == *.enabled ]]; then
    case "${value,,}" in
      true|yes|y|1|on) printf 'true\n' ;;
      false|no|n|0|off) printf 'false\n' ;;
      *)
        print_error "$key must be a boolean value"
        print_info "Use true/false, yes/no, on/off, or 1/0"
        return 1
        ;;
    esac
  else
    printf '%s\n' "$value"
  fi
}

config_list() {
  local file
  file="$(dot_config_file)"

  [[ -f "$file" ]] || return 0

  local line key
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    if [[ "$line" != *=* ]] || ! config_key_valid "$key"; then
      print_warning "Ignoring invalid config line in $file: $line"
      continue
    fi
    printf '%s\n' "$line"
  done < "$file"
}

config_get() {
  local key="$1"
  config_require_key "$key" || return 1

  local file line current_key
  file="$(dot_config_file)"
  [[ -f "$file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
    current_key="${line%%=*}"
    [[ "$current_key" == "$key" ]] || continue
    printf '%s\n' "${line#*=}"
    return 0
  done < "$file"

  return 1
}

config_is_set() {
  local key="$1"
  config_get "$key" >/dev/null
}

config_set() {
  local key="$1"
  local raw_value="$2"
  config_require_key "$key" || return 1

  local value
  value="$(config_normalize_value "$key" "$raw_value")" || return 1

  local dir file tmp found line current_key
  dir="$(dot_config_dir)"
  file="$(dot_config_file)"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.preferences.tmp.XXXXXX")"
  found=false

  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -z "$line" || "$line" == \#* || "$line" != *=* ]]; then
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi

      current_key="${line%%=*}"
      if [[ "$current_key" == "$key" ]]; then
        if [[ "$found" == false ]]; then
          printf '%s=%s\n' "$key" "$value" >> "$tmp"
          found=true
        fi
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
  fi

  if [[ "$found" == false ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi

  mv "$tmp" "$file"
}

config_unset() {
  local key="$1"
  config_require_key "$key" || return 1

  local file dir tmp line current_key removed
  file="$(dot_config_file)"
  [[ -f "$file" ]] || return 0

  dir="$(dot_config_dir)"
  tmp="$(mktemp "$dir/.preferences.tmp.XXXXXX")"
  removed=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" == \#* || "$line" != *=* ]]; then
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi

    current_key="${line%%=*}"
    if [[ "$current_key" == "$key" ]]; then
      removed=true
      continue
    fi

    printf '%s\n' "$line" >> "$tmp"
  done < "$file"

  mv "$tmp" "$file"
}

config_reset() {
  local file
  file="$(dot_config_file)"
  rm -f "$file"
}

cmd_config_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} config${RESET}

Usage:
  ${SCRIPT_NAME} config list
  ${SCRIPT_NAME} config get KEY
  ${SCRIPT_NAME} config set KEY VALUE
  ${SCRIPT_NAME} config unset KEY
  ${SCRIPT_NAME} config reset

Preferences are local-only and stored at:
  $(dot_config_file)
EOF
}

cmd_config() {
  local subcommand="${1:-list}"
  shift || true

  case "$subcommand" in
    list)
      config_list
      ;;
    get)
      [[ "$#" -eq 1 ]] || { print_error "Usage: ${SCRIPT_NAME} config get KEY"; return 1; }
      config_get "$1"
      ;;
    set)
      [[ "$#" -ge 2 ]] || { print_error "Usage: ${SCRIPT_NAME} config set KEY VALUE"; return 1; }
      local key="$1"
      shift
      local value="$*"
      config_set "$key" "$value"
      ;;
    unset)
      [[ "$#" -eq 1 ]] || { print_error "Usage: ${SCRIPT_NAME} config unset KEY"; return 1; }
      config_unset "$1"
      ;;
    reset)
      [[ "$#" -eq 0 ]] || { print_error "Usage: ${SCRIPT_NAME} config reset"; return 1; }
      config_reset
      ;;
    help|-h|--help)
      cmd_config_help
      ;;
    *)
      print_error "Unknown config command: $subcommand"
      cmd_config_help
      return 1
      ;;
  esac
}
