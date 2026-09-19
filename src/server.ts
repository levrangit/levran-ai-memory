import { Skybridge } from "skybridge/server";
import { z } from "zod";

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
        async (input) => ({
          structuredContent: {
            status: "not_implemented",
            memory_id: input.memory_id,
          },
          content: [
            {
              type: "text",
              text: "Enggraph connection is the next implementation step.",
            },
          ],
        }),
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
        async (input) => ({
          structuredContent: {
            status: "not_implemented",
            query: input.query,
            memories: [],
          },
          content: [
            {
              type: "text",
              text: "Enggraph connection is the next implementation step.",
            },
          ],
        }),
      ),
});

export type AppType = typeof app;
