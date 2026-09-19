import { Skybridge } from "skybridge/server";
import { z } from "zod";
import { callEnggraphTool } from "./enggraph.js";

export const app = new Skybridge({
  name: "levran-ai-memory",
  version: "0.1.0",
  instructions: [
    "Persistent memory for ChatGPT backed by Enggraph.",
    "Decide yourself when durable information is important enough to save.",
    "Use save_memory for durable information.",
    "Use search_memory when the user explicitly asks to look through the memory plugin.",
  ].join("\n"),
  handler: (server) =>
    server
      .registerTool(
        {
          name: "save_memory",
          description:
            "Save durable information to the user's persistent Enggraph memory.",
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

            return {
              structuredContent: {
                status: "saved",
                memory_id: input.memory_id,
                result,
              },
              content: [
                {
                  type: "text",
                  text: `Memory saved to Enggraph: ${input.memory_id}`,
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
                error: message,
              },
              content: [
                {
                  type: "text",
                  text: `Failed to save memory to Enggraph: ${message}`,
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
            "Search the user's persistent Enggraph memory for information relevant to the requested topic.",
          inputSchema: {
            query: z.string().min(1),
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
            });

            return {
              structuredContent: {
                status: "ok",
                query: input.query,
                result,
              },
              content: [
                {
                  type: "text",
                  text: `Memory search completed for: ${input.query}`,
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
                error: message,
              },
              content: [
                {
                  type: "text",
                  text: `Failed to search Enggraph memory: ${message}`,
                },
              ],
              isError: true,
            };
          }
        },
      ),
});

export type AppType = typeof app;
