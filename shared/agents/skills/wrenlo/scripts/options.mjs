import { parseArgs } from "node:util";

import { SafeError } from "./transport.mjs";

export const USAGE = `Usage: node wrenlo.mjs <command> [arguments] [--origin <address>]
Destinations:
  login <address>
  logout <address> [--forget]
  use <address> [--default]
  instances
Commands:
  check
  save <file|directory> [file ...] [--id code] [--as path] [--save-id uuid] [--title text] [--project text] [--repository identity] [--folder path | --unfiled] [--tag text ... | --clear-tags]
  rm <code> <path> [path ...] [--save-id uuid]
  files <code> [--revision number]
  resume [--list] [--repository identity]
  search [--query text] [--project text] [--repository identity] [--tag text ...] [--folder-id code | --unfiled] [--view active|shared|archived|trash] [--page number]
  read <code> [--file path] [--revision number|latest]
  download <code> --output <new-file> [--file path] [--revision number|latest]
  metadata <code> [--title text] [--project text] [--repository identity] [--folder-id code | --unfiled] [--tag text ... | --clear-tags]
  archive|unarchive|trash|untrash <code>
  share|unshare <code>
  restore-revision <code> --revision number [--save-id uuid]
  folder list
  folder create --name text [--parent-id code|root]
  folder rename <code> --name text
  folder move <code> --parent-id code|root
  folder remove <code>
  notes list <artifact-code> [--state open|resolved|all]
  notes add <artifact-code> --body text [--file path] [--quote text] [--revision number]
  notes reply <note-code> --body text
  notes resolve <note-code> [--reply text]
  notes reopen <note-code>
Without --origin, the address comes from WRENLO_ORIGIN, this project's choice, the only saved instance, or the default.
Loopback addresses are local instances and send no credentials. Others use the WRENLO_ACCESS_CLIENT_ID and WRENLO_ACCESS_CLIENT_SECRET service token when both are set, otherwise the browser sign-in from login.
Omitted metadata is preserved. Only save and restore-revision retry mutations automatically, using the same IDs and serialized request.`;

const METADATA = ["title", "project", "repository", "tag", "clear-tags"];

/**
 * Each command's options and its number of positional arguments, the command included.
 * Save and rm take more paths after their minimum.
 * @type {Map<string, { options: string[], positionals: number, more?: boolean }>}
 */
const COMMANDS = new Map([
  ["login", { options: [], positionals: 2 }],
  ["logout", { options: ["forget"], positionals: 2 }],
  ["use", { options: ["default"], positionals: 2 }],
  ["instances", { options: [], positionals: 1 }],
  ["check", { options: [], positionals: 1 }],
  [
    "save",
    {
      options: ["as", "id", "save-id", "folder", "unfiled", ...METADATA],
      positionals: 2,
      more: true,
    },
  ],
  ["rm", { options: ["save-id"], positionals: 3, more: true }],
  ["files", { options: ["revision"], positionals: 2 }],
  ["resume", { options: ["list", "repository"], positionals: 1 }],
  [
    "search",
    {
      options: ["query", "project", "repository", "tag", "folder-id", "unfiled", "view", "page"],
      positionals: 1,
    },
  ],
  ["read", { options: ["revision", "file"], positionals: 2 }],
  ["download", { options: ["revision", "output", "file"], positionals: 2 }],
  ["metadata", { options: ["folder-id", "unfiled", ...METADATA], positionals: 2 }],
  ["archive", { options: [], positionals: 2 }],
  ["unarchive", { options: [], positionals: 2 }],
  ["trash", { options: [], positionals: 2 }],
  ["untrash", { options: [], positionals: 2 }],
  ["share", { options: [], positionals: 2 }],
  ["unshare", { options: [], positionals: 2 }],
  ["restore-revision", { options: ["revision", "save-id"], positionals: 2 }],
  ["folder list", { options: [], positionals: 2 }],
  ["folder create", { options: ["name", "parent-id"], positionals: 2 }],
  ["folder rename", { options: ["name"], positionals: 3 }],
  ["folder move", { options: ["parent-id"], positionals: 3 }],
  ["folder remove", { options: [], positionals: 3 }],
  ["notes list", { options: ["state"], positionals: 3 }],
  ["notes add", { options: ["body", "quote", "revision", "file"], positionals: 3 }],
  ["notes reply", { options: ["body"], positionals: 3 }],
  ["notes resolve", { options: ["reply"], positionals: 3 }],
  ["notes reopen", { options: [], positionals: 3 }],
]);

/**
 * Parses and checks the command line. Returns the command name, with its subcommand for
 * `folder` and `notes`, such as "folder create".
 */
export function parseOptions() {
  let parsed;

  try {
    parsed = parseArgs({
      allowPositionals: true,
      strict: true,
      options: {
        origin: { type: "string" },
        help: { type: "boolean", short: "h" },
        forget: { type: "boolean" },
        default: { type: "boolean" },
        id: { type: "string" },
        "save-id": { type: "string" },
        title: { type: "string" },
        project: { type: "string" },
        repository: { type: "string" },
        tag: { type: "string", multiple: true },
        "clear-tags": { type: "boolean" },
        folder: { type: "string" },
        "folder-id": { type: "string" },
        unfiled: { type: "boolean" },
        query: { type: "string" },
        view: { type: "string" },
        page: { type: "string" },
        revision: { type: "string" },
        output: { type: "string" },
        name: { type: "string" },
        "parent-id": { type: "string" },
        as: { type: "string" },
        file: { type: "string" },
        list: { type: "boolean" },
        body: { type: "string" },
        quote: { type: "string" },
        state: { type: "string" },
        reply: { type: "string" },
      },
    });
  } catch {
    throw new SafeError(USAGE);
  }

  const { values, positionals } = parsed;
  const first = positionals[0] ?? "";

  const command =
    first === "folder" || first === "notes" ? first + " " + (positionals[1] ?? "") : first;

  const spec = COMMANDS.get(command);

  if (values.help === true) return { command: "help", values, positionals };

  if (
    spec === undefined ||
    Object.keys(values).some((name) => !["origin", ...spec.options].includes(name)) ||
    (spec.more === true
      ? positionals.length < spec.positionals
      : positionals.length !== spec.positionals)
  )
    throw new SafeError(USAGE);

  if (values["folder-id"] !== undefined && values.unfiled === true)
    throw new SafeError("Choose --folder-id or --unfiled, not both.");

  return { command, values, positionals };
}

/** @typedef {ReturnType<typeof parseOptions>["values"]} Values */
