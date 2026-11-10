import { rm } from "node:fs/promises";

import { projectRoot } from "./files.mjs";
import { renew, signIn, signInMessage } from "./oauth.mjs";
import {
  parseOrigin,
  readSettings,
  readTokens,
  resolveDestination,
  tokenFile,
  writeSettings,
} from "./settings.mjs";
import { SafeError } from "./transport.mjs";

/** Both service token variables, or null. A service token wins over a browser sign-in. */
function serviceToken() {
  const id = process.env.WRENLO_ACCESS_CLIENT_ID?.trim();
  const secret = process.env.WRENLO_ACCESS_CLIENT_SECRET?.trim();

  return id !== undefined && id !== "" && secret !== undefined && secret !== ""
    ? { "CF-Access-Client-Id": id, "CF-Access-Client-Secret": secret }
    : null;
}

/**
 * The destination for this command and how its requests authenticate.
 * @param {string | undefined} option the --origin value
 * @returns {Promise<import("./transport.mjs").Target>}
 */
export async function connect(option) {
  const { origin, local, source } = await resolveDestination(option);
  const base = { origin, local, source };

  if (local) return { ...base, signIn: "local", headers: () => Promise.resolve({}) };

  const service = serviceToken();

  if (service !== null)
    return { ...base, signIn: "service token", headers: () => Promise.resolve(service) };

  let tokens = await readTokens(origin);

  if (tokens === null) throw new SafeError(signInMessage(origin));

  /** @type {Promise<void> | null} */
  let renewing = null;

  // One renewal at a time, so parallel requests share it and a rotated refresh token is used once.
  const refresh = () =>
    (renewing ??= (async () => {
      const current = tokens;

      if (current === null) throw new SafeError(signInMessage(origin));

      tokens = await renew(origin, current);
    })().finally(() => {
      renewing = null;
    }));

  return {
    ...base,
    signIn: "signed in",
    headers: async () => {
      if (tokens !== null && tokens.expiresAt - 30_000 < Date.now()) await refresh();

      return { Authorization: "Bearer " + tokens?.accessToken };
    },
    refresh,
  };
}

/**
 * `login <address>`: signs in (not needed for a local instance) and saves the address. A new
 * instance that is not the only one becomes this project's choice, since the user picked it here.
 * @param {string | undefined} address
 */
export async function login(address) {
  const { origin, local } = parseOrigin(address);

  if (!local) await signIn(origin);

  const settings = await readSettings();
  const project = await projectRoot();
  const added = !settings.instances.includes(origin.origin);

  if (added) settings.instances.push(origin.origin);

  if (added && settings.instances.length > 1 && settings.projects[project] === undefined)
    settings.projects[project] = origin.origin;

  await writeSettings(settings);

  const usedBy =
    settings.instances.length === 1
      ? "every project"
      : settings.projects[project] === origin.origin
        ? "this project (" + project + ")"
        : settings.default === origin.origin
          ? "projects without their own choice"
          : null;

  return {
    ok: true,
    origin: origin.origin,
    signIn: local ? "local" : "signed in",
    message:
      (local ? "Saved " : "Signed in to ") +
      origin.origin +
      ". " +
      (usedBy === null
        ? "Projects use it after: use " + origin.origin
        : "It is now used by " + usedBy + "."),
  };
}

/**
 * `logout <address>`: deletes its sign-in. With `--forget`, also forgets the instance everywhere.
 * @param {string | undefined} address
 * @param {boolean} forget
 */
export async function logout(address, forget) {
  const { origin } = parseOrigin(address);

  await rm(tokenFile(origin), { force: true });

  if (forget) {
    const settings = await readSettings();

    settings.instances = settings.instances.filter((item) => item !== origin.origin);

    if (settings.default === origin.origin) delete settings.default;

    for (const [project, chosen] of Object.entries(settings.projects))
      if (chosen === origin.origin) delete settings.projects[project];

    await writeSettings(settings);
  }

  return { ok: true, origin: origin.origin, signedOut: true, forgotten: forget };
}
