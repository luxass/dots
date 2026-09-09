import { execFile } from "node:child_process";
import { Plugin } from "@opencode/plugin";

const SCRIPT = 'display notification "Session completed" with title "opencode"';

async function notify(): Promise<void> {
  if (process.platform !== "darwin") return;
  await new Promise<void>((resolve) => {
    execFile("osascript", ["-e", SCRIPT], (error) => {
      if (error) console.error(`notification failed: ${error.message}`);
      resolve();
    });
  });
}

export default Plugin.define({
  id: "notification",
  async setup(ctx) {
    const controller = new AbortController();
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type !== "session.idle") continue;
          await notify();
        }
      } catch (error) {
        if ((error as Error)?.name !== "AbortError") console.error(error);
      }
    })();
    return () => controller.abort();
  },
});
