import { randomInt } from "node:crypto";

import { SafeError } from "./transport.mjs";

// Save retry keys stay UUIDs. Folders, artifacts, and notes use 6-character codes.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u;

const CODE = /^[2-9a-hjkmnp-z]{6}$/u;

const CODE_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz";

// Must match the server's message for a new item whose random code is already in use.
const CODE_TAKEN = "That code is already used.";

/** @param {string | undefined} value @param {string} label */
export function uuid(value, label) {
  if (value === undefined || !UUID.test(value))
    throw new SafeError("Use a lowercase UUID v4 for " + label + ".");

  return value;
}

/** @param {string | undefined} value @param {string} label */
export function code(value, label) {
  if (value === undefined || !CODE.test(value))
    throw new SafeError("Use the 6-character code for " + label + ", such as k7m2qx.");

  return value;
}

/** @param {string | undefined} value @param {string} label */
export function positive(value, label) {
  const number = Number(value);

  if (value === undefined || !/^\d+$/u.test(value) || !Number.isSafeInteger(number) || number < 1)
    throw new SafeError("Use a positive integer for " + label + ".");

  return number;
}

/**
 * Creates something under a fresh random code. If the code already belongs to another item,
 * which is about 1 in 900 million, it picks a new code and sends again.
 * @template T
 * @param {(id: string) => Promise<T>} send
 * @returns {Promise<T>}
 */
export async function withFreshCode(send) {
  for (let attempt = 0; ; attempt++) {
    const fresh = Array.from({ length: 6 }, () =>
      CODE_ALPHABET.charAt(randomInt(CODE_ALPHABET.length)),
    ).join("");

    try {
      return await send(fresh);
    } catch (error) {
      if (attempt >= 2 || !(error instanceof SafeError) || !error.message.startsWith(CODE_TAKEN))
        throw error;
    }
  }
}
