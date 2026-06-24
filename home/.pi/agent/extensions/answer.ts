/**
 * Q&A extraction hook - extracts questions from assistant responses
 *
 * Custom interactive TUI for answering questions.
 *
 * Demonstrates the "prompt generator" pattern with custom TUI:
 * 1. /answer command gets the last assistant message
 * 2. Shows a spinner while extracting questions as structured JSON
 * 3. Presents an interactive TUI to navigate and answer questions
 * 4. Submits the compiled answers when done
 */

import { complete, type Api, type Model, type UserMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, ModelRegistry } from "@earendil-works/pi-coding-agent";
import { BorderedLoader } from "@earendil-works/pi-coding-agent";
import {
	type Component,
	Editor,
	type EditorTheme,
	Key,
	matchesKey,
	Text,
	truncateToWidth,
	type TUI,
	visibleWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
import { Type } from "typebox";

// Structured output format for question extraction
interface ExtractedQuestion {
	question: string;
	context?: string;
	metadata?: string[];
	choices?: string[];
	multiSelect?: boolean;
	minSelections?: number;
	maxSelections?: number;
}

interface ExtractionResult {
	metadata?: string[];
	questions: ExtractedQuestion[];
}

interface AnsweredQuestion extends ExtractedQuestion {
	answer: string;
	selectedChoices?: string[];
}

interface AnswerCollectionDetails {
	metadata?: string[];
	answers: AnsweredQuestion[];
	source: "explicit" | "sourceText" | "lastAssistant";
	cancelled?: boolean;
	error?: string;
}

type QnAResult = Omit<AnswerCollectionDetails, "source" | "cancelled" | "error">;

const SYSTEM_PROMPT = `You are a question extractor. Given text from a conversation, extract any questions that need answering and any small contextual metadata that would help answer them.

Output a JSON object with this structure:
{
  "metadata": [
    "Optional batch-level context, constraints, assumptions, or facts relevant to all questions"
  ],
  "questions": [
    {
      "question": "The question text",
      "context": "Optional context that helps answer the question",
      "metadata": [
        "Optional per-question context, constraints, assumptions, or facts useful when answering"
      ],
      "choices": [
        "Optional answer choices to show instead of a free-text editor"
      ],
      "multiSelect": false,
      "minSelections": 1,
      "maxSelections": 3
    }
  ]
}

Rules:
- Extract all questions that require user input
- If the input contains TARGET_TEXT and CONVERSATION_CONTEXT sections, extract questions only from TARGET_TEXT
- Keep questions in the order they appeared
- Be concise with question text
- Include context only when it provides essential information for answering
- Include metadata for helpful facts already present in the source text or conversation context; do not invent metadata
- Use conversation context only to populate context/metadata fields, not to add extra questions
- Use batch metadata for shared information, and per-question metadata for question-specific information
- Metadata should be short free-form strings, not rigid categories
- Include choices only when the source text already provides a finite list of options
- Use multiSelect when the user should be able to pick more than one option
- Use minSelections/maxSelections only when the source text states a selection count or limit
- If no questions are found, return {"questions": []}

Example output:
{
  "metadata": [
    "The project currently supports MySQL and PostgreSQL only."
  ],
  "questions": [
    {
      "question": "What is your preferred database?",
      "context": "We can only configure MySQL and PostgreSQL because of what is implemented.",
      "metadata": ["SQLite support is not implemented yet."]
    },
    {
      "question": "Should we use TypeScript or JavaScript?",
      "metadata": ["The existing package already uses TypeScript tooling."],
      "choices": ["TypeScript", "JavaScript"]
    }
  ]
}`;

const CODEX_MODEL_ID = "gpt-5.4-mini";
const HAIKU_MODEL_ID = "claude-haiku-4-5";

const ToolQuestionSchema = Type.Object({
	question: Type.String({ description: "Question to ask the user." }),
	context: Type.Optional(Type.String({ description: "Optional context that helps the user answer this question." })),
	metadata: Type.Optional(
		Type.Array(Type.String(), {
			description: "Short existing contextual facts or constraints relevant to this question.",
		}),
	),
	choices: Type.Optional(
		Type.Array(Type.String(), {
			description: "Optional finite answer choices to show instead of a free-text editor.",
		}),
	),
	multiSelect: Type.Optional(
		Type.Boolean({
			description: "Whether the user may select multiple choices. Only applies when choices are provided.",
		}),
	),
	minSelections: Type.Optional(
		Type.Number({
			description: "Optional minimum number of choices the user should select.",
		}),
	),
	maxSelections: Type.Optional(
		Type.Number({
			description: "Optional maximum number of choices the user should select.",
		}),
	),
});

const AnswerToolParams = Type.Object({
	questions: Type.Optional(
		Type.Array(ToolQuestionSchema, {
			description:
				"Explicit questions to ask. Prefer this when you already know the questions the user must answer.",
		}),
	),
	sourceText: Type.Optional(
		Type.String({
			description:
				"Text to extract questions and contextual metadata from. Used only when explicit questions are not provided.",
		}),
	),
	batchMetadata: Type.Optional(
		Type.Array(Type.String(), {
			description:
				"Short shared contextual facts or constraints that apply to the whole batch of explicit questions.",
		}),
	),
});

type AnswerToolParamsType = {
	questions?: ExtractedQuestion[];
	sourceText?: string;
	batchMetadata?: string[];
};

/**
 * Prefer GPT-5.4 Mini for extraction when available, otherwise fallback to haiku or the current model.
 */
async function selectExtractionModel(
	currentModel: Model<Api>,
	modelRegistry: ModelRegistry,
): Promise<Model<Api>> {
	const codexModel = modelRegistry.find("openai-codex", CODEX_MODEL_ID);
	if (codexModel) {
		const auth = await modelRegistry.getApiKeyAndHeaders(codexModel);
		if (auth.ok) {
			return codexModel;
		}
	}

	const haikuModel = modelRegistry.find("anthropic", HAIKU_MODEL_ID);
	if (!haikuModel) {
		return currentModel;
	}

	const auth = await modelRegistry.getApiKeyAndHeaders(haikuModel);
	if (auth.ok === false) {
		return currentModel;
	}

	return haikuModel;
}

function normalizeMetadata(value: unknown): string[] | undefined {
	if (!Array.isArray(value)) {
		return undefined;
	}

	const metadata = value
		.filter((item): item is string => typeof item === "string")
		.map((item) => item.trim())
		.filter((item) => item.length > 0);

	return metadata.length > 0 ? metadata : undefined;
}

function mergeMetadata(...values: Array<string[] | undefined>): string[] | undefined {
	const merged: string[] = [];
	const seen = new Set<string>();
	for (const value of values) {
		for (const item of value ?? []) {
			const normalized = item.trim();
			if (!normalized || seen.has(normalized)) continue;
			seen.add(normalized);
			merged.push(normalized);
		}
	}
	return merged.length > 0 ? merged : undefined;
}

function normalizeChoices(value: unknown): string[] | undefined {
	if (!Array.isArray(value)) {
		return undefined;
	}

	const choices: string[] = [];
	const seen = new Set<string>();
	for (const item of value) {
		if (typeof item !== "string") continue;
		const normalized = item.trim();
		if (!normalized || seen.has(normalized)) continue;
		seen.add(normalized);
		choices.push(normalized);
	}

	return choices.length > 0 ? choices : undefined;
}

function normalizeSelectionLimit(value: unknown, choicesLength: number): number | undefined {
	if (typeof value !== "number" || !Number.isFinite(value)) {
		return undefined;
	}
	const normalized = Math.floor(value);
	if (normalized < 1) {
		return undefined;
	}
	return Math.min(normalized, choicesLength);
}

function inferSelectionLimits(text: string, choicesLength: number): { minSelections?: number; maxSelections?: number } {
	const normalized = text.toLowerCase();
	const rangeMatch = normalized.match(/(?:select|choose|pick)?\s*(\d+)\s*(?:-|to|–|—)\s*(\d+)\s+(?:options?|choices?|items?|selections?)/);
	if (rangeMatch) {
		const min = normalizeSelectionLimit(Number.parseInt(rangeMatch[1], 10), choicesLength);
		const max = normalizeSelectionLimit(Number.parseInt(rangeMatch[2], 10), choicesLength);
		return {
			minSelections: min && max ? Math.min(min, max) : min,
			maxSelections: min && max ? Math.max(min, max) : max,
		};
	}

	const maxMatch = normalized.match(/(?:up to|at most|max(?:imum)?(?: of)?|no more than)\s+(\d+)\s+(?:options?|choices?|items?|selections?)/);
	if (maxMatch) {
		return { maxSelections: normalizeSelectionLimit(Number.parseInt(maxMatch[1], 10), choicesLength) };
	}

	const minMatch = normalized.match(/(?:at least|min(?:imum)?(?: of)?)\s+(\d+)\s+(?:options?|choices?|items?|selections?)/);
	if (minMatch) {
		return { minSelections: normalizeSelectionLimit(Number.parseInt(minMatch[1], 10), choicesLength) };
	}

	return {};
}

function inferMultiSelect(text: string, minSelections?: number, maxSelections?: number): boolean {
	if ((minSelections && minSelections > 1) || (maxSelections && maxSelections > 1)) {
		return true;
	}

	return /\b(multiple|multi-select|multiselect|one or more|any of|all that apply|select all|choose all|pick all)\b/i.test(text);
}

function normalizeQuestions(value: unknown): ExtractedQuestion[] {
	if (!Array.isArray(value)) {
		return [];
	}

	return value
		.map((item): ExtractedQuestion | null => {
			if (!item || typeof item !== "object") return null;
			const raw = item as Record<string, unknown>;
			if (typeof raw.question !== "string" || raw.question.trim().length === 0) return null;

			const question: ExtractedQuestion = {
				question: raw.question.trim(),
			};
			if (typeof raw.context === "string" && raw.context.trim().length > 0) {
				question.context = raw.context.trim();
			}
			question.metadata = normalizeMetadata(raw.metadata);
			question.choices = normalizeChoices(raw.choices);
			if (question.choices) {
				const inferenceText = [question.question, question.context, ...(question.metadata ?? [])].filter(Boolean).join(" ");
				const inferredLimits = inferSelectionLimits(inferenceText, question.choices.length);
				question.minSelections = normalizeSelectionLimit(raw.minSelections, question.choices.length) ?? inferredLimits.minSelections;
				question.maxSelections = normalizeSelectionLimit(raw.maxSelections, question.choices.length) ?? inferredLimits.maxSelections;
				question.multiSelect = typeof raw.multiSelect === "boolean"
					? raw.multiSelect
					: inferMultiSelect(inferenceText, question.minSelections, question.maxSelections);
				if (!question.multiSelect) {
					question.maxSelections = 1;
				}
			}
			return question;
		})
		.filter((question): question is ExtractedQuestion => question !== null);
}

/**
 * Parse the JSON response from the LLM.
 */
function buildExtractionInput(text: string, contextText?: string): string {
	if (!contextText?.trim()) {
		return text;
	}

	return [
		"Use CONVERSATION_CONTEXT only to enrich context/metadata. Extract questions only from TARGET_TEXT.",
		"",
		"CONVERSATION_CONTEXT:",
		contextText.trim(),
		"",
		"TARGET_TEXT:",
		text,
	].join("\n");
}

function parseExtractionResult(text: string): ExtractionResult | null {
	try {
		// Try to find JSON in the response (it might be wrapped in markdown code blocks)
		let jsonStr = text;

		// Remove markdown code block if present
		const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
		if (jsonMatch) {
			jsonStr = jsonMatch[1].trim();
		}

		const parsed = JSON.parse(jsonStr) as Record<string, unknown>;
		const questions = normalizeQuestions(parsed?.questions);
		if (parsed && Array.isArray(parsed.questions)) {
			return {
				metadata: normalizeMetadata(parsed.metadata),
				questions,
			};
		}
		return null;
	} catch {
		return null;
	}
}

function getMessageRoleAndText(message: unknown): { role: "user" | "assistant"; text: string } | undefined {
	if (!message || typeof message !== "object" || !("role" in message)) {
		return undefined;
	}

	const msg = message as { role?: unknown; content?: unknown };
	if (msg.role === "user") {
		if (typeof msg.content === "string") {
			const text = msg.content.trim();
			return text ? { role: "user", text } : undefined;
		}
		if (Array.isArray(msg.content)) {
			const text = msg.content
				.filter((c): c is { type: "text"; text: string } => Boolean(c && typeof c === "object" && (c as { type?: unknown }).type === "text" && typeof (c as { text?: unknown }).text === "string"))
				.map((c) => c.text)
				.join("\n")
				.trim();
			return text ? { role: "user", text } : undefined;
		}
	}

	if (msg.role === "assistant" && Array.isArray(msg.content)) {
		const text = msg.content
			.filter((c): c is { type: "text"; text: string } => Boolean(c && typeof c === "object" && (c as { type?: unknown }).type === "text" && typeof (c as { text?: unknown }).text === "string"))
			.map((c) => c.text)
			.join("\n")
			.trim();
		return text ? { role: "assistant", text } : undefined;
	}

	return undefined;
}

function truncateContextText(text: string, maxLength = 1200): string {
	return text.length > maxLength ? `${text.slice(0, maxLength).trim()}…` : text;
}

function getRecentConversationContext(ctx: ExtensionContext, targetText: string): string | undefined {
	const branch = ctx.sessionManager.getBranch();
	const entries: string[] = [];
	let skippedTarget = false;

	for (let i = branch.length - 1; i >= 0 && entries.length < 8; i--) {
		const entry = branch[i];
		if (entry.type !== "message") continue;

		const parsed = getMessageRoleAndText(entry.message);
		if (!parsed) continue;

		if (!skippedTarget && parsed.role === "assistant" && parsed.text === targetText.trim()) {
			skippedTarget = true;
			continue;
		}

		const label = parsed.role === "user" ? "User" : "Assistant";
		entries.push(`${label}: ${truncateContextText(parsed.text)}`);
	}

	const context = entries.reverse().join("\n\n").trim();
	return context.length > 0 ? truncateContextText(context, 6000) : undefined;
}

function getLastAssistantText(ctx: ExtensionContext):
	| { ok: true; text: string }
	| { ok: false; reason: "not_found" | "incomplete"; message: string } {
	const branch = ctx.sessionManager.getBranch();

	for (let i = branch.length - 1; i >= 0; i--) {
		const entry = branch[i];
		if (entry.type !== "message") continue;
		const msg = entry.message;
		if (!("role" in msg) || msg.role !== "assistant") continue;

		if (msg.stopReason !== "stop") {
			return {
				ok: false,
				reason: "incomplete",
				message: `Last assistant message incomplete (${msg.stopReason})`,
			};
		}

		const textParts = msg.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text);
		if (textParts.length > 0) {
			return { ok: true, text: textParts.join("\n") };
		}
	}

	return { ok: false, reason: "not_found", message: "No assistant messages found" };
}

async function extractQuestionsFromText(
	ctx: ExtensionContext,
	text: string,
	signal?: AbortSignal,
	contextText?: string,
): Promise<ExtractionResult | null> {
	if (!ctx.model) {
		throw new Error("No model selected");
	}

	const extractionModel = await selectExtractionModel(ctx.model, ctx.modelRegistry);
	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(extractionModel);
	if (auth.ok === false) {
		throw new Error(auth.error);
	}

	const userMessage: UserMessage = {
		role: "user",
		content: [{ type: "text", text: buildExtractionInput(text, contextText) }],
		timestamp: Date.now(),
	};

	const response = await complete(
		extractionModel,
		{ systemPrompt: SYSTEM_PROMPT, messages: [userMessage] },
		{ apiKey: auth.apiKey, headers: auth.headers, signal },
	);

	if (response.stopReason === "aborted") {
		return null;
	}

	const responseText = response.content
		.filter((c): c is { type: "text"; text: string } => c.type === "text")
		.map((c) => c.text)
		.join("\n");

	return preferMarkdownQuestionList(text, parseExtractionResult(responseText));
}

async function extractQuestionsWithLoader(ctx: ExtensionContext, text: string, contextText?: string): Promise<ExtractionResult | null> {
	if (!ctx.model) {
		ctx.ui.notify("No model selected", "error");
		return null;
	}

	const extractionModel = await selectExtractionModel(ctx.model, ctx.modelRegistry);

	return ctx.ui.custom<ExtractionResult | null>((tui, theme, _kb, done) => {
		const loader = new BorderedLoader(tui, theme, `Extracting questions using ${extractionModel.id}...`);
		loader.onAbort = () => done(null);

		const doExtract = async () => {
			const auth = await ctx.modelRegistry.getApiKeyAndHeaders(extractionModel);
			if (auth.ok === false) {
				throw new Error(auth.error);
			}
			const userMessage: UserMessage = {
				role: "user",
				content: [{ type: "text", text: buildExtractionInput(text, contextText) }],
				timestamp: Date.now(),
			};

			const response = await complete(
				extractionModel,
				{ systemPrompt: SYSTEM_PROMPT, messages: [userMessage] },
				{ apiKey: auth.apiKey, headers: auth.headers, signal: loader.signal },
			);

			if (response.stopReason === "aborted") {
				return null;
			}

			const responseText = response.content
				.filter((c): c is { type: "text"; text: string } => c.type === "text")
				.map((c) => c.text)
				.join("\n");

			return preferMarkdownQuestionList(text, parseExtractionResult(responseText));
		};

		doExtract()
			.then(done)
			.catch(() => done(null));

		return loader;
	});
}

function formatMetadataLines(metadata: string[] | undefined, prefix = "- "): string[] {
	return (metadata ?? []).map((item) => `${prefix}${item}`);
}

function shouldAutoCollectAnswers(text: string): boolean {
	const questionCount = text.match(/\?/g)?.length ?? 0;
	if (questionCount < 2) {
		return false;
	}

	const hasDecisionHeading = /(?:remaining things to decide|things to decide|open questions|questions to answer|decisions to make|clarifying questions)/i.test(text);
	const hasNumberedQuestions = /(?:^|\n)\s*\d+[.)]\s+[^\n?]+\?/m.test(text);
	const hasRecommendation = /\bmy recommendation\b/i.test(text);

	return hasDecisionHeading || (hasNumberedQuestions && hasRecommendation) || questionCount >= 3 && hasNumberedQuestions;
}

function getAssistantMessageText(message: unknown): string | undefined {
	if (!message || typeof message !== "object") {
		return undefined;
	}
	const raw = message as { role?: unknown; stopReason?: unknown; content?: unknown };
	if (raw.role !== "assistant" || raw.stopReason !== "stop" || !Array.isArray(raw.content)) {
		return undefined;
	}

	const text = raw.content
		.filter((item): item is { type: "text"; text: string } => {
			return Boolean(item && typeof item === "object" && (item as { type?: unknown }).type === "text" && typeof (item as { text?: unknown }).text === "string");
		})
		.map((item) => item.text)
		.join("\n")
		.trim();

	return text.length > 0 ? text : undefined;
}

function stripListMarker(line: string): string | undefined {
	return line.trim().replace(/^(?:[-*+]\s+|\d+[.)]\s+)/, "").trim() || undefined;
}

function splitChoiceText(value: string): string[] | undefined {
	const cleaned = value
		.replace(/[?。！？]+$/u, "")
		.replace(/\s+or\s+/gi, ", ")
		.replace(/\s+and\s+/gi, ", ");
	const choices = normalizeChoices(cleaned.split(","));
	return choices && choices.length >= 2 ? choices : undefined;
}

function extractInlineChoices(question: string): { question: string; choices?: string[]; multiSelect?: boolean } {
	const colonMatch = question.match(/^(.*?):\s*(.+)$/);
	if (colonMatch) {
		const choices = splitChoiceText(colonMatch[2]);
		if (choices) {
			const prompt = colonMatch[1].trim().replace(/[?。！？]+$/u, "");
			return {
				question: `${prompt}?`,
				choices,
				multiSelect: inferMultiSelect(question, undefined, choices.length > 2 ? choices.length : undefined),
			};
		}
	}

	const eitherMatch = question.match(/^(?:Should|Do|Does|Are|Is|Can|Could|Would)\s+.+?\s+(?:be|use|want|include|show|appear on)?\s*([^,?]+?),?\s+or\s+([^?]+?)\?$/i);
	if (eitherMatch) {
		const choices = normalizeChoices([eitherMatch[1], eitherMatch[2]]);
		if (choices && choices.length === 2) {
			return { question, choices, multiSelect: false };
		}
	}

	return { question };
}

function parseMarkdownQuestionList(text: string): ExtractedQuestion[] {
	const lines = text.split("\n");
	const questions: ExtractedQuestion[] = [];

	for (let index = 0; index < lines.length; index++) {
		const line = lines[index];
		const marker = line.match(/^(\s*)(?:[-*+]\s+|\d+[.)]\s+)/);
		if (!marker) continue;

		const indent = marker[1].length;
		const rawQuestion = stripListMarker(line);
		if (!rawQuestion) continue;

		const isQuestion = rawQuestion.includes("?") || rawQuestion.endsWith(":") || /^(what|which|should|how|do|does|are|is|can|could|would)\b/i.test(rawQuestion);
		if (!isQuestion) continue;

		const nestedChoices: string[] = [];
		let lookahead = index + 1;
		while (lookahead < lines.length) {
			const nestedLine = lines[lookahead];
			const nestedMarker = nestedLine.match(/^(\s*)(?:[-*+]\s+|\d+[.)]\s+)/);
			if (!nestedMarker || nestedMarker[1].length <= indent) break;
			const choice = stripListMarker(nestedLine);
			if (choice) nestedChoices.push(choice);
			lookahead++;
		}

		const baseQuestion = rawQuestion.endsWith(":") ? `${rawQuestion.slice(0, -1).trim()}?` : rawQuestion;
		const extracted = extractInlineChoices(baseQuestion);
		const choices = normalizeChoices(nestedChoices) ?? extracted.choices;
		const inferredLimits = choices ? inferSelectionLimits(rawQuestion, choices.length) : {};
		const multiSelect = choices
			? extracted.multiSelect ?? (inferMultiSelect(rawQuestion, inferredLimits.minSelections, inferredLimits.maxSelections) || /^which\b/i.test(rawQuestion))
			: undefined;

		questions.push({
			question: extracted.question,
			choices,
			multiSelect,
			minSelections: choices ? inferredLimits.minSelections : undefined,
			maxSelections: choices ? inferredLimits.maxSelections : undefined,
		});

		if (nestedChoices.length > 0) {
			index = lookahead - 1;
		}
	}

	return questions;
}

function preferMarkdownQuestionList(text: string, extracted: ExtractionResult | null): ExtractionResult | null {
	const markdownQuestions = parseMarkdownQuestionList(text);
	if (markdownQuestions.length < 2) {
		return extracted;
	}

	return {
		metadata: extracted?.metadata,
		questions: markdownQuestions.map((question, index) => {
			const extractedQuestion = extracted?.questions[index];
			return {
				...question,
				context: question.context ?? extractedQuestion?.context,
				metadata: mergeMetadata(question.metadata, extractedQuestion?.metadata),
			};
		}),
	};
}

function formatAnswers(details: AnswerCollectionDetails | QnAResult): string {
	const parts: string[] = [];
	if (details.metadata?.length) {
		parts.push("Metadata:");
		parts.push(...formatMetadataLines(details.metadata));
		parts.push("");
	}

	for (const item of details.answers) {
		parts.push(`Q: ${item.question}`);
		if (item.context) {
			parts.push(`> ${item.context}`);
		}
		if (item.metadata?.length) {
			parts.push("Metadata:");
			parts.push(...formatMetadataLines(item.metadata));
		}
		parts.push(`A: ${item.answer || "(no answer)"}`);
		parts.push("");
	}

	return parts.join("\n").trim();
}

/**
 * Interactive Q&A component for answering extracted questions.
 */
class QnAComponent implements Component {
	private readonly metadata?: string[];
	private questions: ExtractedQuestion[];
	private answers: string[];
	private selectedChoices: number[][];
	private choiceCursors: number[];
	private customAnswers: string[];
	private choiceTextMode: boolean[];
	private currentIndex: number = 0;
	private editor: Editor;
	private tui: TUI;
	private onDone: (result: QnAResult | null) => void;
	private showingConfirmation: boolean = false;
	private selectionWarning?: string;

	// Cache
	private cachedWidth?: number;
	private cachedLines?: string[];

	// Colors - using proper reset sequences
	private dim = (s: string) => `\x1b[2m${s}\x1b[0m`;
	private bold = (s: string) => `\x1b[1m${s}\x1b[0m`;
	private cyan = (s: string) => `\x1b[36m${s}\x1b[0m`;
	private green = (s: string) => `\x1b[32m${s}\x1b[0m`;
	private yellow = (s: string) => `\x1b[33m${s}\x1b[0m`;
	private gray = (s: string) => `\x1b[90m${s}\x1b[0m`;

	constructor(
		extractionResult: ExtractionResult,
		tui: TUI,
		onDone: (result: QnAResult | null) => void,
	) {
		this.metadata = extractionResult.metadata;
		this.questions = extractionResult.questions;
		this.answers = extractionResult.questions.map(() => "");
		this.selectedChoices = extractionResult.questions.map(() => []);
		this.choiceCursors = extractionResult.questions.map(() => 0);
		this.customAnswers = extractionResult.questions.map(() => "");
		this.choiceTextMode = extractionResult.questions.map(() => false);
		this.tui = tui;
		this.onDone = onDone;

		// Create a minimal theme for the editor
		const editorTheme: EditorTheme = {
			borderColor: this.dim,
			selectList: {
				selectedPrefix: this.cyan,
				selectedText: (s: string) => `\x1b[44m${s}\x1b[0m`,
				description: this.gray,
				scrollInfo: this.dim,
				noMatch: this.yellow,
			},
		};

		this.editor = new Editor(tui, editorTheme);
		// Disable the editor's built-in submit (which clears the editor)
		// We'll handle Enter ourselves to preserve the text
		this.editor.disableSubmit = true;
		this.editor.onChange = () => {
			this.invalidate();
			this.tui.requestRender();
		};
	}

	private saveCurrentAnswer(): void {
		if (this.isChoiceQuestion(this.questions[this.currentIndex]) && this.choiceTextMode[this.currentIndex]) {
			this.customAnswers[this.currentIndex] = this.editor.getText();
			return;
		}
		if (!this.isChoiceQuestion(this.questions[this.currentIndex])) {
			this.answers[this.currentIndex] = this.editor.getText();
		}
	}

	private isChoiceQuestion(question: ExtractedQuestion): boolean {
		return (question.choices?.length ?? 0) > 0;
	}

	private useCustomAnswer(): void {
		if (!this.isChoiceQuestion(this.questions[this.currentIndex])) return;
		this.selectedChoices[this.currentIndex] = [];
		this.choiceTextMode[this.currentIndex] = true;
		this.editor.setText(this.customAnswers[this.currentIndex] || "");
		this.selectionWarning = undefined;
		this.invalidate();
		this.tui.requestRender();
	}

	private useChoiceAnswer(): void {
		if (!this.isChoiceQuestion(this.questions[this.currentIndex])) return;
		this.customAnswers[this.currentIndex] = this.editor.getText();
		this.choiceTextMode[this.currentIndex] = false;
		this.editor.setText("");
		this.selectionWarning = undefined;
		this.invalidate();
		this.tui.requestRender();
	}

	private getSelectedChoiceLabels(index: number): string[] {
		const question = this.questions[index];
		return (this.selectedChoices[index] ?? [])
			.map((choiceIndex) => question.choices?.[choiceIndex])
			.filter((choice): choice is string => Boolean(choice));
	}

	private getAnswer(index: number): string {
		if (this.isChoiceQuestion(this.questions[index])) {
			const customAnswer = this.customAnswers[index]?.trim();
			if (this.choiceTextMode[index] || customAnswer) {
				return customAnswer || "(none)";
			}
			const selected = this.getSelectedChoiceLabels(index);
			return selected.length > 0 ? selected.join(", ") : "(no answer)";
		}
		return this.answers[index]?.trim() || "(no answer)";
	}

	private advanceOrConfirm(): void {
		this.saveCurrentAnswer();
		const question = this.questions[this.currentIndex];
		if (question.choices?.length && question.minSelections && !this.choiceTextMode[this.currentIndex]) {
			const selectedCount = this.getSelectedChoiceLabels(this.currentIndex).length;
			if (selectedCount < question.minSelections) {
				this.selectionWarning = `Select at least ${question.minSelections} option${question.minSelections === 1 ? "" : "s"}.`;
				this.invalidate();
				this.tui.requestRender();
				return;
			}
		}
		if (this.currentIndex < this.questions.length - 1) {
			this.navigateTo(this.currentIndex + 1);
		} else {
			this.showingConfirmation = true;
			this.invalidate();
		}
		this.tui.requestRender();
	}

	private toggleChoice(choiceIndex: number): void {
		const question = this.questions[this.currentIndex];
		if (!question.choices?.[choiceIndex]) return;

		this.choiceCursors[this.currentIndex] = choiceIndex;
		this.selectionWarning = undefined;
		const selected = this.selectedChoices[this.currentIndex] ?? [];
		const existingIndex = selected.indexOf(choiceIndex);

		if (!question.multiSelect) {
			this.selectedChoices[this.currentIndex] = [choiceIndex];
			this.invalidate();
			return;
		}

		if (existingIndex >= 0) {
			selected.splice(existingIndex, 1);
		} else if (!question.maxSelections || selected.length < question.maxSelections) {
			selected.push(choiceIndex);
			selected.sort((a, b) => a - b);
		}
		this.selectedChoices[this.currentIndex] = selected;
		this.invalidate();
	}

	private handleChoiceInput(data: string): boolean {
		const question = this.questions[this.currentIndex];
		const choices = question.choices;
		if (!choices?.length) {
			return false;
		}
		if (this.choiceTextMode[this.currentIndex]) {
			return false;
		}
		if (data.toLowerCase() === "o") {
			this.useCustomAnswer();
			return true;
		}
		if (data.toLowerCase() === "n") {
			this.selectedChoices[this.currentIndex] = [];
			this.customAnswers[this.currentIndex] = "none";
			this.choiceTextMode[this.currentIndex] = true;
			this.editor.setText("none");
			this.selectionWarning = undefined;
			this.invalidate();
			this.tui.requestRender();
			return true;
		}

		const customChoiceIndex = choices.length;
		let cursor = this.choiceCursors[this.currentIndex] ?? 0;
		if (matchesKey(data, Key.up)) {
			this.choiceCursors[this.currentIndex] = Math.max(0, cursor - 1);
			this.invalidate();
			this.tui.requestRender();
			return true;
		}
		if (matchesKey(data, Key.down)) {
			this.choiceCursors[this.currentIndex] = Math.min(customChoiceIndex, cursor + 1);
			this.invalidate();
			this.tui.requestRender();
			return true;
		}
		if (matchesKey(data, Key.space)) {
			if (cursor === customChoiceIndex) {
				this.useCustomAnswer();
			} else {
				this.toggleChoice(cursor);
				this.tui.requestRender();
			}
			return true;
		}
		if (matchesKey(data, Key.enter) && !matchesKey(data, Key.shift("enter"))) {
			if (cursor === customChoiceIndex) {
				this.useCustomAnswer();
				return true;
			}
			if (!question.multiSelect && this.selectedChoices[this.currentIndex]?.length === 0) {
				this.toggleChoice(cursor);
			}
			this.advanceOrConfirm();
			return true;
		}

		const quickSelect = data >= "1" && data <= "9" ? Number.parseInt(data, 10) - 1 : data === "0" ? 9 : -1;
		if (quickSelect >= 0 && quickSelect < choices.length) {
			this.toggleChoice(quickSelect);
			this.tui.requestRender();
			return true;
		}

		return true;
	}

	private navigateTo(index: number): void {
		if (index < 0 || index >= this.questions.length) return;
		this.saveCurrentAnswer();
		this.currentIndex = index;
		this.selectionWarning = undefined;
		this.editor.setText(
			this.isChoiceQuestion(this.questions[index])
				? this.choiceTextMode[index]
					? this.customAnswers[index] || ""
					: ""
				: this.answers[index] || "",
		);
		this.invalidate();
	}

	private submit(): void {
		this.saveCurrentAnswer();

		this.onDone({
			metadata: this.metadata,
			answers: this.questions.map((question, index) => {
				const selectedChoices = this.isChoiceQuestion(question) ? this.getSelectedChoiceLabels(index) : undefined;
				return {
					...question,
					answer: this.getAnswer(index),
					...(selectedChoices?.length ? { selectedChoices } : {}),
				};
			}),
		});
	}

	private cancel(): void {
		this.onDone(null);
	}

	invalidate(): void {
		this.cachedWidth = undefined;
		this.cachedLines = undefined;
	}

	handleInput(data: string): void {
		// Handle confirmation dialog
		if (this.showingConfirmation) {
			if (matchesKey(data, Key.enter) || data.toLowerCase() === "y") {
				this.submit();
				return;
			}
			if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c")) || data.toLowerCase() === "n") {
				this.showingConfirmation = false;
				this.invalidate();
				this.tui.requestRender();
				return;
			}
			return;
		}

		if (
			this.isChoiceQuestion(this.questions[this.currentIndex]) &&
			this.choiceTextMode[this.currentIndex] &&
			matchesKey(data, Key.escape)
		) {
			this.useChoiceAnswer();
			return;
		}

		// Global navigation and commands
		if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.cancel();
			return;
		}

		// Tab / Shift+Tab for navigation
		if (matchesKey(data, Key.tab)) {
			if (this.currentIndex < this.questions.length - 1) {
				this.navigateTo(this.currentIndex + 1);
				this.tui.requestRender();
			}
			return;
		}
		if (matchesKey(data, Key.shift("tab"))) {
			if (this.currentIndex > 0) {
				this.navigateTo(this.currentIndex - 1);
				this.tui.requestRender();
			}
			return;
		}

		if (this.handleChoiceInput(data)) {
			return;
		}

		// Arrow up/down for question navigation when editor is empty
		// (Editor handles its own cursor navigation when there's content)
		if (matchesKey(data, Key.up) && this.editor.getText() === "") {
			if (this.currentIndex > 0) {
				this.navigateTo(this.currentIndex - 1);
				this.tui.requestRender();
				return;
			}
		}
		if (matchesKey(data, Key.down) && this.editor.getText() === "") {
			if (this.currentIndex < this.questions.length - 1) {
				this.navigateTo(this.currentIndex + 1);
				this.tui.requestRender();
				return;
			}
		}

		// Handle Enter ourselves (editor's submit is disabled)
		// Plain Enter moves to next question or shows confirmation on last question
		// Shift+Enter adds a newline (handled by editor)
		if (matchesKey(data, Key.enter) && !matchesKey(data, Key.shift("enter"))) {
			this.advanceOrConfirm();
			return;
		}

		// Pass to editor
		this.editor.handleInput(data);
		this.invalidate();
		this.tui.requestRender();
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) {
			return this.cachedLines;
		}

		const lines: string[] = [];
		const boxWidth = Math.min(width - 4, 120); // Allow wider box
		const contentWidth = boxWidth - 4; // 2 chars padding on each side

		// Helper to create horizontal lines (dim the whole thing at once)
		const horizontalLine = (count: number) => "─".repeat(count);

		// Helper to create a box line
		const boxLine = (content: string, leftPad: number = 2): string => {
			const paddedContent = " ".repeat(leftPad) + content;
			const contentLen = visibleWidth(paddedContent);
			const rightPad = Math.max(0, boxWidth - contentLen - 2);
			return this.dim("│") + paddedContent + " ".repeat(rightPad) + this.dim("│");
		};

		const emptyBoxLine = (): string => {
			return this.dim("│") + " ".repeat(boxWidth - 2) + this.dim("│");
		};

		const padToWidth = (line: string): string => {
			const len = visibleWidth(line);
			return line + " ".repeat(Math.max(0, width - len));
		};

		// Title
		lines.push(padToWidth(this.dim("╭" + horizontalLine(boxWidth - 2) + "╮")));
		const title = `${this.bold(this.cyan("Questions"))} ${this.dim(`(${this.currentIndex + 1}/${this.questions.length})`)}`;
		lines.push(padToWidth(boxLine(title)));
		lines.push(padToWidth(this.dim("├" + horizontalLine(boxWidth - 2) + "┤")));

		if (this.metadata?.length) {
			const metadataTitle = this.gray("Shared context:");
			lines.push(padToWidth(boxLine(metadataTitle)));
			for (const item of this.metadata) {
				const wrapped = wrapTextWithAnsi(this.gray(`• ${item}`), contentWidth - 2);
				for (const line of wrapped) {
					lines.push(padToWidth(boxLine(line)));
				}
			}
			lines.push(padToWidth(this.dim("├" + horizontalLine(boxWidth - 2) + "┤")));
		}

		// Progress indicator
		const progressParts: string[] = [];
		for (let i = 0; i < this.questions.length; i++) {
			const answered = this.isChoiceQuestion(this.questions[i])
				? this.getSelectedChoiceLabels(i).length > 0 || (this.customAnswers[i]?.trim() || "").length > 0
				: (this.answers[i]?.trim() || "").length > 0;
			const current = i === this.currentIndex;
			if (current) {
				progressParts.push(this.cyan("●"));
			} else if (answered) {
				progressParts.push(this.green("●"));
			} else {
				progressParts.push(this.dim("○"));
			}
		}
		lines.push(padToWidth(boxLine(progressParts.join(" "))));
		lines.push(padToWidth(emptyBoxLine()));

		// Current question
		const q = this.questions[this.currentIndex];
		const questionText = `${this.bold("Q:")} ${q.question}`;
		const wrappedQuestion = wrapTextWithAnsi(questionText, contentWidth);
		for (const line of wrappedQuestion) {
			lines.push(padToWidth(boxLine(line)));
		}

		// Context if present
		if (q.context) {
			lines.push(padToWidth(emptyBoxLine()));
			const contextText = this.gray(`> ${q.context}`);
			const wrappedContext = wrapTextWithAnsi(contextText, contentWidth - 2);
			for (const line of wrappedContext) {
				lines.push(padToWidth(boxLine(line)));
			}
		}

		// Metadata if present
		if (q.metadata?.length) {
			lines.push(padToWidth(emptyBoxLine()));
			lines.push(padToWidth(boxLine(this.gray("Question context:"))));
			for (const item of q.metadata) {
				const wrapped = wrapTextWithAnsi(this.gray(`• ${item}`), contentWidth - 2);
				for (const line of wrapped) {
					lines.push(padToWidth(boxLine(line)));
				}
			}
		}

		lines.push(padToWidth(emptyBoxLine()));

		if (q.choices?.length) {
			if (this.choiceTextMode[this.currentIndex]) {
				const answerPrefix = this.bold("A: ") + this.dim("Custom answer ");
				const editorWidth = contentWidth - 4 - visibleWidth("A: Custom answer ");
				const editorLines = this.editor.render(Math.max(20, editorWidth));
				for (let i = 1; i < editorLines.length - 1; i++) {
					lines.push(padToWidth(boxLine((i === 1 ? answerPrefix : " ".repeat(17)) + editorLines[i])));
				}
			} else {
				const selected = this.selectedChoices[this.currentIndex] ?? [];
				const cursor = this.choiceCursors[this.currentIndex] ?? 0;
				const mode = q.multiSelect ? "Select one or more" : "Select one";
				const limit = q.multiSelect && q.maxSelections ? ` (max ${q.maxSelections})` : "";
				lines.push(padToWidth(boxLine(this.bold("A: ") + this.dim(`${mode}${limit}`))));
				for (let choiceIndex = 0; choiceIndex < q.choices.length; choiceIndex++) {
					const choice = q.choices[choiceIndex] ?? "";
					const isSelected = selected.includes(choiceIndex);
					const isCursor = choiceIndex === cursor;
					const marker = q.multiSelect ? (isSelected ? this.green("☑") : "☐") : isSelected ? this.green("●") : "○";
					const quickKey = choiceIndex < 9 ? String(choiceIndex + 1) : choiceIndex === 9 ? "0" : " ";
					const prefix = `${isCursor ? this.cyan("›") : " "} ${marker} ${quickKey}. `;
					const wrapped = wrapTextWithAnsi(prefix + choice, contentWidth - 2);
					for (const line of wrapped) {
						lines.push(padToWidth(boxLine(line)));
					}
				}
				const customCursor = cursor === q.choices.length;
				const customText = this.customAnswers[this.currentIndex]?.trim();
				const customLabel = customText ? `Other: ${customText}` : "Other / none / custom answer";
				const customPrefix = `${customCursor ? this.cyan("›") : " "} ${customText ? this.green("✎") : "✎"}    `;
				for (const line of wrapTextWithAnsi(customPrefix + customLabel, contentWidth - 2)) {
					lines.push(padToWidth(boxLine(line)));
				}
				if (this.selectionWarning) {
					lines.push(padToWidth(boxLine(this.yellow(this.selectionWarning))));
				}
			}
		} else {
			// Render the editor component (multi-line input) with padding
			// Skip the first and last lines (editor's own border lines)
			const answerPrefix = this.bold("A: ");
			const editorWidth = contentWidth - 4 - 3; // Extra padding + space for "A: "
			const editorLines = this.editor.render(editorWidth);
			for (let i = 1; i < editorLines.length - 1; i++) {
				if (i === 1) {
					// First content line gets the "A: " prefix
					lines.push(padToWidth(boxLine(answerPrefix + editorLines[i])));
				} else {
					// Subsequent lines get padding to align with the first line
					lines.push(padToWidth(boxLine("   " + editorLines[i])));
				}
			}
		}

		lines.push(padToWidth(emptyBoxLine()));

		// Confirmation dialog or footer with controls
		if (this.showingConfirmation) {
			lines.push(padToWidth(this.dim("├" + horizontalLine(boxWidth - 2) + "┤")));
			const confirmMsg = `${this.yellow("Submit all answers?")} ${this.dim("(Enter/y to confirm, Esc/n to cancel)")}`;
			lines.push(padToWidth(boxLine(truncateToWidth(confirmMsg, contentWidth))));
		} else {
			lines.push(padToWidth(this.dim("├" + horizontalLine(boxWidth - 2) + "┤")));
			const controls = q.choices?.length
				? this.choiceTextMode[this.currentIndex]
					? `${this.dim("Enter")} next · ${this.dim("Shift+Enter")} newline · ${this.dim("Esc")} back to choices · ${this.dim("Ctrl+C")} cancel`
					: `${this.dim("↑/↓")} move · ${this.dim("Space/1-0")} select · ${this.dim("Other line")} custom · ${this.dim("Enter")} next`
				: `${this.dim("Tab/Enter")} next · ${this.dim("Shift+Tab")} prev · ${this.dim("Shift+Enter")} newline · ${this.dim("Esc")} cancel`;
			lines.push(padToWidth(boxLine(truncateToWidth(controls, contentWidth))));
		}
		lines.push(padToWidth(this.dim("╰" + horizontalLine(boxWidth - 2) + "╯")));

		this.cachedWidth = width;
		this.cachedLines = lines;
		return lines;
	}
}

async function runQnA(ctx: ExtensionContext, extractionResult: ExtractionResult): Promise<QnAResult | null> {
	return ctx.ui.custom<QnAResult | null>((tui, _theme, _kb, done) => {
		return new QnAComponent(extractionResult, tui, done);
	});
}

async function resolveToolExtraction(
	ctx: ExtensionContext,
	params: AnswerToolParamsType,
	signal?: AbortSignal,
): Promise<{ result?: ExtractionResult; source: AnswerCollectionDetails["source"]; error?: string }> {
	const explicitQuestions = normalizeQuestions(params.questions);
	if (explicitQuestions.length > 0) {
		return {
			source: "explicit",
			result: {
				metadata: normalizeMetadata(params.batchMetadata),
				questions: explicitQuestions,
			},
		};
	}

	const sourceText = params.sourceText?.trim();
	if (sourceText) {
		if (!ctx.model) {
			return { source: "sourceText", error: "No model selected for question extraction." };
		}
		const extracted = await extractQuestionsFromText(ctx, sourceText, signal, getRecentConversationContext(ctx, sourceText));
		return {
			source: "sourceText",
			result: extracted
				? { ...extracted, metadata: mergeMetadata(normalizeMetadata(params.batchMetadata), extracted.metadata) }
				: undefined,
		};
	}

	const lastAssistant = getLastAssistantText(ctx);
	if (!lastAssistant.ok) {
		return { source: "lastAssistant", error: lastAssistant.message };
	}
	if (!ctx.model) {
		return { source: "lastAssistant", error: "No model selected for question extraction." };
	}

	const extracted = await extractQuestionsFromText(ctx, lastAssistant.text, signal, getRecentConversationContext(ctx, lastAssistant.text));
	return {
		source: "lastAssistant",
		result: extracted
			? { ...extracted, metadata: mergeMetadata(normalizeMetadata(params.batchMetadata), extracted.metadata) }
			: undefined,
	};
}

function buildToolError(message: string, source: AnswerCollectionDetails["source"] = "explicit") {
	const details: AnswerCollectionDetails = {
		source,
		answers: [],
		error: message,
	};
	return {
		content: [{ type: "text" as const, text: `Error: ${message}` }],
		details,
		isError: true,
	};
}

export default function (pi: ExtensionAPI) {
	let autoAnswerInProgress = false;

	const collectAndSendAnswers = async (
		ctx: ExtensionContext,
		extractionResult: ExtractionResult,
		source: AnswerCollectionDetails["source"],
	): Promise<boolean> => {
		const answersResult = await runQnA(ctx, extractionResult);

		if (answersResult === null) {
			ctx.ui.notify("Cancelled", "info");
			return false;
		}

		const details: AnswerCollectionDetails = {
			...answersResult,
			source,
		};

		// Send the answers directly as a message and trigger a turn.
		pi.sendMessage(
			{
				customType: "answers",
				content: "I answered your questions in the following way:\n\n" + formatAnswers(details),
				details,
				display: true,
			},
			{ triggerTurn: true },
		);
		return true;
	};

	const answerHandler = async (ctx: ExtensionContext) => {
		if (!ctx.hasUI) {
			ctx.ui.notify("answer requires interactive mode", "error");
			return;
		}

		if (!ctx.model) {
			ctx.ui.notify("No model selected", "error");
			return;
		}

		const lastAssistant = getLastAssistantText(ctx);
		if (!lastAssistant.ok) {
			ctx.ui.notify(lastAssistant.message, "error");
			return;
		}

		const extractionResult = await extractQuestionsWithLoader(ctx, lastAssistant.text, getRecentConversationContext(ctx, lastAssistant.text));

		if (extractionResult === null) {
			ctx.ui.notify("Cancelled", "info");
			return;
		}

		if (extractionResult.questions.length === 0) {
			ctx.ui.notify("No questions found in the last message", "info");
			return;
		}

		await collectAndSendAnswers(ctx, extractionResult, "lastAssistant");
	};

	pi.on("message_end", async (event, ctx) => {
		if (autoAnswerInProgress || !ctx.hasUI || ctx.mode !== "tui" || !ctx.model) {
			return;
		}

		const text = getAssistantMessageText(event.message);
		if (!text || !shouldAutoCollectAnswers(text)) {
			return;
		}

		autoAnswerInProgress = true;
		try {
			const extractionResult = await extractQuestionsWithLoader(ctx, text, getRecentConversationContext(ctx, text));
			if (!extractionResult || extractionResult.questions.length === 0) {
				return;
			}
			await collectAndSendAnswers(ctx, extractionResult, "lastAssistant");
		} finally {
			autoAnswerInProgress = false;
		}
	});

	pi.registerTool({
		name: "answer",
		label: "Answer Questions",
		description:
			"Ask the user one or more questions in an interactive Q&A UI and return their answers. Supports explicit questions or extracting questions from sourceText/the last completed assistant message.",
		promptSnippet:
			"Ask the user clarifying questions in an interactive Q&A UI and return structured answers with helpful contextual metadata",
		promptGuidelines: [
			"Use answer when you need user input to proceed; prefer calling answer over ending your response with a plain list of questions.",
			"When using answer, prefer explicit questions and include short metadata notes for constraints or context already known from the conversation.",
			"Use choices for finite option prompts, and set multiSelect when the user may choose more than one option.",
			"Use answer with sourceText, or with no arguments as a last-assistant-message fallback, only when you need to extract questions from prose.",
		],
		parameters: AnswerToolParams,

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			if (!ctx.hasUI || ctx.mode !== "tui") {
				return buildToolError("answer requires interactive TUI mode; UI is not available in this session.");
			}

			let resolved: Awaited<ReturnType<typeof resolveToolExtraction>>;
			try {
				resolved = await resolveToolExtraction(ctx, params as AnswerToolParamsType, signal);
			} catch (error) {
				return buildToolError(error instanceof Error ? error.message : String(error));
			}

			if (resolved.error) {
				return buildToolError(resolved.error, resolved.source);
			}

			if (!resolved.result) {
				return buildToolError("Question extraction was cancelled or failed.", resolved.source);
			}

			if (resolved.result.questions.length === 0) {
				return buildToolError("No questions found to ask.", resolved.source);
			}

			const answersResult = await runQnA(ctx, resolved.result);
			if (answersResult === null) {
				const details: AnswerCollectionDetails = {
					metadata: resolved.result.metadata,
					answers: [],
					source: resolved.source,
					cancelled: true,
				};
				return {
					content: [{ type: "text" as const, text: "User cancelled answer collection." }],
					details,
				};
			}

			const details: AnswerCollectionDetails = {
				...answersResult,
				source: resolved.source,
			};
			return {
				content: [{ type: "text" as const, text: formatAnswers(details) }],
				details,
			};
		},

		renderCall(args, theme) {
			const params = args as AnswerToolParamsType;
			const questionCount = Array.isArray(params.questions) ? params.questions.length : 0;
			const mode = questionCount > 0 ? `${questionCount} explicit question${questionCount === 1 ? "" : "s"}` : params.sourceText ? "extract from sourceText" : "extract from last assistant";
			return new Text(theme.fg("toolTitle", theme.bold("answer ")) + theme.fg("muted", mode), 0, 0);
		},

		renderResult(result, _options, theme) {
			const details = result.details as AnswerCollectionDetails | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}

			if (details.error) {
				return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
			}
			if (details.cancelled) {
				return new Text(theme.fg("warning", "Cancelled"), 0, 0);
			}

			const lines = [
				theme.fg("success", `✓ Collected ${details.answers.length} answer${details.answers.length === 1 ? "" : "s"}`),
				...(details.metadata?.length ? [theme.fg("muted", `Context: ${details.metadata.join("; ")}`)] : []),
				...details.answers.map((item, index) => {
					const answer = item.answer.replace(/\s+/g, " ").trim();
					return theme.fg("muted", `${index + 1}. `) + theme.fg("text", item.question) + theme.fg("dim", ` → ${answer}`);
				}),
			];
			return new Text(lines.join("\n"), 0, 0);
		},
	});

	pi.registerCommand("answer", {
		description: "Extract questions from last assistant message into interactive Q&A",
		handler: (_args, ctx) => answerHandler(ctx),
	});

	pi.registerShortcut("ctrl+.", {
		description: "Extract and answer questions",
		handler: answerHandler,
	});
}
