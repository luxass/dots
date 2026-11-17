import { setTimeout as delay } from "node:timers/promises";

import { code, positive } from "./ids.mjs";
import { MAX_SMALL_JSON_BYTES, request, resultJson, SafeError } from "./transport.mjs";

/** @typedef {import("./transport.mjs").Target} Target */
/** @typedef {import("./options.mjs").Values} Values */

/**
 * Answers a person sent from a form, typed by the form's own fields.
 * @typedef {{
 *   id: string,
 *   artifactId: string,
 *   revision: number,
 *   path: string,
 *   form: string,
 *   answers: Record<string, string | number | boolean | string[]>,
 *   actor: string,
 *   createdAt: string,
 *   pickedUpAt: string | null,
 *   pickedUpBy: string | null,
 * }} Submission
 */

const STATES = new Set(["waiting", "picked-up", "all"]);

// `wait` checks every few seconds: one cheap read while a person fills in a form.
const POLL_SECONDS = 3;

const DEFAULT_WAIT_SECONDS = 600;

const MAX_WAIT_SECONDS = 3600;

/**
 * @param {Target} target
 * @param {string | undefined} artifact
 * @param {string} state
 * @param {number} page
 * @returns {Promise<{ submissions: Submission[], page: number, hasMore: boolean }>}
 */
async function list(target, artifact, state, page) {
  const params = new URLSearchParams({ state, page: String(page) });

  if (artifact !== undefined) params.set("artifact", artifact);

  return resultJson(await request(target, "/api/v1/submissions?" + params.toString()));
}

/**
 * Sent once, like every change but saves. Picking up again changes nothing.
 * @param {Target} target
 * @param {string} id
 * @returns {Promise<{ id: string, pickedUpAt: string, pickedUpBy: string }>}
 */
async function pickUp(target, id) {
  return resultJson(
    await request(target, "/api/v1/submissions/" + id, {
      method: "PATCH",
      body: JSON.stringify({ pickedUp: true }),
    }),
    MAX_SMALL_JSON_BYTES,
  );
}

/**
 * `submissions list|wait|pickup`. `wait` returns as soon as answers arrive, picks each one up,
 * and prints them in the order they were sent.
 * @param {Target} target
 * @param {string} command
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function submissions(target, command, positionals, values) {
  if (command === "submissions pickup")
    return pickUp(target, code(positionals[2], "the submission"));

  const artifact = positionals[2] === undefined ? undefined : code(positionals[2], "the artifact");

  if (command === "submissions list") {
    const state = values.state ?? "waiting";

    if (!STATES.has(state)) throw new SafeError("Use --state waiting, picked-up, or all.");

    return list(target, artifact, state, positive(values.page ?? "1", "--page"));
  }

  const seconds = positive(values.timeout ?? String(DEFAULT_WAIT_SECONDS), "--timeout");

  if (seconds > MAX_WAIT_SECONDS)
    throw new SafeError(`Wait at most ${String(MAX_WAIT_SECONDS)} seconds, then wait again.`);
  const deadline = Date.now() + seconds * 1000;

  while (true) {
    const { submissions: waiting } = await list(target, artifact, "waiting", 1);

    if (waiting.length > 0) {
      /** @type {Submission[]} */
      const picked = [];

      // The list is newest first.
      for (const submission of waiting.toReversed()) {
        const receipt = await pickUp(target, submission.id);
        picked.push({
          ...submission,
          pickedUpAt: receipt.pickedUpAt,
          pickedUpBy: receipt.pickedUpBy,
        });
      }

      return { submissions: picked, timedOut: false };
    }

    if (Date.now() + POLL_SECONDS * 1000 > deadline) return { submissions: [], timedOut: true };
    await delay(POLL_SECONDS * 1000);
  }
}
