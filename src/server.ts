import { Skybridge } from "skybridge/server";
import { z } from "zod";
import { callEnggraphTool } from "./enggraph.js";

export const app = new Skybridge({
  name: "levran-ai-memory",
  version: "0.1.0",
  instructions: [
    "Persistent memory for ChatGPT backed by Enggraph.",
    "Decide yourself when durable information is important enough to save.",
    "When saving a memory, determine its about scope from the current conversation context.",
    "For project-specific memories, pass the stable project name in about.",
    "Use about=Family_beacon for Family Beacon context and about=enggraph for Enggraph context.",
    "For durable personal or cross-project information, use about=* when appropriate.",
    "If the project cannot be determined reliably, omit about instead of guessing.",
    "Do not infer project scope from tags alone; use the surrounding conversation context.",
    "Use save_memory for durable information.",
    "Use search_memory when the user explicitly asks to look through the memory plugin.",
    "When searching, pass about when the current conversation clearly identifies a relevant project or scope.",
  ].join("\n"),
  handler: (server) =>
    server
      .registerTool(
        {
          name: "save_memory",
          description:
            "Save durable information to the user's persistent Enggraph memory. IMPORTANT: ChatGPT must determine the memory's about scope from the current conversation context. If the memory belongs to a known project, pass that project's stable name in about (for example, Family_beacon or enggraph). Use about=* for durable personal or cross-project information when appropriate. If the scope cannot be determined reliably, omit about rather than guessing.",
          inputSchema: {
            memory_id: z.string().min(1),
            title: z.string().min(1),
            text: z.string().min(1),
            summary: z.string().optional(),
            tags: z.array(z.string()).optional(),
            about: z.string().optional(),
          },
          annotations: {
            readOnlyHint: false,
            openWorldHint: true,
            destructiveHint: false,
          },
        },
        async (input) => {
          try {
            const result = await callEnggraphTool("save_memory", input);
            const scopeText = input.about ? " (about " + input.about + ")" : "";

            return {
              structuredContent: {
                status: "saved",
                memory_id: input.memory_id,
                about: input.about ?? null,
                result,
              },
              content: [
                {
                  type: "text",
                  text: "Memory saved to Enggraph: " + input.memory_id + scopeText,
                },
              ],
            };
          } catch (error) {
            const message =
              error instanceof Error ? error.message : String(error);

            return {
              structuredContent: {
                status: "error",
                memory_id: input.memory_id,
                about: input.about ?? null,
                error: message,
              },
              content: [
                {
                  type: "text",
                  text: "Failed to save memory to Enggraph: " + message,
                },
              ],
              isError: true,
            };
          }
        },
      )
      .registerTool(
        {
          name: "search_memory",
          description:
            "Search the user's persistent Enggraph memory for information relevant to the requested topic. If the current conversation clearly identifies a project or scope, pass it in about to focus the search. Omit about when the search should cover all scopes.",
          inputSchema: {
            query: z.string().min(1),
            about: z.string().optional(),
          },
          annotations: {
            readOnlyHint: true,
            openWorldHint: true,
            destructiveHint: false,
          },
        },
        async (input) => {
          try {
            const result = await callEnggraphTool("get_memory", {
              query: input.query,
              limit: 20,
              ...(input.about ? { about: input.about } : {}),
            });
            const scopeText = input.about ? " (about " + input.about + ")" : "";

            return {
              structuredContent: {
                status: "ok",
                query: input.query,
                about: input.about ?? null,
                result,
              },
              content: [
                {
                  type: "text",
                  text: "Memory search completed for: " + input.query + scopeText,
                },
              ],
            };
          } catch (error) {
            const message =
              error instanceof Error ? error.message : String(error);

            return {
              structuredContent: {
                status: "error",
                query: input.query,
                about: input.about ?? null,
                error: message,
              },
              content: [
                {
                  type: "text",
                  text: "Failed to search Enggraph memory: " + message,
                },
              ],
              isError: true,
            };
          }
        },
      ),
});

export type AppType = typeof app;
