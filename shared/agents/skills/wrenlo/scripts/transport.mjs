import { Buffer } from "node:buffer";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";

/** The helper's own path, printed in messages so an agent can run the next command as is. */
export const HELPER = fileURLToPath(new URL("wrenlo.mjs", import.meta.url));

export class SafeError extends Error {
  /** @param {string} message @param {boolean} [retryable] */
  constructor(message, retryable = false) {
    super(message);
    this.retryable = retryable;
  }
}

/**
 * Where requests go and how they authenticate. `refresh` renews a browser sign-in; it is absent
 * for local instances and service tokens.
 * @typedef {{
 *   origin: URL,
 *   local: boolean,
 *   source: string,
 *   signIn: "local" | "service token" | "signed in",
 *   headers: () => Promise<Record<string, string>>,
 *   refresh?: () => Promise<void>,
 * }} Target
 */

/**
 * @param {Target} target
 * @param {string} path
 * @param {{method?: string, body?: string, timeout?: number}} [options]
 */
export async function request(target, path, { method = "GET", body, timeout = 20_000 } = {}) {
  const send = async () => {
    /** @type {RequestInit} */
    const init = {
      method,
      headers: { "Content-Type": "application/json", ...(await target.headers()) },
      redirect: "manual",
      signal: AbortSignal.timeout(timeout),
    };

    if (body !== undefined) init.body = body;

    try {
      return await fetch(new URL(path, target.origin), init);
    } catch {
      throw new SafeError(
        "The request could not be confirmed. Read current state before repeating a mutation without a retry ID.",
        true,
      );
    }
  };

  let response = await send();

  // An access token can expire between the expiry check and the request: renew once and resend.
  if (response.status === 401 && target.refresh !== undefined) {
    await response.body?.cancel();
    await target.refresh();
    response = await send();
  }

  if (response.status >= 300 && response.status < 400) {
    await response.body?.cancel();
    throw new SafeError(
      `Access redirected this request to its sign-in page, so it was not admitted. Run: node "${HELPER}" login ${target.origin.origin}, or check the Service Auth policy for the service token.`,
    );
  }

  if (!response.ok) {
    const reason = await errorMessage(response);
    throw new SafeError(
      (reason ?? "Check admission, input, resource state, and server availability.") +
        " (HTTP " +
        response.status +
        ")",
      [408, 429, 500, 502, 503, 504].includes(response.status),
    );
  }

  return response;
}

/**
 * Reads Wrenlo's {"error": "..."} message, so an agent can fix its request.
 * Server messages never contain credentials or artifact content.
 * @param {Response} response
 */
async function errorMessage(response) {
  try {
    /** @type {{error?: string}} */
    const body = await resultJson(response, 16 * 1024);

    return body.error;
  } catch {
    return undefined;
  }
}

/** @param {Response} response @param {number} limit */
export async function responseBytes(response, limit) {
  if (!response.body) throw new SafeError("The response has no body.", true);
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;

  try {
    while (true) {
      /** @type {ReadableStreamReadResult<Uint8Array>} */
      const chunk = await reader.read();

      if (chunk.done) break;
      length += chunk.value.byteLength;

      if (length > limit) {
        await reader.cancel();
        throw new SafeError("The response exceeded its size limit.");
      }

      chunks.push(chunk.value);
    }

    return Buffer.concat(chunks);
  } finally {
    reader.releaseLock();
  }
}

/**
 * Parses a JSON response from Wrenlo's own versioned API. Callers declare the shape.
 * @template [T=unknown]
 * @param {Response} response
 * @param {number} [limit]
 * @returns {Promise<T>}
 */
export async function resultJson(response, limit = 8 * 1024 * 1024) {
  if (
    response.headers.get("Content-Type")?.split(";")[0]?.trim().toLowerCase() !== "application/json"
  ) {
    await response.body?.cancel();
    throw new SafeError("The server did not return Wrenlo JSON.");
  }

  const bytes = await responseBytes(response, limit);

  try {
    // SAFETY: Wrenlo's own versioned API; each caller declares the response fields it reads.
    return /** @type {T} */ (JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)));
  } catch {
    throw new SafeError("The JSON response could not be read.", true);
  }
}

/**
 * @param {Target} target
 * @param {{id: string, saveId: string, path: string, method: string, body: string}} input
 */
export async function confirmRevision(target, { id, saveId, path, method, body }) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await request(target, path, { method, body });
      /** @type {{id: string, saveId: string, revision: number, created: boolean, format: string, title: string, url: string}} */
      const receipt = await resultJson(response, 16 * 1024);

      // Matching IDs prove this receipt belongs to this exact request, so a retry is safe.
      if (receipt.id !== id || receipt.saveId !== saveId)
        throw new SafeError("The server returned a receipt for a different save.");

      return receipt;
    } catch (error) {
      if (error instanceof SafeError && !error.retryable) throw error;

      if (attempt === 2)
        throw new SafeError(
          `The revision could not be confirmed after three attempts. Retry IDs: artifact ${id} --save-id ${saveId}. Use --id for save, or the positional artifact ID for restore-revision. Keep the same destination, original file or source revision, and exact metadata. Do not change text under a retry ID.`,
          true,
        );
    }

    await delay(500 * 2 ** attempt);
  }

  throw new SafeError("The revision could not be confirmed.");
}
