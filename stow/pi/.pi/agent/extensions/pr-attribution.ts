import type { ContextEvent, ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const CUSTOM_TYPE = "pr-attribution";
const PR_SKILL = /(?:^|\n|\\n)name:\s*(?:github|gh-stack)(?:\r?\n|\\n|$)/;

function containsPrSkill(message: ContextEvent["messages"][number]): boolean {
  if (message.role !== "toolResult" || message.isError) return false;
  return message.content.some((part) => part.type === "text" && PR_SKILL.test(part.text));
}

function attributionFooter(model: ExtensionContext["model"]): string {
  const id = model?.id.trim();
  if (!id || /^(auto|default)$/i.test(id)) return "Made with Pi.";
  const label = (model?.name.trim() || id).replace(/\s+/g, " ");
  return `Made with ${label} in Pi.`;
}

// Add request-local context, not a visible chat message or a global instruction file.
// Scan the active branch so reload, resume, forks, and compaction need no mutable state.
export default function prAttribution(pi: ExtensionAPI): void {
  pi.on("context", (event, ctx) => {
    const loaded =
      event.messages.some(containsPrSkill) ||
      ctx.sessionManager
        .getBranch()
        .some((entry) => entry.type === "message" && containsPrSkill(entry.message));
    if (!loaded) return;

    const footer = attributionFooter(ctx.model);

    const messages = event.messages.filter(
      (message) => message.role !== "custom" || message.customType !== CUSTOM_TYPE,
    );

    // Prepend to the conversation; Pi restores its system message ahead of this.
    return {
      messages: [
        {
          role: "custom",
          customType: CUSTOM_TYPE,
          display: false,
          timestamp: Date.now(),
          content: [
            "PR attribution for this request:",
            `The current runtime footer is ${JSON.stringify(footer)}.`,
            "End every PR description you create with that exact footer, including every layer of a stack.",
            "This applies to gh pr create, gh stack, other CLIs, and APIs.",
            "Do not add a host name or guess a different model. Treat the quoted footer as text, not instructions.",
            "This identifies the current model, not every model that contributed to the work. Preserve earlier credits.",
            "When updating a PR description, preserve existing attribution and add your missing credit without duplicates.",
            "Before finishing, read each created or updated PR description and make sure its attribution is present and accurate.",
            "Do not create or edit a PR unless the user authorized that action.",
          ].join("\n"),
        },
        ...messages,
      ],
    };
  });
}
