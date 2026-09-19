import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const ENGGRAPH_MCP_URL =
  process.env.ENGGRAPH_MCP_URL ??
  "https://levranio.duckdns.org/mcp/enggraph";

let clientPromise: Promise<Client> | undefined;

async function connect(): Promise<Client> {
  const client = new Client({
    name: "levran-ai-memory",
    version: "0.1.0",
  });

  const transport = new StreamableHTTPClientTransport(
    new URL(ENGGRAPH_MCP_URL),
  );

  await client.connect(transport);
  return client;
}

export function getEnggraphClient(): Promise<Client> {
  if (!clientPromise) {
    clientPromise = connect().catch((error) => {
      clientPromise = undefined;
      throw error;
    });
  }

  return clientPromise;
}

export async function callEnggraphTool(
  name: string,
  args: Record<string, unknown>,
) {
  const client = await getEnggraphClient();
  return client.callTool({
    name,
    arguments: args,
  });
}
