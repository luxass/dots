# shellcheck shell=bash
# Package lists: the Brewfiles that say what this Mac should have installed.
#   packages/bundle       base: every machine
#   packages/bundle.work  work: formulas only; init asks before installing it
# Entries are read as "<type><TAB><name>", where type is brew or cask.
# Installing them is package-manager.sh's job.

# package_list_file base|work: print the Brewfile for a package list name.
package_list_file() {
  case "$1" in
    base) printf '%s\n' "$PACKAGES_DIR/bundle" ;;
    work) printf '%s\n' "$PACKAGES_DIR/bundle.work" ;;
    *)
      print_error "Unknown package list '$1': expected base or work"
      return 1
      ;;
  esac
}

# package_list_names: print the package lists, base first, then work when
# packages/bundle.work exists.
package_list_names() {
  printf 'base\n'
  if [[ -f "$PACKAGES_DIR/bundle.work" ]]; then
    printf 'work\n'
  fi
}

# parse_brewfile_entry LINE: print "<brew|cask><TAB><name>". Fails for other
# lines, such as comments, blank lines, and taps.
parse_brewfile_entry() {
  local line="$1"

  [[ "$line" =~ ^[[:space:]]*# ]] && return 1
  [[ -z "${line//[[:space:]]/}" ]] && return 1
  if [[ "$line" =~ ^[[:space:]]*brew[[:space:]]+\"([^\"]+)\" ]]; then
    printf 'brew\t%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$line" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
    printf 'cask\t%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# read_package_list FILE: print every entry of a Brewfile as "<type><TAB><name>".
read_package_list() {
  local list_file="$1" line parsed

  [[ -f "$list_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    parsed="$(parse_brewfile_entry "$line")" || continue
    printf '%s\n' "$parsed"
  done <"$list_file"
}

# package_list_entry_type FILE NAME: print the type of a package in a Brewfile, or fail.
package_list_entry_type() {
  local list_file="$1" package_name="$2" entry_type entry_name

  while IFS=$'\t' read -r entry_type entry_name; do
    if [[ "$entry_name" == "$package_name" ]]; then
      printf '%s\n' "$entry_type"
      return 0
    fi
  done < <(read_package_list "$list_file")
  return 1
}

# package_list_add FILE TYPE NAME: add a package to a Brewfile in sorted
# order. Formulas stay before casks. Comments and taps stay where they are.
package_list_add() {
  local list_file="$1" package_type="$2" package_name="$3"
  local package_line="$2 \"$3\"" inserted=false temp_file line parsed existing_type existing_name

  mkdir -p "$(dirname "$list_file")" || return 1
  [[ -f "$list_file" ]] || touch "$list_file" || return 1
  temp_file="$(mktemp "$list_file.XXXXXX")" || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$inserted" == false ]] && parsed="$(parse_brewfile_entry "$line")"; then
      IFS=$'\t' read -r existing_type existing_name <<<"$parsed"
      if [[ "$existing_type" == "$package_type" && "$package_name" < "$existing_name" ]] \
        || [[ "$package_type" == brew && "$existing_type" == cask ]]; then
        printf '%s\n' "$package_line" >>"$temp_file"
        inserted=true
      fi
    fi
    printf '%s\n' "$line" >>"$temp_file"
  done <"$list_file"
  if [[ "$inserted" == false ]]; then
    printf '%s\n' "$package_line" >>"$temp_file"
  fi
  mv "$temp_file" "$list_file"
}

# package_list_remove FILE NAME: remove a package from a Brewfile and print
# the removed entry's type. Fails when the package is not in the file.
package_list_remove() {
  local list_file="$1" package_name="$2" removed_type temp_file line parsed entry_type entry_name

  removed_type="$(package_list_entry_type "$list_file" "$package_name")" || return 1
  temp_file="$(mktemp "$list_file.XXXXXX")" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    if parsed="$(parse_brewfile_entry "$line")"; then
      IFS=$'\t' read -r entry_type entry_name <<<"$parsed"
      [[ "$entry_name" == "$package_name" ]] && continue
    fi
    printf '%s\n' "$line" >>"$temp_file"
  done <"$list_file"
  mv "$temp_file" "$list_file" || return 1
  printf '%s\n' "$removed_type"
}

# validate_work_brewfile FILE: the work Brewfile takes formulas only. Casks
# belong in packages/bundle.
validate_work_brewfile() {
  local entry_type entry_name

  while IFS=$'\t' read -r entry_type entry_name; do
    if [[ "$entry_type" == cask ]]; then
      print_error "Work Brewfile contains cask '$entry_name'; casks belong in packages/bundle"
      return 1
    fi
  done < <(read_package_list "$1")
}
