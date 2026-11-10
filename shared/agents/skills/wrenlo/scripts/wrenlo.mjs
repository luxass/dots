#!/usr/bin/env node
import { connect, login, logout } from "./auth.mjs";
import { parseOptions, USAGE } from "./options.mjs";
import { artifactDetails, folder, notes } from "./organize.mjs";
import { check, files, read, resume, search } from "./read.mjs";
import { restore, save } from "./save.mjs";
import { chooseInstance, listInstances } from "./settings.mjs";
import { SafeError } from "./transport.mjs";

/**
 * Runs one command and returns what it prints as JSON.
 * @param {ReturnType<typeof parseOptions>} options
 */
async function run({ command, values, positionals }) {
  switch (command) {
    case "login":
      return login(positionals[1]);
    case "logout":
      return logout(positionals[1], values.forget === true);
    case "use":
      return chooseInstance(positionals[1], values.default === true);
    case "instances":
      return listInstances();
  }

  const target = await connect(values.origin);

  switch (command) {
    case "check":
      return check(target);
    // Receipts name the instance and why it was used, so a save never lands somewhere unnoticed.
    case "save":
    case "rm":
      return Object.assign(await save(target, command, positionals, values), {
        destination: target.origin.origin + " (" + target.source + ")",
      });
    case "restore-revision":
      return Object.assign(await restore(target, positionals, values), {
        destination: target.origin.origin + " (" + target.source + ")",
      });
    case "files":
      return files(target, positionals, values);
    case "search":
      return search(target, values);
    case "read":
    case "download":
      return read(target, command, positionals, values);
    case "resume":
      return resume(target, values);
    default:
      if (command.startsWith("folder ")) return folder(target, command, positionals, values);

      if (command.startsWith("notes ")) return notes(target, command, positionals, values);

      return artifactDetails(target, command, positionals, values);
  }
}

try {
  const options = parseOptions();

  if (options.command === "help") console.log(USAGE);
  else console.log(JSON.stringify(await run(options)));
} catch (error) {
  console.error(
    error instanceof SafeError
      ? error.message
      : "The request could not be completed. No credential or artifact details are printed.",
  );
  process.exitCode = 1;
}
