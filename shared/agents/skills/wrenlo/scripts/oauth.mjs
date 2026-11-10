import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { once } from "node:events";
import { createServer } from "node:http";

import { tokenFile, writePrivate } from "./settings.mjs";
import { HELPER, resultJson, SafeError } from "./transport.mjs";

/** @param {URL} origin */
export function signInMessage(origin) {
  return `Sign-in to ${origin.origin} is missing or expired. Tell the user a browser window will open, then run: node "${HELPER}" login ${origin.origin}`;
}

const NO_BROWSER_SIGN_IN =
  " does not offer browser sign-in. Ask the operator to turn on Managed OAuth for its Access application, or set a service token in WRENLO_ACCESS_CLIENT_ID and WRENLO_ACCESS_CLIENT_SECRET.";

/**
 * One request to Access's OAuth endpoints. Redirects and errors mean sign-in is not possible.
 * Callers declare the fields they read; a wrong value fails the next step, never silently.
 * @template [T=Record<string, string | undefined>]
 * @param {string | URL} url
 * @param {string} failure
 * @param {URLSearchParams | object} [body] a form, or JSON for client registration
 * @returns {Promise<T>}
 */
async function oauth(url, failure, body) {
  /** @type {RequestInit} */
  const init = { redirect: "manual", signal: AbortSignal.timeout(20_000) };

  if (body !== undefined) {
    const form = body instanceof URLSearchParams;

    init.method = "POST";
    init.headers = {
      "Content-Type": form ? "application/x-www-form-urlencoded" : "application/json",
      Accept: "application/json",
    };
    init.body = form ? body.toString() : JSON.stringify(body);
  }

  let response;

  try {
    response = await fetch(url, init);
  } catch {
    throw new SafeError(failure + " The sign-in service could not be reached.", true);
  }

  if (!response.ok) {
    await response.body?.cancel();
    throw new SafeError(failure);
  }

  try {
    return await resultJson(response, 64 * 1024);
  } catch {
    throw new SafeError(failure);
  }
}

/** @param {unknown} value @param {string} failure */
function httpsEndpoint(value, failure) {
  try {
    const url = new URL(String(value));

    if (url.protocol === "https:" && !url.username && !url.password) return url;
  } catch {
    // Reported below.
  }

  throw new SafeError(failure);
}

/** @param {string} url */
function openBrowser(url) {
  const [command, args] =
    process.platform === "darwin"
      ? ["open", [url]]
      : process.platform === "win32"
        ? ["rundll32", ["url.dll,FileProtocolHandler", url]]
        : ["xdg-open", [url]];

  try {
    const child = spawn(command, args, { detached: true, stdio: "ignore" });

    child.on("error", () => {});
    child.unref();
  } catch {
    // The printed URL still works.
  }
}

/**
 * Waits for Access to send the browser back with an authorization code.
 * @param {import("node:http").Server} server
 * @param {string} state
 * @returns {Promise<string>}
 */
function callback(server, state) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new SafeError("No sign-in arrived within 5 minutes. Run login again."));
    }, 5 * 60_000);

    server.on("request", (request, response) => {
      const url = new URL(request.url ?? "/", "http://127.0.0.1");

      if (url.pathname !== "/callback") {
        response.writeHead(404).end();

        return;
      }

      const code = url.searchParams.get("code");
      const ok = code !== null && url.searchParams.get("state") === state;

      response
        .writeHead(ok ? 200 : 400, { "Content-Type": "text/plain; charset=utf-8" })
        .end(
          ok
            ? "Signed in to Wrenlo. You can close this tab."
            : "Sign-in failed. Return to your agent and run login again.",
        );
      clearTimeout(timer);

      if (ok) resolve(code);
      else reject(new SafeError("Sign-in was refused or interrupted. Run login again."));
    });
  });
}

/**
 * Browser sign-in through Access Managed OAuth: discovery, client registration, the
 * authorization code flow with PKCE on a one-time loopback listener, then saved tokens.
 * @param {URL} origin
 */
export async function signIn(origin) {
  const failure = origin.origin + NO_BROWSER_SIGN_IN;
  const metadata = await oauth(new URL("/.well-known/oauth-authorization-server", origin), failure);
  const authorize = httpsEndpoint(metadata.authorization_endpoint, failure);
  const tokenEndpoint = httpsEndpoint(metadata.token_endpoint, failure);
  const register = httpsEndpoint(metadata.registration_endpoint, failure);

  // RFC 8707: tokens are bound to this application. Access names it in its resource metadata.
  let resource = origin.origin;

  try {
    const described = await oauth(new URL("/.well-known/oauth-protected-resource", origin), "");

    const named = described.resource;

    // Sent exactly as Access names it; it may compare the string as is.
    if (named !== undefined && new URL(named).origin === origin.origin) resource = named;
  } catch {
    // Without resource metadata, the application's own address names it.
  }

  const server = createServer();

  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  try {
    // SAFETY: a TCP listener on 127.0.0.1 always reports an address object.
    const { port } = /** @type {import("node:net").AddressInfo} */ (server.address());
    const redirect = `http://127.0.0.1:${String(port)}/callback`;

    const client = await oauth(register, failure, {
      client_name: "Wrenlo agent helper",
      redirect_uris: [redirect],
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
    });

    const clientId = client.client_id ?? "";

    if (clientId === "") throw new SafeError(failure);

    const verifier = randomBytes(32).toString("base64url");
    const state = randomBytes(16).toString("base64url");

    authorize.search = new URLSearchParams({
      response_type: "code",
      client_id: clientId,
      redirect_uri: redirect,
      code_challenge: createHash("sha256").update(verifier).digest("base64url"),
      code_challenge_method: "S256",
      state,
      resource,
    }).toString();

    const arrived = callback(server, state);

    console.error(
      `Opening the browser to sign in to ${origin.origin}. If it does not open, visit:\n${authorize.href}`,
    );
    openBrowser(authorize.href);

    const code = await arrived;

    await saveTokens(
      origin,
      { clientId, tokenEndpoint: tokenEndpoint.href, resource },
      await oauth(
        tokenEndpoint,
        "The sign-in could not be completed. Run login again.",
        new URLSearchParams({
          grant_type: "authorization_code",
          code,
          redirect_uri: redirect,
          client_id: clientId,
          code_verifier: verifier,
          resource,
        }),
      ),
    );
  } finally {
    server.close();
  }
}

/**
 * Saves a token response next to the client it belongs to. A refresh may omit the refresh token,
 * which keeps the previous one.
 * @param {URL} origin
 * @param {{ clientId: string, tokenEndpoint: string, resource: string, refreshToken?: string }} client
 * @param {{ access_token?: string, refresh_token?: string, expires_in?: number }} response
 */
async function saveTokens(origin, client, response) {
  const accessToken = response.access_token ?? "";
  const seconds = Number(response.expires_in);

  if (accessToken === "")
    throw new SafeError("The sign-in service returned no access token. Run login again.");

  const tokens = {
    clientId: client.clientId,
    tokenEndpoint: client.tokenEndpoint,
    resource: client.resource,
    accessToken,
    refreshToken: response.refresh_token ?? client.refreshToken,
    // Without a lifetime, renew after 15 minutes, Access's default.
    expiresAt: Date.now() + (Number.isFinite(seconds) && seconds > 0 ? seconds : 900) * 1000,
  };

  await writePrivate(tokenFile(origin), tokens);

  return tokens;
}

/**
 * Renews an expired or rejected access token with the saved refresh token.
 * @param {URL} origin
 * @param {Exclude<Awaited<ReturnType<typeof import("./settings.mjs").readTokens>>, null>} tokens
 */
export async function renew(origin, tokens) {
  if (tokens.refreshToken === undefined) throw new SafeError(signInMessage(origin));

  return saveTokens(
    origin,
    tokens,
    await oauth(
      tokens.tokenEndpoint,
      signInMessage(origin),
      new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: tokens.refreshToken,
        client_id: tokens.clientId,
        resource: tokens.resource,
      }),
    ),
  );
}
