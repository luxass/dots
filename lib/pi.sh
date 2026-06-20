readonly PI_PACKAGE_JSON="${HOME_DIR}/.pi/package.json"
readonly PI_SETTINGS_JSON="${HOME_DIR}/.pi/agent/settings.json"
readonly PI_SKILLS_DIR="${HOME_DIR}/.pi/agent/skills"
readonly PI_SKILLS_LOCK="${HOME_DIR}/.pi/skills-lock.json"
readonly SKILLS_CLI_PACKAGE="${SKILLS_CLI_PACKAGE:-skills}"
readonly PLANNOTATOR_PACKAGE="@plannotator/pi-extension"

require_pi_tooling() {
  local failed=0

  for tool in pi pnpm node; do
    if command_exists "$tool"; then
      continue
    fi
    print_error "$tool is required for Pi management"
    failed=1
  done

  return "$failed"
}

pi_package_version() {
  local package_name="$1"

  node -e '
    const fs = require("fs");
    const packagePath = process.argv[1];
    const packageName = process.argv[2];
    const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
    const version = pkg.dependencies?.[packageName] ?? pkg.devDependencies?.[packageName];
    if (version) console.log(version);
  ' "$PI_PACKAGE_JSON" "$package_name"
}

latest_pi_version() {
  pnpm view @earendil-works/pi-coding-agent version 2>/dev/null
}

set_pi_package_version() {
  local version="$1"

  node -e '
    const fs = require("fs");
    const packagePath = process.argv[1];
    const version = process.argv[2];
    const packageNames = [
      "@earendil-works/pi-ai",
      "@earendil-works/pi-coding-agent",
      "@earendil-works/pi-tui",
    ];
    const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
    pkg.dependencies ??= {};
    for (const packageName of packageNames) {
      if (Object.hasOwn(pkg.dependencies, packageName)) {
        pkg.dependencies[packageName] = version;
      }
    }
    fs.writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`);
  ' "$PI_PACKAGE_JSON" "$version"
}

ensure_plannotator_share_disabled() {
  local env_line='set -gx PLANNOTATOR_SHARE disabled'
  local fish_env="${HOME_DIR}/.config/fish/conf.d/env.fish"

  mkdir -p "$(dirname "$fish_env")"

  if grep -q '^set -gx PLANNOTATOR_SHARE ' "$fish_env" 2>/dev/null; then
    print_success "PLANNOTATOR_SHARE is already configured"
    return 0
  fi

  {
    printf '\n'
    printf '# Plannotator sharing is opt-in for Pi sessions.\n'
    printf '%s\n' "$env_line"
  } >> "$fish_env"

  print_success "Disabled Plannotator sharing by default"
}

print_pi_settings_packages() {
  node -e '
    const fs = require("fs");
    const settingsPath = process.argv[1];
    if (!fs.existsSync(settingsPath)) {
      console.log("Settings packages: missing settings file");
      process.exit(0);
    }

    const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
    const keys = ["packages", "extensions"];
    let printed = false;
    for (const key of keys) {
      const value = settings[key];
      if (!value) continue;
      printed = true;
      console.log(`${key}:`);
      if (Array.isArray(value)) {
        for (const item of value) console.log(`  ${typeof item === "string" ? item : JSON.stringify(item)}`);
      } else {
        for (const [name, item] of Object.entries(value)) console.log(`  ${name}: ${typeof item === "string" ? item : JSON.stringify(item)}`);
      }
    }
    if (!printed) console.log("Settings packages: none");
  ' "$PI_SETTINGS_JSON"
}

cmd_pi_status() {
  print_header "Pi status"

  if command_exists pi; then
    printf "Installed Pi:        "
    pi --version
  else
    echo "Installed Pi:        missing"
  fi

  if command_exists pnpm; then
    printf "Latest Pi npm:       "
    pnpm view @earendil-works/pi-coding-agent version 2>/dev/null || echo "unknown"
    printf "Latest Plannotator:  "
    pnpm view "$PLANNOTATOR_PACKAGE" version 2>/dev/null || echo "unknown"
  else
    echo "Latest Pi npm:       pnpm missing"
    echo "Latest Plannotator:  pnpm missing"
  fi

  if [[ -f "$PI_PACKAGE_JSON" ]]; then
    printf "Pinned Pi package:   "
    pi_package_version "@earendil-works/pi-coding-agent" || echo "unknown"
  else
    echo "Pinned Pi package:   missing $PI_PACKAGE_JSON"
  fi

  echo
  print_header "Configured Pi packages"
  if command_exists pi; then
    pi list || true
  else
    print_warning "pi is not installed"
  fi
  print_pi_settings_packages
}

cmd_pi_update() {
  local version="${1:-}"

  require_pi_tooling || return 1

  if [[ ! -f "$PI_PACKAGE_JSON" ]]; then
    print_error "Missing $PI_PACKAGE_JSON"
    return 1
  fi

  if [[ -z "$version" ]]; then
    print_info "Checking latest Pi version"
    version="$(latest_pi_version)"
    if [[ -z "$version" ]]; then
      print_error "Could not determine latest Pi version"
      return 1
    fi
  fi

  print_header "Updating Pi to $version"
  set_pi_package_version "$version"

  print_info "Refreshing Pi lockfile"
  (cd "${HOME_DIR}/.pi" && pnpm install --lockfile-only --ignore-scripts --config.minimumReleaseAge=0)

  print_info "Updating Pi and configured packages"
  if (cd "$DOTFILES_DIR" && pi update); then
    print_success "Pi and configured packages updated"
  else
    print_error "Failed to update Pi and configured packages"
    return 1
  fi

  local installed_version
  installed_version="$(pi --version)"
  if [[ "$installed_version" != "$version" ]]; then
    print_error "Pi version is $installed_version; expected $version"
    return 1
  fi
  print_success "Pi version verified: $installed_version"

  cmd_doctor
}

cmd_pi_extension_install() {
  local name="${1:-}"
  local version="${2:-}"
  local source

  if [[ -z "$name" || -z "$version" ]]; then
    print_error "Usage: dot pi extension install NAME VERSION"
    return 1
  fi

  require_pi_tooling || return 1

  case "$name" in
    plannotator)
      source="npm:${PLANNOTATOR_PACKAGE}@${version}"
      ensure_plannotator_share_disabled
      ;;
    *)
      print_error "Unknown managed Pi extension: $name"
      return 1
      ;;
  esac

  print_header "Installing Pi extension: $name $version"
  print_info "Installing $source"
  if (
    cd "$DOTFILES_DIR" &&
      PLANNOTATOR_SHARE=disabled \
      NPM_CONFIG_IGNORE_SCRIPTS=true \
      NPM_CONFIG_MIN_RELEASE_AGE=0 \
      pi install "$source"
  ); then
    print_success "$name installed"
  else
    print_error "Failed to install $name"
    return 1
  fi

  cmd_doctor
}

cmd_pi_extension() {
  local subcommand="${1:-help}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    install) cmd_pi_extension_install "$@" ;;
    help|-h|--help) cmd_pi_help ;;
    *) print_error "Unknown pi extension command: $subcommand"; cmd_pi_help; return 1 ;;
  esac
}

cmd_pi_skills_list() {
  node - "$PI_SKILLS_LOCK" <<'NODE'
const fs = require("fs");
const lockPath = process.argv[2];

if (!fs.existsSync(lockPath)) {
  console.log(`Missing skills lock: ${lockPath}`);
  process.exit(1);
}

const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const rows = Object.entries(lock.skills ?? {}).sort(([a], [b]) => a.localeCompare(b));

console.log(`Skills lock: ${lockPath}`);
console.log(`Skills: ${rows.length}`);
for (const [name, skill] of rows) {
  const hash = String(skill.computedHash ?? "").slice(0, 12);
  console.log(`${name}\t${skill.source ?? "unknown"}\t${skill.localPath ?? ""}\t${hash}`);
}
NODE
}

cmd_pi_skills_refresh() {
  node - "$DOTFILES_DIR" "$PI_SKILLS_DIR" "$PI_SKILLS_LOCK" "$HOME" <<'NODE'
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const root = process.argv[2];
const skillsDir = process.argv[3];
const lockPath = process.argv[4];
const home = process.argv[5] || os.homedir();
const globalLockPath = process.env.XDG_STATE_HOME
  ? path.join(process.env.XDG_STATE_HOME, "skills", ".skill-lock.json")
  : path.join(home, ".agents", ".skill-lock.json");

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

function hashSkill(dir) {
  const hash = crypto.createHash("sha256");
  const files = [];

  function walk(current) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) files.push(full);
    }
  }

  walk(dir);
  for (const file of files) {
    const rel = path.relative(dir, file).split(path.sep).join("/");
    hash.update(rel);
    hash.update("\0");
    hash.update(fs.readFileSync(file));
    hash.update("\0");
  }
  return hash.digest("hex");
}

const existing = readJson(lockPath, { skills: {} }).skills ?? {};
const global = readJson(globalLockPath, { skills: {} }).skills ?? {};
const skills = {};

if (fs.existsSync(skillsDir)) {
  for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    if (!entry.isDirectory()) continue;
    const dir = path.join(skillsDir, entry.name);
    if (!fs.existsSync(path.join(dir, "SKILL.md"))) continue;

    const localPath = path.relative(root, dir).split(path.sep).join("/");
    const prior = existing[entry.name] ?? {};
    const managed = global[entry.name] ?? {};
    const record = {
      source: prior.source ?? managed.source ?? managed.sourceUrl ?? "local",
      sourceType: prior.sourceType ?? managed.sourceType ?? "local",
      sourcePath: prior.sourcePath ?? managed.skillPath ?? localPath,
      localPath,
      computedHash: hashSkill(dir),
    };

    for (const key of ["sourceUrl", "ref", "skillPath", "skillFolderHash", "pluginName"]) {
      if (prior[key] !== undefined) record[key] = prior[key];
      else if (managed[key] !== undefined) record[key] = managed[key];
    }

    skills[entry.name] = record;
  }
}

fs.writeFileSync(lockPath, `${JSON.stringify({ version: 1, skills }, null, 2)}\n`);
console.log(`Updated ${lockPath} (${Object.keys(skills).length} skills)`);
NODE
}

cmd_pi_skills_add() {
  local source="${1:-}"
  if [[ -z "$source" ]]; then
    print_error "Usage: ${SCRIPT_NAME} pi skills add SOURCE [skills options...]"
    return 1
  fi
  shift

  if ! command_exists pnpm; then
    print_error "pnpm is required to run the skills CLI"
    return 1
  fi

  local home_pi_skills="$HOME/.pi/agent/skills"
  if [[ -e "$home_pi_skills" ]]; then
    local repo_skills real_home_skills
    repo_skills="$(realpath "$PI_SKILLS_DIR")"
    real_home_skills="$(realpath "$home_pi_skills")"
    if [[ "$repo_skills" != "$real_home_skills" ]]; then
      print_error "$home_pi_skills does not point at $PI_SKILLS_DIR"
      print_info "Run 'dot stow' before installing skills so installed files are visible in Git"
      return 1
    fi
  fi

  print_info "Running skills CLI without installing it globally"
  if pnpm dlx "$SKILLS_CLI_PACKAGE" add "$source" --global --agent pi --copy "$@"; then
    cmd_pi_skills_refresh
  else
    print_error "skills CLI failed"
    return 1
  fi
}

cmd_pi_skills_check() {
  node - "$DOTFILES_DIR" "$PI_SKILLS_DIR" "$PI_SKILLS_LOCK" <<'NODE'
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const skillsDir = process.argv[3];
const lockPath = process.argv[4];
let failed = false;

function hashSkill(dir) {
  const hash = crypto.createHash("sha256");
  const files = [];

  function walk(current) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) files.push(full);
    }
  }

  walk(dir);
  for (const file of files) {
    const rel = path.relative(dir, file).split(path.sep).join("/");
    hash.update(rel);
    hash.update("\0");
    hash.update(fs.readFileSync(file));
    hash.update("\0");
  }
  return hash.digest("hex");
}

if (!fs.existsSync(lockPath)) {
  console.error(`Missing skills lock: ${lockPath}`);
  process.exit(1);
}

const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const skills = lock.skills ?? {};
const lockedNames = new Set(Object.keys(skills));

for (const [name, skill] of Object.entries(skills).sort(([a], [b]) => a.localeCompare(b))) {
  const localPath = skill.localPath ?? `home/.pi/agent/skills/${name}`;
  const dir = path.join(root, localPath);
  if (!fs.existsSync(path.join(dir, "SKILL.md"))) {
    console.error(`missing: ${name} (${localPath})`);
    failed = true;
    continue;
  }

  const actual = hashSkill(dir);
  if (actual !== skill.computedHash) {
    console.error(`changed: ${name}`);
    console.error(`  expected ${skill.computedHash}`);
    console.error(`  actual   ${actual}`);
    failed = true;
  } else {
    console.log(`ok: ${name}`);
  }
}

if (fs.existsSync(skillsDir)) {
  for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    if (!entry.isDirectory()) continue;
    if (!fs.existsSync(path.join(skillsDir, entry.name, "SKILL.md"))) continue;
    if (!lockedNames.has(entry.name)) {
      console.error(`untracked: ${entry.name}`);
      failed = true;
    }
  }
}

process.exit(failed ? 1 : 0);
NODE
}

cmd_pi_skills_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} pi skills${RESET}

${BOLD}USAGE:${RESET}
  ${SCRIPT_NAME} pi skills list
  ${SCRIPT_NAME} pi skills check
  ${SCRIPT_NAME} pi skills refresh
  ${SCRIPT_NAME} pi skills add SOURCE [skills options...]

${BOLD}COMMANDS:${RESET}
  list    List tracked skills from the local skills lock
  check   Verify checked-in skill files match the local skills lock
  refresh Rebuild the local skills lock from checked-in skill files
  add     Install skills with 'pnpm dlx skills' so files remain visible in Git
EOF
}

cmd_pi_skills() {
  local subcommand="${1:-list}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    list) cmd_pi_skills_list "$@" ;;
    check) cmd_pi_skills_check "$@" ;;
    refresh) cmd_pi_skills_refresh "$@" ;;
    add) cmd_pi_skills_add "$@" ;;
    help|-h|--help) cmd_pi_skills_help ;;
    *) print_error "Unknown pi skills command: $subcommand"; cmd_pi_skills_help; return 1 ;;
  esac
}

cmd_pi_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} pi${RESET}

${BOLD}USAGE:${RESET}
  ${SCRIPT_NAME} pi status
  ${SCRIPT_NAME} pi update [VERSION]
  ${SCRIPT_NAME} pi skills list
  ${SCRIPT_NAME} pi skills check
  ${SCRIPT_NAME} pi skills refresh
  ${SCRIPT_NAME} pi skills add SOURCE [skills options...]
  ${SCRIPT_NAME} pi extension install plannotator VERSION

${BOLD}COMMANDS:${RESET}
  status                         Show installed, latest, and pinned Pi state
  update [VERSION]               Update tracked Pi pins, run 'pi update', verify version, and run doctor
  skills                         Inspect the checked-in Pi skills inventory
  extension install NAME VERSION Install a managed pinned Pi extension
EOF
}

cmd_pi() {
  local subcommand="${1:-status}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    status) cmd_pi_status "$@" ;;
    update) cmd_pi_update "$@" ;;
    skills) cmd_pi_skills "$@" ;;
    extension) cmd_pi_extension "$@" ;;
    help|-h|--help) cmd_pi_help ;;
    *) print_error "Unknown pi command: $subcommand"; cmd_pi_help; return 1 ;;
  esac
}
