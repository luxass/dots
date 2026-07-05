import type { Plugin } from "@opencode-ai/plugin"

export const AppleScriptNotification = (async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return

      await $`osascript -e 'display notification "Session completed" with title "opencode"'`.quiet()
    },
  }
}) satisfies Plugin
