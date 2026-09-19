import { Skybridge } from "skybridge/server";
import { z } from "zod";
import { callEnggraphTool } from "./enggraph.js";

const memoryRecordSchema = z.object({
  record_type: z.literal("memory"),
  about: z.string().min(1),
  id: z.string().regex(/^[a-z0-9][a-z0-9_-]*$/),
  title: z.string().min(1),
  content: z.string().min(1),
  tags: z.array(z.string()),
});

const planRecordSchema = z.object({
  record_type: z.literal("plan"),
  about: z.string().min(1),
  id: z.string().regex(/^[a-z0-9][a-z0-9_-]*$/),
  title: z.string().min(1),
  content: z.string().min(1),
  tags: z.array(z.string()),
  plan_type: z.enum(["plan", "template", "procedure"]),
  plan_status: z.string().min(1),
});

const suggestionRecordSchema = z.object({
  record_type: z.literal("suggestion"),
  about: z.string().min(1),
  id: z.string().regex(/^[a-z0-9][a-z0-9_-]*$/),
  title: z.string().min(1),
  content: z.string().min(1),
  tags: z.array(z.string()),
  suggestion_kind: z.enum(["empty-lookup", "missing-summary", "thin-summary", "not-indexed", "no-parser", "stale-index", "missing-tool"]).optional(),
  lever: z.enum(["tokens", "coverage", "runtime"]).optional(),
  suggestion_status: z.enum(["open", "resolved", "wontfix"]).default("open"),
});

const saveRecordSchema = z.discriminatedUnion("record_type", [memoryRecordSchema, planRecordSchema, suggestionRecordSchema]);
const sessionContextSchema = z.object({
  about: z.string().min(1),
  limit: z.number().int().min(1).max(20).default(20),
});

function textContent(text: string) {
  return [{ type: "text" as const, text }];
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export const app = new Skybridge({
  name: "levran-ai-memory",
  version: "0.2.0",
  instructions: [
    "You are the intelligent layer. levran-ai-memory is only a storage and routing gateway; it does not understand the conversation.",
    "",
    "PERSISTENT MEMORY POLICY",
    "Save only information that has durable value beyond the current turn.",
    "Do not save routine conversation, temporary actions, transient debugging output, or ordinary discussion.",
    "Do not call save_record merely because a statement sounds important.",
    "When there is meaningful uncertainty about whether something should be persistent, prefer not to save it.",
    "",
    "CLASSIFY EVERY SAVED RECORD",
    "Before calling save_record, classify the information as exactly one of:",
    "Memory = durable fact, rule, preference, constraint, agreement, architectural decision, or other knowledge that should shape future work.",
    "Plan = future work, an execution roadmap, a reusable template, or a procedure.",
    "Suggestion = an observed gap, defect, missing capability, technical debt, risk, or possible improvement that has not yet become an accepted plan or decision.",
    "Do not invent another record type or taxonomy.",
    "",
    "WHEN TYPES ARE AMBIGUOUS",
    "Do not guess between Memory, Plan, and Suggestion.",
    "If the user explicitly selects a type, follow that instruction.",
    "If no explicit type is given and the distinction remains materially uncertain, do not call save_record.",
    "",
    "ABOUT / PROJECT SCOPE",
    "Determine about from the surrounding conversation context, not from tags.",
    "Use a stable project name when the conversation clearly belongs to a project, for example Family_beacon, enggraph, or levran-ai-memory.",
    "Use about=* for durable personal or cross-project information.",
    "Never invent a project name just to fill about.",
    "",
    "TAGS",
    "Choose 2-5 short semantic tags when useful. Tags are for retrieval and organization, not classification. Empty tags are allowed.",
    "",
    "SESSION START",
    "At the beginning of meaningful work on a project, call get_session_context with that project about value when persistent context could affect the work.",
    "Use its memories, active plans, and open suggestions as context before proceeding.",
    "",
    "EXPLICIT MEMORY LOOKUP",
    "When the user explicitly asks to look through the memory plugin, for example посмотри через плагин памяти ..., use search_memory with the relevant query and about when known.",
    "Do not claim to remember persistent information that was not retrieved or is not present in the current conversation.",
  ].join("\n"),
  handler: (server) =>
    server
      .registerTool({
        name: "save_record",
        description: "Save one already-classified durable record to Enggraph. ChatGPT must decide whether it is durable, choose exactly memory/plan/suggestion, determine about from conversation context, and construct the fields. This tool validates and routes the record; it does not infer meaning. If classification or scope is materially uncertain, do not call it.",
        inputSchema: {
          record_type: z.enum(["memory", "plan", "suggestion"]),
          about: z.string().min(1),
          id: z.string().regex(/^[a-z0-9][a-z0-9_-]*$/),
          title: z.string().min(1),
          content: z.string().min(1),
          tags: z.array(z.string()),
          plan_type: z.enum(["plan", "template", "procedure"]).optional(),
          plan_status: z.string().min(1).optional(),
          suggestion_kind: z.enum(["empty-lookup", "missing-summary", "thin-summary", "not-indexed", "no-parser", "stale-index", "missing-tool"]).optional(),
          lever: z.enum(["tokens", "coverage", "runtime"]).optional(),
          suggestion_status: z.enum(["open", "resolved", "wontfix"]).optional(),
        },
        annotations: { readOnlyHint: false, openWorldHint: true, destructiveHint: false },
      }, async (rawInput) => {
        try {
          const input = saveRecordSchema.parse(rawInput);
          if (input.record_type === "memory") {
            const result = await callEnggraphTool("save_memory", { memory_id: input.id, title: input.title, text: input.content, tags: input.tags, about: input.about });
            return { structuredContent: { status: "saved", record_type: input.record_type, id: input.id, about: input.about, result }, content: textContent("Memory saved: " + input.id + " (about " + input.about + ").") };
          }
          if (input.record_type === "plan") {
            const result = await callEnggraphTool("save_plan", { project: input.about, plan_id: input.id, title: input.title, content: input.content, status: input.plan_status, type: input.plan_type });
            return { structuredContent: { status: "saved", record_type: input.record_type, id: input.id, about: input.about, result }, content: textContent("Plan saved: " + input.id + " (about " + input.about + ").") };
          }
          const result = await callEnggraphTool("save_suggestion", { suggestion_id: input.id, title: input.title, detail: input.content, about: input.about, ...(input.suggestion_kind ? { kind: input.suggestion_kind } : {}), ...(input.lever ? { lever: input.lever } : {}), status: input.suggestion_status ?? "open" });
          return { structuredContent: { status: "saved", record_type: input.record_type, id: input.id, about: input.about, result }, content: textContent("Suggestion saved: " + input.id + " (about " + input.about + ").") };
        } catch (error) {
          const message = errorMessage(error);
          return { structuredContent: { status: "error", error: message }, content: textContent("Failed to save persistent record: " + message), isError: true };
        }
      })
      .registerTool({
        name: "get_session_context",
        description: "Load persistent project context for the beginning of meaningful work. ChatGPT supplies the stable about value. Returns Memory records, active Plans, and open Suggestions. Read-only; it never writes or deletes records.",
        inputSchema: { about: z.string().min(1), limit: z.number().int().min(1).max(20).default(20) },
        annotations: { readOnlyHint: true, openWorldHint: true, destructiveHint: false },
      }, async (rawInput) => {
        try {
          const input = sessionContextSchema.parse(rawInput);
          const [memories, plans, suggestions] = await Promise.all([
            callEnggraphTool("get_memory", { query: "*", limit: input.limit, about: input.about }),
            callEnggraphTool("get_plans", { project: input.about, status: "active", limit: input.limit }),
            callEnggraphTool("get_suggestions", { about: input.about, status: "open", limit: input.limit }),
          ]);
          return { structuredContent: { status: "ok", about: input.about, memories, plans, suggestions }, content: textContent("Session context loaded for " + input.about + ": memories, active plans, and open suggestions.") };
        } catch (error) {
          const message = errorMessage(error);
          return { structuredContent: { status: "error", error: message }, content: textContent("Failed to load session context: " + message), isError: true };
        }
      })
      .registerTool({
        name: "search_memory",
        description: "Search persistent Enggraph memory. Use this when the user explicitly asks to look through the memory plugin; pass about when the relevant project or scope is known.",
        inputSchema: { query: z.string().min(1), about: z.string().optional() },
        annotations: { readOnlyHint: true, openWorldHint: true, destructiveHint: false },
      }, async (input) => {
        try {
          const result = await callEnggraphTool("get_memory", { query: input.query, limit: 20, ...(input.about ? { about: input.about } : {}) });
          return { structuredContent: { status: "ok", query: input.query, about: input.about ?? null, result }, content: textContent("Memory search completed for: " + input.query + (input.about ? " (about " + input.about + ")" : "")) };
        } catch (error) {
          const message = errorMessage(error);
          return { structuredContent: { status: "error", query: input.query, about: input.about ?? null, error: message }, content: textContent("Failed to search Enggraph memory: " + message), isError: true };
        }
      }),
});

export type AppType = typeof app;