/**
 * Inline skills: use `/skill:name` anywhere in a prompt, not only at the start.
 *
 * - Autocomplete suggests skills after a mid-prompt `/`.
 * - On submit, each mentioned skill is loaded once and placed before the prompt.
 *
 * Temporary experiment for Pi 1.5. Remove this file and `/reload` to disable.
 *
 * @example
 * // You type:
 * Open a PR with /skill:github and keep it short.
 *
 * // The model receives:
 * <skill name="github" location="…/github/SKILL.md">
 * …instructions…
 * </skill>
 *
 * Open a PR with /skill:github and keep it short.
 */
import { readFile } from "node:fs/promises";
import { dirname } from "node:path";
import {
  CustomEditor,
  stripFrontmatter,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { fuzzyFilter } from "@earendil-works/pi-tui";

const SKILL_PREFIX = "/skill:";

/**
 * A partial mention just before the cursor (`|` marks the cursor).
 *
 * @example
 * "use /|"          // matches "/"
 * "use /sk|"        // matches "/sk"
 * "use /skill:gi|"  // matches "/skill:gi"
 * "path/to/|"       // no match: the "/" is not after a space
 */
const PARTIAL_MENTION = /(?:^|[ \t])(\/[a-z0-9:-]*)$/;

/**
 * A complete mention, followed by whitespace, punctuation, or the end of the text.
 *
 * @example
 * "use /skill:github."        // matches "skill:github"
 * "(see /skill:gh-stack)"     // matches "skill:gh-stack"
 * "https://x.dev/skill:a"     // no match: the "/" is not after a space
 */
const MENTION = /(?:^|\s)\/(skill:[a-z0-9-]+)(?=$|[\s.,!?;:)\]}])/g;

export default function inlineSkills(pi: ExtensionAPI) {
  const getSkills = () => pi.getCommands().filter((command) => command.source === "skill");

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    /**
     * Wrap Pi's autocomplete provider (`current`). Mid-prompt skill mentions get
     * skill suggestions; everything else goes to `current` unchanged.
     *
     * @example
     * "Open a PR with /skill:gi|"
     * // Menu shows: /skill:github, /skill:gh-stack
     * // Enter or Tab gives: "Open a PR with /skill:github |"
     *
     * "/mod|"  or  "look at @src/|"
     * // Not a mid-prompt skill mention: Pi's own suggestions.
     */
    ctx.ui.addAutocompleteProvider((current) => ({
      triggerCharacters: current.triggerCharacters,

      async getSuggestions(lines, line, col, options) {
        const mention = findPartialMention(lines, line, col);
        if (!mention) return current.getSuggestions(lines, line, col, options);

        const query = mention.slice(SKILL_PREFIX.length);
        const matches = fuzzyFilter(getSkills(), query, (skill) =>
          skill.name.slice("skill:".length),
        );
        if (matches.length === 0) return null;

        return {
          // Without the leading "/", Pi treats this as a text completion: Enter
          // inserts the skill instead of submitting the prompt.
          prefix: mention.slice(1),
          items: matches.map((skill) => ({
            value: `${skill.name} `,
            label: `/${skill.name}`,
            description: skill.description,
          })),
        };
      },

      applyCompletion: (...args) => current.applyCompletion(...args),
      shouldTriggerFileCompletion: (...args) =>
        current.shouldTriggerFileCompletion?.(...args) ?? true,
    }));

    openAutocompleteOnSlash(ctx);
  });

  /**
   * Prepend each known skill mentioned outside code, once, in order of first mention.
   * All skills share one <skill> block: Pi's chat display folds only one leading block,
   * so it shows "[skill] github, commit" followed by your text.
   *
   * @example
   * // You type:
   * Use /skill:github, then /skill:commit. Again /skill:github, but not `/skill:commit`.
   *
   * // The model receives:
   * <skill name="github, commit" location="/Users/me/.agents/skills/github/SKILL.md">
   * # Skill: github
   * Location: /Users/me/.agents/skills/github/SKILL.md
   * References are relative to /Users/me/.agents/skills/github.
   *
   * …github instructions…
   *
   * ---
   *
   * # Skill: commit
   * …
   * </skill>
   *
   * Use /skill:github, then /skill:commit. Again /skill:github, but not `/skill:commit`.
   */
  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") return;

    const skillsByName = new Map(getSkills().map((skill) => [skill.name, skill]));
    const mentioned = new Set(
      [...hideCode(event.text).matchAll(MENTION)]
        .map(([, name]) => skillsByName.get(name))
        .filter((skill) => skill !== undefined),
    );
    if (mentioned.size === 0) return;

    try {
      const skills = [...mentioned];
      const names = skills.map((skill) => skill.name.slice("skill:".length));

      // One section per skill, so the model still knows where each one came from.
      const sections = await Promise.all(
        skills.map(async (skill, index) => {
          const path = skill.sourceInfo.path;
          const instructions = stripFrontmatter(await readFile(path, "utf8")).trim();
          return [
            `# Skill: ${names[index]}`,
            `Location: ${path}`,
            `References are relative to ${dirname(path)}.`,
            "",
            instructions,
          ].join("\n");
        }),
      );

      const block = [
        `<skill name="${names.join(", ")}" location="${skills[0].sourceInfo.path}">`,
        sections.join("\n\n---\n\n"),
        "</skill>",
      ].join("\n");

      // Pi only expands a skill at the very start of the prompt. Our block comes
      // first, so a leading mention is not expanded a second time.
      return { action: "transform", text: `${block}\n\n${event.text}` };
    } catch (error) {
      // Do not send the prompt without a skill the user asked for.
      ctx.ui.notify(`Inline skills: could not load a skill: ${String(error)}`, "error");
      if (!ctx.ui.getEditorText()) ctx.ui.setEditorText(event.text);
      return { action: "handled" };
    }
  });
}

/**
 * Return the partial skill mention before the cursor, or `undefined`.
 * A mention at the start of the message is left to Pi's own slash commands.
 *
 * @example
 * findPartialMention(["use /skill:gi"], 0, 13)   // "/skill:gi"
 * findPartialMention(["first", "/sk"], 1, 3)     // "/sk" (later lines count)
 * findPartialMention(["/skill:gi"], 0, 9)        // undefined: starts the message
 * findPartialMention(["use /model"], 0, 10)      // undefined: not a skill
 * findPartialMention(["run `/skill:gi"], 0, 14)  // undefined: inside code
 */
function findPartialMention(lines: string[], line: number, col: number) {
  const textBeforeCursor = (lines[line] ?? "").slice(0, col);
  const mention = PARTIAL_MENTION.exec(textBeforeCursor)?.[1];
  if (!mention) return;

  const couldBeSkill = SKILL_PREFIX.startsWith(mention) || mention.startsWith(SKILL_PREFIX);
  const startsMessage = line === 0 && textBeforeCursor === mention;
  if (!couldBeSkill || startsMessage) return;

  const textUpToCursor = [...lines.slice(0, line), textBeforeCursor].join("\n");
  if (!hideCode(textUpToCursor).endsWith(mention)) return;

  return mention;
}

/**
 * Pi does not accept "/" as an autocomplete trigger in the middle of a prompt.
 * Wrap the editor and open its autocomplete after each edit that leaves the
 * cursor on a skill mention.
 *
 * This uses the editor's private `requestAutocomplete()` method.
 *
 * @example
 * // Typing "/" in "Please use |"   -> menu opens
 * // Typing "g" in "use /skill:|"   -> menu opens or updates
 * // Escape in "use /skill:gi|"     -> menu closes and stays closed
 */
function openAutocompleteOnSlash(ctx: ExtensionContext) {
  const createPreviousEditor = ctx.ui.getEditorComponent();

  ctx.ui.setEditorComponent((tui, theme, keybindings) => {
    const editor = (createPreviousEditor?.(tui, theme, keybindings) ??
      new CustomEditor(tui, theme, keybindings)) as CustomEditor;
    const privateEditor = editor as unknown as {
      requestAutocomplete?(options: { force: boolean; explicitTab: boolean }): void;
    };

    if (typeof privateEditor.requestAutocomplete !== "function") {
      ctx.ui.notify("Inline skills: Pi's editor changed. Use Tab to complete skills.", "warning");
      return editor;
    }

    const handleInput = editor.handleInput.bind(editor);
    editor.handleInput = (data) => {
      const textBefore = editor.getText();
      handleInput(data);

      // Keys that do not change the text, such as Escape, keep the menu closed.
      const textChanged = editor.getText() !== textBefore;
      if (!textChanged || editor.isShowingAutocomplete()) return;

      const { line, col } = editor.getCursor();
      if (findPartialMention(editor.getLines(), line, col)) {
        privateEditor.requestAutocomplete?.({ force: false, explicitTab: false });
      }
    };

    return editor;
  });
}

/**
 * Replace inline code and code fences with spaces, so mentions inside them are
 * ignored. Offsets stay the same. An unclosed code span runs to the end.
 *
 * @example
 * hideCode("run `/skill:a` now")  // "run            now"
 * hideCode("run `/skill:a")        // "run          "
 */
function hideCode(text: string) {
  return text.replace(/(`+)[\s\S]*?(?:\1|$)/g, (code) => code.replace(/[^\n]/g, " "));
}
