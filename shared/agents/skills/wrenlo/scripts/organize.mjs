import { metadata } from "./files.mjs";
import { code, positive, withFreshCode } from "./ids.mjs";
import { request, resultJson, SafeError } from "./transport.mjs";

/** @typedef {import("./transport.mjs").Target} Target */
/** @typedef {import("./options.mjs").Values} Values */

/**
 * Sends one JSON change. Changes other than saves are never retried automatically: after an
 * uncertain failure, read the current state before sending again.
 * @param {Target} target
 * @param {string} path
 * @param {string} method
 * @param {Record<string, unknown>} body
 * @returns {Promise<unknown>}
 */
async function send(target, path, method, body) {
  return resultJson(await request(target, path, { method, body: JSON.stringify(body) }), 16 * 1024);
}

const LIFECYCLE = new Map([
  ["archive", { archived: true }],
  ["unarchive", { archived: false }],
  ["trash", { trashed: true }],
  ["untrash", { trashed: false }],
  ["share", { shared: true }],
  ["unshare", { shared: false }],
]);

/**
 * `metadata` without changes prints the artifact; with changes it updates them. Archive,
 * trash, and share commands change one flag.
 * @param {Target} target
 * @param {string} command
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function artifactDetails(target, command, positionals, values) {
  const id = code(positionals[1], "the artifact");
  const path = "/api/v1/artifacts/" + id;
  const flag = LIFECYCLE.get(command);

  if (flag !== undefined) return send(target, path, "PATCH", flag);

  const { folder: _folder, ...details } = await metadata({ ...values, id });
  /** @type {Record<string, unknown>} */
  const body = details;

  if (values["folder-id"] !== undefined) body.folderId = code(values["folder-id"], "the folder");

  if (values.unfiled === true) body.folderId = null;

  if (Object.keys(body).length === 0) return resultJson(await request(target, path));

  return send(target, path, "PATCH", body);
}

/**
 * `folder list|create|rename|move|remove`.
 * @param {Target} target
 * @param {string} command
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function folder(target, command, positionals, values) {
  if (command === "folder list") return resultJson(await request(target, "/api/v1/folders"));

  /** @type {Record<string, unknown>} */
  const body = {};

  if (command === "folder create" || command === "folder rename") {
    if (values.name === undefined || values.name === "")
      throw new SafeError("Supply --name for folder creation or rename.");
    body.name = values.name;
  }

  if (command === "folder move" && values["parent-id"] === undefined)
    throw new SafeError("Supply --parent-id with a folder code or root.");

  if (command === "folder create" || command === "folder move")
    body.parentId =
      values["parent-id"] === undefined || values["parent-id"] === "root"
        ? null
        : code(values["parent-id"], "the parent folder");

  if (command === "folder create")
    return withFreshCode((fresh) =>
      send(target, "/api/v1/folders", "POST", { ...body, id: fresh }),
    );

  const path = "/api/v1/folders/" + code(positionals[2], "the folder");

  return send(target, path, command === "folder remove" ? "DELETE" : "PATCH", body);
}

/**
 * `notes list|add|reply|resolve|reopen`.
 * @param {Target} target
 * @param {string} command
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function notes(target, command, positionals, values) {
  const id = positionals[2];

  if (command === "notes list") {
    const state = values.state ?? "open";

    if (!["open", "resolved", "all"].includes(state))
      throw new SafeError("Use --state open, resolved, or all.");

    /** @type {{ notes: Array<{ resolvedAt: string | null }> }} */
    const result = await resultJson(
      await request(target, "/api/v1/artifacts/" + code(id, "the artifact") + "/notes"),
    );

    return {
      notes: result.notes.filter(
        (note) => state === "all" || (note.resolvedAt === null) === (state === "open"),
      ),
    };
  }

  if (command === "notes add" || command === "notes reply") {
    if (values.body === undefined || values.body === "")
      throw new SafeError("Supply --body with the note text.");

    const path =
      command === "notes add"
        ? "/api/v1/artifacts/" + code(id, "the artifact") + "/notes"
        : "/api/v1/notes/" + code(id, "the note") + "/replies";

    /** @type {Record<string, unknown>} */
    const body = { body: values.body };

    if (command === "notes add") {
      if (values.quote !== undefined) body.quote = values.quote;

      if (values.file !== undefined) body.path = values.file;

      if (values.revision !== undefined) body.revision = positive(values.revision, "revision");
    }

    return withFreshCode((fresh) => send(target, path, "POST", { ...body, id: fresh }));
  }

  const noteId = code(id, "the note");
  const reply = values.reply;

  if (command === "notes resolve" && reply !== undefined)
    await withFreshCode((fresh) =>
      send(target, "/api/v1/notes/" + noteId + "/replies", "POST", { id: fresh, body: reply }),
    );

  return send(target, "/api/v1/notes/" + noteId, "PATCH", {
    resolved: command === "notes resolve",
  });
}
