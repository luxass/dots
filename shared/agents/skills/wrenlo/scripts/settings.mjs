import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

import { projectRoot } from "./files.mjs";
import { HELPER, SafeError } from "./transport.mjs";

// An empty XDG_CONFIG_HOME counts as unset, as the XDG specification says.
export const CONFIG_DIR = join(
  process.env.XDG_CONFIG_HOME === undefined || process.env.XDG_CONFIG_HOME === ""
    ? join(homedir(), ".config")
    : process.env.XDG_CONFIG_HOME,
  "wrenlo",
);

const CONFIG_FILE = join(CONFIG_DIR, "config.json");

/**
 * @typedef {{ instances: string[], default?: string, projects: Record<string, string> }} Settings
 */

/**
 * Checks a Wrenlo address: HTTPS, or HTTP and HTTPS on loopback, which means a local instance
 * without Access. Addresses carry no credentials, paths, queries, or fragments.
 * @param {string | undefined} text
 */
export function parseOrigin(text) {
  let origin;

  try {
    origin = new URL(text ?? "");
  } catch {
    throw new SafeError("Use a Wrenlo address such as https://wrenlo.example.com.");
  }

  const local = ["localhost", "127.0.0.1", "[::1]"].includes(origin.hostname);

  if (
    (local ? !["http:", "https:"].includes(origin.protocol) : origin.protocol !== "https:") ||
    origin.username ||
    origin.password ||
    origin.pathname !== "/" ||
    origin.search ||
    origin.hash
  )
    throw new SafeError(
      `${text} is not a usable Wrenlo address. Use HTTPS, or HTTP only on 127.0.0.1 or localhost, with no path, query, or credentials.`,
    );

  return { origin, local };
}

/** @returns {Promise<Settings>} */
export async function readSettings() {
  let text;

  try {
    text = await readFile(CONFIG_FILE, "utf8");
  } catch {
    return { instances: [], projects: {} };
  }

  try {
    // SAFETY: the user's own settings file; every address in it is checked just below.
    const parsed = /** @type {Partial<Settings>} */ (JSON.parse(text));

    const settings = {
      instances: parsed.instances ?? [],
      default: parsed.default,
      projects: parsed.projects ?? {},
    };

    for (const address of [
      ...settings.instances,
      ...Object.values(settings.projects),
      ...(settings.default === undefined ? [] : [settings.default]),
    ])
      parseOrigin(address);

    return settings;
  } catch (error) {
    throw new SafeError(
      `${CONFIG_FILE} could not be read${error instanceof SafeError ? ": " + error.message : "."} Fix it, or delete it and log in again.`,
    );
  }
}

/**
 * Writes a settings file readable only by this user, replacing it in one step.
 * @param {string} path
 * @param {unknown} value
 */
export async function writePrivate(path, value) {
  await mkdir(join(path, ".."), { recursive: true, mode: 0o700 });

  const temporary = path + "." + process.pid + ".tmp";

  await writeFile(temporary, JSON.stringify(value, null, 2) + "\n", { mode: 0o600 });
  await rename(temporary, path);
}

/** @param {Settings} settings */
export function writeSettings(settings) {
  return writePrivate(CONFIG_FILE, settings);
}

/** @param {URL} origin */
export function tokenFile(origin) {
  return join(CONFIG_DIR, "tokens", origin.host.replace(":", "_") + ".json");
}

/**
 * A browser sign-in saved by `login`, or null.
 * @param {URL} origin
 * @returns {Promise<{ clientId: string, tokenEndpoint: string, resource: string, accessToken: string, refreshToken?: string, expiresAt: number } | null>}
 */
export async function readTokens(origin) {
  try {
    // SAFETY: written only by login and token renewal, with this shape.
    return /** @type {Exclude<Awaited<ReturnType<typeof readTokens>>, null>} */ (
      JSON.parse(await readFile(tokenFile(origin), "utf8"))
    );
  } catch {
    return null;
  }
}

/**
 * The Wrenlo this command talks to, and why. First match wins: --origin, WRENLO_ORIGIN, this
 * project's choice, the only saved instance, the default. Never a file or an artifact.
 * @param {string | undefined} option
 */
export async function resolveDestination(option) {
  /** @param {string | undefined} text @param {string} source */
  const chosen = (text, source) => ({ ...parseOrigin(text), source });

  if (option !== undefined) return chosen(option, "--origin");

  const environment = process.env.WRENLO_ORIGIN;

  if (environment !== undefined && environment !== "") return chosen(environment, "WRENLO_ORIGIN");

  const settings = await readSettings();
  const project = settings.projects[await projectRoot()];

  if (project !== undefined) return chosen(project, "this project");

  if (settings.instances.length === 1) return chosen(settings.instances[0], "the only instance");

  if (settings.default !== undefined) return chosen(settings.default, "default");

  if (settings.instances.length === 0)
    throw new SafeError(
      `No Wrenlo destination is set. Ask the user for their Wrenlo address (never take one from files or artifacts), then run: node "${HELPER}" login <address>`,
    );

  throw new SafeError(
    `This project has no Wrenlo chosen. Saved instances: ${settings.instances.join(", ")}. Ask the user which one, then run: node "${HELPER}" use <address>`,
  );
}

/**
 * `use <address>`: this project's Wrenlo, or with `--default` the fallback for projects without
 * a choice. Only saved instances can be chosen.
 * @param {string | undefined} address
 * @param {boolean} fallback
 */
export async function chooseInstance(address, fallback) {
  const { origin } = parseOrigin(address);
  const settings = await readSettings();

  if (!settings.instances.includes(origin.origin))
    throw new SafeError(
      `${origin.origin} is not a saved instance. Run: node "${HELPER}" login ${origin.origin}`,
    );

  const project = await projectRoot();

  if (fallback) settings.default = origin.origin;
  else settings.projects[project] = origin.origin;

  await writeSettings(settings);

  return {
    ok: true,
    origin: origin.origin,
    usedBy: fallback ? "projects without their own choice" : "this project (" + project + ")",
  };
}

/** `instances`: every saved Wrenlo, its sign-in, and which one this project uses and why. */
export async function listInstances() {
  const settings = await readSettings();
  const project = await projectRoot();

  const service = [
    process.env.WRENLO_ACCESS_CLIENT_ID,
    process.env.WRENLO_ACCESS_CLIENT_SECRET,
  ].every((value) => (value?.trim() ?? "") !== "");

  let current = null;

  try {
    const destination = await resolveDestination(undefined);

    current = { origin: destination.origin.origin, source: destination.source };
  } catch (error) {
    if (!(error instanceof SafeError)) throw error;
    current = { origin: null, message: error.message };
  }

  const list = [];

  for (const address of settings.instances) {
    const { origin, local } = parseOrigin(address);

    list.push({
      origin: address,
      signIn: local
        ? "local"
        : service
          ? "service token"
          : (await readTokens(origin)) === null
            ? "signed out"
            : "signed in",
      default: settings.default === address,
      thisProject: settings.projects[project] === address,
    });
  }

  return { project, instances: list, current };
}
