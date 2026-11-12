import { randomUUID } from "node:crypto";
import { stat } from "node:fs/promises";
import { basename, join, relative, resolve, sep } from "node:path";

import { directoryFiles, formatFromPath, metadata, readFile, requireSupported } from "./files.mjs";
import { code, positive, uuid, withFreshCode } from "./ids.mjs";
import { confirmRevision, request, resultJson, SafeError } from "./transport.mjs";

/** @typedef {import("./transport.mjs").Target} Target */
/** @typedef {import("./options.mjs").Values} Values */
/** @typedef {{ mode: "replace" | "merge", files: { path: string, content: string }[], remove: string[] }} Change */

/**
 * A file's path relative to the current directory, with forward slashes.
 * @param {string} input
 */
function relativePath(input) {
  const path = relative(process.cwd(), resolve(input)).split(sep).join("/");

  if (path.startsWith("../") || path === "..")
    throw new SafeError(
      input + " is outside the current directory. Run the helper from the artifact's folder.",
    );

  return path;
}

/**
 * The existing artifact a single file is saved into, or null when its code is still unused,
 * as when a new artifact's save is retried with --id.
 * @param {Target} target
 * @param {string} id
 * @returns {Promise<{ fileCount: number, mainPath: string } | null>}
 */
async function existing(target, id) {
  try {
    return await resultJson(await request(target, "/api/v1/artifacts/" + id));
  } catch (error) {
    if (error instanceof SafeError && error.message.endsWith("(HTTP 404)")) return null;
    throw error;
  }
}

/**
 * The files of one save, by three rules:
 * 1. A directory replaces the artifact's whole file set, with paths relative to it.
 * 2. Files are merged in by path relative to the current directory; `--as` sets one file's path.
 *    One file saved into a multi-file artifact is merged the same way.
 * 3. Otherwise one file is the whole artifact: a new one is stored under its name, and a
 *    one-file artifact has its file replaced, keeping the stored name when the format matches.
 * @param {Target} target
 * @param {string[]} inputs
 * @param {Values} values
 * @returns {Promise<Change>}
 */
async function collectFiles(target, inputs, values) {
  const first = inputs[0] ?? "";
  const single = inputs.length === 1;

  if (values.as !== undefined && !single)
    throw new SafeError("Save option --as works with one file. Pass one file, or drop --as.");

  if (single && values.as === undefined && (await isDirectory(first))) {
    const files = [];

    for (const path of await directoryFiles(first))
      files.push({ path, content: (await readFile(join(first, path))).content });

    return { mode: "replace", files, remove: [] };
  }

  for (const input of inputs) requireSupported(input);

  if (values.as !== undefined) requireSupported(values.as);

  const current =
    single && values.as === undefined && values.id !== undefined
      ? await existing(target, code(values.id, "the artifact"))
      : null;

  if (!single || values.as !== undefined || (current !== null && current.fileCount > 1)) {
    const files = [];

    for (const input of inputs)
      files.push({
        path: values.as ?? relativePath(input),
        content: (await readFile(input)).content,
      });

    return { mode: "merge", files, remove: [] };
  }

  const path =
    current !== null && formatFromPath(current.mainPath) === formatFromPath(first)
      ? current.mainPath
      : basename(first);

  return {
    mode: "replace",
    files: [{ path, content: (await readFile(first)).content }],
    remove: [],
  };
}

/** @param {string} path */
async function isDirectory(path) {
  try {
    return (await stat(path)).isDirectory();
  } catch {
    throw new SafeError(path + " could not be found.");
  }
}

/**
 * `save` and `rm`: one new revision, retried safely with the same save ID.
 * @param {Target} target
 * @param {string} command
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function save(target, command, positionals, values) {
  const saveId = uuid(values["save-id"] ?? randomUUID(), "save ID");

  /** @type {Change} */
  const change =
    command === "rm"
      ? { mode: "merge", files: [], remove: positionals.slice(2) }
      : await collectFiles(target, positionals.slice(1), values);

  const details = command === "rm" ? {} : await metadata(values);

  /** @param {string} id @param {boolean} create */
  const send = (id, create) => {
    /** @type {Record<string, unknown>} */
    const body = { ...details, ...change, saveId };

    // A new artifact says so, so its random code can never land in an existing artifact.
    if (create) body.create = true;

    return confirmRevision(target, {
      id,
      saveId,
      path: "/api/v1/artifacts/" + id,
      method: "PUT",
      body: JSON.stringify(body),
    });
  };

  const id = command === "rm" ? positionals[1] : values.id;

  return id === undefined
    ? withFreshCode((fresh) => send(fresh, true))
    : send(code(id, "the artifact"), false);
}

/**
 * `restore-revision`: appends a revision with an earlier revision's files.
 * @param {Target} target
 * @param {string[]} positionals
 * @param {Values} values
 */
export function restore(target, positionals, values) {
  const id = code(positionals[1], "the artifact");
  const sourceRevision = positive(values.revision, "revision");
  const saveId = uuid(values["save-id"] ?? randomUUID(), "save ID");

  return confirmRevision(target, {
    id,
    saveId,
    path: "/api/v1/artifacts/" + id + "/restores",
    method: "POST",
    body: JSON.stringify({ sourceRevision, saveId }),
  });
}
