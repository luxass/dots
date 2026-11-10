import { writeFile } from "node:fs/promises";

import { gitContext, repositoryIdentity } from "./files.mjs";
import { code, positive } from "./ids.mjs";
import { request, responseBytes, resultJson, SafeError } from "./transport.mjs";

/** @typedef {import("./transport.mjs").Target} Target */
/** @typedef {import("./options.mjs").Values} Values */

/**
 * `check`: which Wrenlo this project uses and why, how it signs in, and that the deployment
 * speaks API version 1. Reads only; writes stay unverified.
 * @param {Target} target
 */
export async function check(target) {
  const response = await request(target, "/api/v1/capabilities", {
    method: "HEAD",
    timeout: 10_000,
  });

  if (
    response.headers.get("Wrenlo-Api-Version") !== "1" ||
    response.headers.get("Content-Type")?.split(";")[0]?.trim().toLowerCase() !== "application/json"
  ) {
    let source = "";

    try {
      /** @type {{ skillSource?: string | null }} */
      const advertised = await resultJson(await request(target, "/api/v1/capabilities"), 16 * 1024);

      source = advertised.skillSource ?? "";
    } catch {
      // A deployment on another API version may not describe itself the same way.
    }

    throw new SafeError(
      "This helper speaks Wrenlo API version 1, and this deployment does not." +
        (source === ""
          ? " Ask the operator which skill version matches this deployment."
          : ` Update the skill: npx skills@1.7.4 add '${source}' --skill wrenlo`),
    );
  }

  return {
    ok: true,
    origin: target.origin.origin,
    source: target.source,
    mode: target.local ? "local" : "production",
    signIn: target.signIn,
    apiVersion: 1,
    check: target.local ? "local-reachability" : "read-access",
    writes: "unverified",
  };
}

/** @param {string | undefined} revision */
function revisionPath(revision) {
  return revision === undefined || revision === "latest"
    ? "latest"
    : String(positive(revision, "revision"));
}

/**
 * `files`: a revision's file list and main file.
 * @param {Target} target
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function files(target, positionals, values) {
  const id = code(positionals[1], "the artifact");

  /** @type {{ number: number, mainPath: string, files: unknown[] }} */
  const result = await resultJson(
    await request(
      target,
      "/api/v1/artifacts/" + id + "/revisions/" + revisionPath(values.revision),
    ),
  );

  return { id, revision: result.number, main: result.mainPath, files: result.files };
}

/**
 * `search`: full-text results with a query, otherwise the newest artifacts.
 * @param {Target} target
 * @param {Values} values
 */
export async function search(target, values) {
  const url = new URL("/api/v1/artifacts", target.origin);

  if (values.query !== undefined) url.searchParams.set("q", values.query);

  if (values.project !== undefined) url.searchParams.set("project", values.project);

  if (values.repository !== undefined)
    url.searchParams.set("repository", repositoryIdentity(values.repository));

  for (const tag of values.tag ?? []) url.searchParams.append("tag", tag);

  if (values["folder-id"] !== undefined)
    url.searchParams.set("folder", code(values["folder-id"], "the folder"));

  if (values.unfiled === true) url.searchParams.set("folder", "unfiled");

  if (values.view !== undefined) {
    if (!["active", "shared", "archived", "trash"].includes(values.view))
      throw new SafeError("Use --view active, shared, archived, or trash.");
    url.searchParams.set("view", values.view);
  }

  if (values.page !== undefined)
    url.searchParams.set("page", String(positive(values.page, "page")));

  return resultJson(await request(target, url.pathname + url.search));
}

/**
 * `read` prints one file of a revision; `download` writes it to a new file.
 * Without --file, the revision's main file.
 * @param {Target} target
 * @param {string} command
 * @param {string[]} positionals
 * @param {Values} values
 */
export async function read(target, command, positionals, values) {
  const id = code(positionals[1], "the artifact");
  const path = "/api/v1/artifacts/" + id + "/revisions/" + revisionPath(values.revision);
  const file = values.file === undefined ? "" : "?file=" + encodeURIComponent(values.file);

  if (command === "read") return resultJson(await request(target, path + file));

  if (values.output === undefined || values.output === "")
    throw new SafeError(
      "Choose a new destination with --output. Existing files are never overwritten.",
    );

  /** @type {{ file: { path: string } }} */
  const { file: selected } = await resultJson(await request(target, path + file));
  const response = await request(target, path + "/files/" + encodeURI(selected.path));

  if (response.headers.get("Content-Disposition")?.startsWith("attachment") !== true)
    throw new SafeError("The server did not return an artifact file.");
  const bytes = await responseBytes(response, 1024 * 1024);

  try {
    await writeFile(values.output, bytes, { flag: "wx" });
  } catch {
    throw new SafeError("The download could not be written. Choose a new writable file path.");
  }

  return { id, file: selected.path, output: values.output, bytes: bytes.byteLength };
}

/**
 * `resume`: the newest active artifact of this repository, or of this project outside Git,
 * with its main file's content. `--list` prints the newest ten without content.
 * @param {Target} target
 * @param {Values} values
 */
export async function resume(target, values) {
  const context = await gitContext();

  const repository =
    values.repository === undefined ? context.repository : repositoryIdentity(values.repository);

  const listing = new URL("/api/v1/artifacts", target.origin);

  if (repository === undefined) listing.searchParams.set("project", context.project);
  else listing.searchParams.set("repository", repository);

  /** @type {{ items: { id: string, title: string, format: string, currentRevision: number, updatedAt: string }[] }} */
  const { items } = await resultJson(await request(target, listing.pathname + listing.search));

  const matches = items.slice(0, 10).map((artifact) => ({
    id: artifact.id,
    title: artifact.title,
    format: artifact.format,
    revision: artifact.currentRevision,
    updatedAt: artifact.updatedAt,
    url: new URL("/a/" + artifact.id, target.origin).href,
  }));

  if (values.list === true) return { artifacts: matches };
  const latest = matches[0];

  if (latest === undefined)
    throw new SafeError(
      "No active artifact was found for " + (repository ?? "project " + context.project) + ".",
    );

  /** @type {{ files: unknown[], file: { path: string, content: string } }} */
  const { files: list, file } = await resultJson(
    await request(target, "/api/v1/artifacts/" + latest.id + "/revisions/latest"),
  );

  // The main file's content; `files` lists the others for `read --file`.
  return { ...latest, files: list, main: file.path, content: file.content };
}
