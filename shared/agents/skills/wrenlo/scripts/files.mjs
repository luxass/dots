import { Buffer } from "node:buffer";
import { execFile } from "node:child_process";
import { open, readdir, realpath, stat } from "node:fs/promises";
import { basename, join, relative, sep } from "node:path";

import { SafeError } from "./transport.mjs";

const LIMIT = 1024 * 1024;

/** File extensions for each file format. The first is the default. */
export const FORMATS = {
  markdown: ["md", "markdown"],
  html: ["html", "htm"],
  svg: ["svg"],
  mermaid: ["mmd", "mermaid"],
  css: ["css"],
  javascript: ["js", "mjs"],
  json: ["json"],
  text: ["txt"],
  csv: ["csv"],
};

const SUPPORTED = ".md, .html, .svg, .mmd, .css, .js, .mjs, .json, .txt, or .csv";

/** Skipped when saving a directory. */
const SKIPPED = new Set(["node_modules", ".git"]);

/**
 * The format name for a file path, or undefined for an unsupported type.
 * @param {string} path
 */
export function formatFromPath(path) {
  const extension = /\.([a-z]+)$/iu.exec(path)?.[1]?.toLowerCase() ?? "";

  return Object.entries(FORMATS).find(([, extensions]) => extensions.includes(extension))?.[0];
}

/** @param {string} path */
export async function readFile(path) {
  let handle;

  try {
    if (!(await stat(path)).isFile()) throw new SafeError(path + " is not a regular file.");
    handle = await open(path, "r");

    if (!(await handle.stat()).isFile()) throw new SafeError(path + " is not a regular file.");
    const buffer = Buffer.alloc(LIMIT + 1);
    let length = 0;

    while (length < buffer.length) {
      const { bytesRead } = await handle.read(buffer, length, buffer.length - length, null);

      if (!bytesRead) break;
      length += bytesRead;
    }

    if (length > LIMIT) throw new SafeError(path + " is larger than 1 MiB.");
    const body = buffer.subarray(0, length);
    let content;

    try {
      content = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(body);
    } catch {
      throw new SafeError(path + " must contain valid UTF-8.");
    }

    if (content.length === 0) throw new SafeError(path + " is empty.");

    return { body, content };
  } catch (error) {
    if (error instanceof SafeError) throw error;
    throw new SafeError(path + " could not be read.");
  } finally {
    await handle?.close();
  }
}

/**
 * Every file in a directory, with paths relative to it, using forward slashes. Hidden entries,
 * node_modules, and .git are skipped. Unsupported file types stop the save with their list.
 * @param {string} directory
 */
export async function directoryFiles(directory) {
  /** @type {string[]} */
  const found = [];

  /** @param {string} current */
  const walk = async (current) => {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      if (entry.name.startsWith(".") || SKIPPED.has(entry.name)) continue;
      const full = join(current, entry.name);

      if (entry.isDirectory()) await walk(full);
      else if (entry.isFile()) found.push(relative(directory, full).split(sep).join("/"));
    }
  };

  try {
    await walk(directory);
  } catch {
    throw new SafeError(directory + " could not be read.");
  }

  const unsupported = found.filter((path) => formatFromPath(path) === undefined);

  if (unsupported.length > 0)
    throw new SafeError(
      "These files have unsupported types: " + unsupported.join(", ") + ". Use " + SUPPORTED + ".",
    );

  if (found.length === 0) throw new SafeError(directory + " has no files to save.");

  return found;
}

/**
 * @param {string} path
 */
export function requireSupported(path) {
  if (formatFromPath(path) === undefined)
    throw new SafeError(path + " has an unsupported type. Use " + SUPPORTED + ".");
}

/** @param {string[]} args @returns {Promise<string>} */
function gitOutput(args) {
  return new Promise((resolve, reject) => {
    execFile(
      "git",
      args,
      { timeout: 2000, maxBuffer: 16_384, encoding: "utf8" },
      (error, stdout) => {
        if (error === null) resolve(stdout);
        else reject(new SafeError("Local Git context is unavailable."));
      },
    );
  });
}

/** @param {string} remote */
export function repositoryIdentity(remote) {
  if (!remote.trim()) return "";
  remote = remote.trim();

  if (/^(?:\/|\.{1,2}\/|[a-z]:[\\/])/iu.test(remote) || remote.includes("\\"))
    throw new SafeError("Local repository paths cannot be attached.");

  const scp = /^[^/@]+:\d+\//u.test(remote)
    ? null
    : /^(?:[^@/\s]+@)?([^:/\s]+):(.+)$/u.exec(remote);

  let url;

  try {
    url = new URL(
      remote.includes("://")
        ? remote
        : scp
          ? "ssh://" + scp[1] + "/" + scp[2]
          : "https://" + remote,
    );
  } catch {
    throw new SafeError("Use a repository URL or host/owner/repository identity.");
  }

  const path = url.pathname.replaceAll(/^\/+|\/+$/gu, "").replace(/\.git$/iu, "");

  if (
    !["https:", "http:", "ssh:"].includes(url.protocol) ||
    !url.hostname ||
    !path ||
    path.split("/").some((part) => !part || part === "." || part === "..")
  )
    throw new SafeError("Use a repository URL with a repository path.");

  return url.hostname.toLowerCase() + (url.port ? ":" + url.port : "") + "/" + path;
}

/**
 * The folder that identifies this project for its saved Wrenlo choice: the Git top level, or the
 * working folder outside Git. Resolved, so links and moved folders never match an old choice.
 */
export async function projectRoot() {
  let root = process.cwd();

  try {
    root = (await gitOutput(["rev-parse", "--show-toplevel"])).trim() || root;
  } catch {
    // Outside Git, the working folder is the project.
  }

  return realpath(root);
}

/** Read only local Git context; failure must not prevent a save. */
export async function gitContext() {
  let project = basename(process.cwd());

  try {
    const stdout = await gitOutput(["rev-parse", "--show-toplevel"]);
    project = basename(stdout.trim()) || project;
  } catch {
    return { project };
  }

  try {
    const stdout = await gitOutput(["config", "--local", "--get", "remote.origin.url"]);
    const repository = repositoryIdentity(stdout.trim());

    return { repository, project: repository.split("/").at(-1) ?? project };
  } catch {
    return { project };
  }
}

/**
 * Builds the metadata to send. The server validates and normalizes every field and returns
 * a clear error, so only local work happens here: Git context and cleaned repository identities.
 * @param {{id?: string, title?: string, project?: string, repository?: string, tag?: string[], folder?: string, unfiled?: boolean, "clear-tags"?: boolean}} values
 */
export async function metadata(values) {
  if (values.folder !== undefined && values.unfiled === true)
    throw new SafeError("Choose --folder or --unfiled, not both.");

  if (values.tag !== undefined && values["clear-tags"] === true)
    throw new SafeError("Choose --tag or --clear-tags, not both.");
  /** @type {{title?: string, project?: string, repository?: string, tags?: string[], folder?: string | null}} */
  const result = {};

  if (values.id === undefined) {
    // New artifacts get Git labels. The derived project is cut to the server's 80-character limit.
    const context = await gitContext();
    result.project = Array.from(context.project).slice(0, 80).join("");

    if (context.repository !== undefined) result.repository = context.repository;
  }

  if (values.title !== undefined) result.title = values.title;

  if (values.project !== undefined) result.project = values.project;

  // Cleaned locally, so remote URLs never upload credentials.
  if (values.repository !== undefined) result.repository = repositoryIdentity(values.repository);

  if (values.tag !== undefined) result.tags = values.tag;
  else if (values["clear-tags"] === true) result.tags = [];

  if (values.folder !== undefined) result.folder = values.folder;
  else if (values.unfiled === true) result.folder = null;

  return result;
}
