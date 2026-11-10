import { execFile } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Publish Plannotator plan and code reviews to the tailnet through Tailscale Serve.
// Plannotator keeps listening on 127.0.0.1; Serve adds an HTTPS proxy for each
// session while it is open and removes it when the session closes.
//
// Annotation sessions are not published: they include an agent terminal, which
// Plannotator disables only for remote and --tailscale sessions.

const SESSION_OPENED = "plannotator:session-opened";
const SESSION_CLOSED = "plannotator:session-closed";
const PUBLISHED_ACTIONS = new Set(["plan-review", "code-review"]);
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]"]);

/** True for loopback names, including `*.localhost` such as Plannotator's `urlHost`. */
function isLoopbackHostname(hostname: string): boolean {
  const name = hostname.toLowerCase();
  return LOOPBACK_HOSTS.has(name) || name.endsWith(".localhost");
}
const ALLOWED_HOSTS_ENV = "PLANNOTATOR_ALLOWED_HOSTS";
const TAILSCALE_TIMEOUT_MS = 10_000;
const TAILSCALE_COMMANDS = ["tailscale", "/Applications/Tailscale.app/Contents/MacOS/Tailscale"];

const STATE_FILE = join(
  process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"),
  "pi",
  "plannotator-tailscale.json",
);

interface PlannotatorSessionEvent {
  id: string;
  action: string;
  url: string;
}

interface RecordedMapping {
  port: number;
  pid: number;
}

interface ServeStatus {
  TCP?: Record<string, unknown>;
  Web?: Record<string, { Handlers?: Record<string, { Proxy?: string }> }>;
}

// Plannotator may deliver a close event to a newer extension instance than the
// one that saw the open (after /reload, /new, or /resume), so mappings live in
// one process-wide store. Versioned so a differently shaped copy is never read.
interface SharedState {
  tailnetHost: string | undefined;
  mappings: Map<string, Promise<number | undefined>>;
  context: ExtensionContext | undefined;
}

const STATE_KEY = "__plannotatorTailscaleState_v1";

function sharedState(): SharedState {
  const store = globalThis as typeof globalThis & Record<string, unknown>;
  const existing = store[STATE_KEY] as SharedState | undefined;
  if (existing) return existing;
  const created: SharedState = { tailnetHost: undefined, mappings: new Map(), context: undefined };
  store[STATE_KEY] = created;
  return created;
}

function isSessionEvent(data: unknown): data is PlannotatorSessionEvent {
  if (typeof data !== "object" || data === null) return false;
  const event = data as Record<string, unknown>;
  return typeof event.id === "string" && typeof event.action === "string" && typeof event.url === "string";
}

function notify(message: string, type: "info" | "warning" = "info"): void {
  const context = sharedState().context;
  if (!context?.hasUI) return;
  try {
    context.ui.notify(message, type);
  } catch {
    // The context belongs to a session that was replaced; drop the message.
  }
}

function describeError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function runCommand(command: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(command, args, { timeout: TAILSCALE_TIMEOUT_MS }, (error, stdout, stderr) => {
      if (error) {
        const detail = stderr.trim();
        reject(Object.assign(error, { message: detail || error.message }));
        return;
      }
      resolve(stdout);
    });
  });
}

/** Runs the Tailscale CLI, falling back to the copy inside the macOS app. */
async function runTailscale(args: string[]): Promise<string> {
  let lastError: unknown;
  for (const command of TAILSCALE_COMMANDS) {
    try {
      return await runCommand(command, args);
    } catch (error) {
      lastError = error;
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
  throw lastError;
}

/** Returns this machine's MagicDNS name, or undefined when Tailscale is off or logged out. */
async function readTailnetHost(): Promise<string | undefined> {
  try {
    const status = JSON.parse(await runTailscale(["status", "--json"])) as {
      BackendState?: string;
      Self?: { DNSName?: string };
    };
    if (status.BackendState !== "Running") return undefined;
    const name = status.Self?.DNSName?.replace(/\.$/, "");
    return name || undefined;
  } catch {
    return undefined;
  }
}

async function readServeStatus(): Promise<ServeStatus> {
  return JSON.parse(await runTailscale(["serve", "status", "--json"])) as ServeStatus;
}

function loopbackTarget(port: number): string {
  return `http://127.0.0.1:${port}`;
}

/** True when Serve proxies the port to this extension's loopback target. */
function servesOurTarget(status: ServeStatus, host: string, port: number): boolean {
  return status.Web?.[`${host}:${port}`]?.Handlers?.["/"]?.Proxy === loopbackTarget(port);
}

function addAllowedHost(host: string): void {
  const entries = (process.env[ALLOWED_HOSTS_ENV] ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (entries.some((entry) => entry.toLowerCase() === host.toLowerCase())) return;
  process.env[ALLOWED_HOSTS_ENV] = [...entries, host].join(",");
}

async function readRecordedMappings(): Promise<RecordedMapping[]> {
  try {
    const parsed = JSON.parse(await readFile(STATE_FILE, "utf8")) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (entry): entry is RecordedMapping =>
        Number.isInteger(entry?.port) && Number.isInteger(entry?.pid),
    );
  } catch {
    return [];
  }
}

async function writeRecordedMappings(mappings: RecordedMapping[]): Promise<void> {
  await mkdir(dirname(STATE_FILE), { recursive: true });
  await writeFile(STATE_FILE, `${JSON.stringify(mappings, null, 2)}\n`);
}

async function recordMapping(port: number): Promise<void> {
  const mappings = (await readRecordedMappings()).filter((entry) => entry.port !== port);
  await writeRecordedMappings([...mappings, { port, pid: process.pid }]);
}

async function forgetMapping(port: number): Promise<void> {
  const mappings = await readRecordedMappings();
  await writeRecordedMappings(mappings.filter((entry) => entry.port !== port));
}

function processIsAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === "EPERM";
  }
}

/** Removes a mapping only while it still points at this extension's target. */
async function removeMapping(host: string, port: number): Promise<void> {
  try {
    const status = await readServeStatus();
    if (servesOurTarget(status, host, port)) {
      await runTailscale(["serve", `--https=${port}`, "off"]);
    }
  } catch (error) {
    notify(
      `Plannotator Tailscale: could not remove the mapping for port ${port} (${describeError(error)}). ` +
        `Run: tailscale serve --https=${port} off`,
      "warning",
    );
    return;
  }
  await forgetMapping(port).catch(() => undefined);
}

/** After a crash or SIGKILL, remove mappings whose Pi process no longer runs. */
async function removeStaleMappings(host: string): Promise<void> {
  const recorded = await readRecordedMappings();
  const stale = recorded.filter((entry) => !processIsAlive(entry.pid));
  for (const entry of stale) {
    await removeMapping(host, entry.port);
  }
}

async function publishSession(host: string, event: PlannotatorSessionEvent): Promise<number | undefined> {
  const sessionUrl = new URL(event.url);
  if (!isLoopbackHostname(sessionUrl.hostname)) return undefined;
  const port = Number(sessionUrl.port);
  if (!Number.isInteger(port) || port <= 0) return undefined;

  try {
    const status = await readServeStatus();
    if (status.TCP?.[String(port)] !== undefined) {
      notify(
        `Plannotator Tailscale: port ${port} already has a Serve mapping, so this review stays local.`,
        "warning",
      );
      return undefined;
    }

    await runTailscale(["serve", "--bg", `--https=${port}`, loopbackTarget(port)]);
    await recordMapping(port).catch(() => undefined);
  } catch (error) {
    notify(`Plannotator Tailscale: could not publish the review (${describeError(error)}).`, "warning");
    return undefined;
  }

  const tailnetUrl = new URL(sessionUrl.pathname + sessionUrl.search + sessionUrl.hash, `https://${host}:${port}`);
  notify(`Plannotator on your tailnet: ${tailnetUrl.href}`);
  return port;
}

function handleSessionOpened(data: unknown): void {
  const state = sharedState();
  const host = state.tailnetHost;
  if (!host || !isSessionEvent(data) || !PUBLISHED_ACTIONS.has(data.action)) return;
  if (state.mappings.has(data.id)) return;
  state.mappings.set(data.id, publishSession(host, data));
}

function handleSessionClosed(data: unknown): void {
  const state = sharedState();
  if (!isSessionEvent(data)) return;
  const pending = state.mappings.get(data.id);
  if (!pending) return;
  state.mappings.delete(data.id);

  void pending.then((port) => {
    const host = state.tailnetHost;
    if (port !== undefined && host) return removeMapping(host, port);
  });
}

async function removeAllMappings(): Promise<void> {
  const state = sharedState();
  const host = state.tailnetHost;
  const pending = [...state.mappings.values()];
  state.mappings.clear();
  const ports = await Promise.all(pending);
  if (!host) return;
  for (const port of ports) {
    if (port !== undefined) await removeMapping(host, port);
  }
}

export default function plannotatorTailscale(pi: ExtensionAPI): void {
  pi.events.on(SESSION_OPENED, handleSessionOpened);
  pi.events.on(SESSION_CLOSED, handleSessionClosed);

  pi.on("session_start", async (event, ctx) => {
    const state = sharedState();
    state.context = ctx;

    if (state.tailnetHost === undefined) {
      state.tailnetHost = await readTailnetHost();
    }
    const host = state.tailnetHost;
    if (!host) return;

    // Plannotator refuses requests whose Host header it does not recognize,
    // and Serve forwards the tailnet name as the Host header.
    addAllowedHost(host);

    if (event.reason === "startup") {
      await removeStaleMappings(host);
    }
  });

  pi.on("session_shutdown", async (event, ctx) => {
    const state = sharedState();
    if (state.context === ctx) state.context = undefined;

    // On /reload, /new, /resume, and /fork the process keeps running and its
    // open reviews stay open, so their mappings stay until they close.
    if (event.reason === "quit") {
      await removeAllMappings();
    }
  });
}
