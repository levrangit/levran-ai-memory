# Levran AI Memory

Skybridge MCP App for persistent ChatGPT memory backed by the remote Enggraph instance.

## Development

Requires Node.js 24+.

```bash
npm install
npm run dev
```

The local MCP endpoint is exposed by Skybridge at `/mcp`.

## Remote Enggraph

The app will connect to:

`https://levranio.duckdns.org/mcp/enggraph`

The first version is tool-only and does not expose a custom UI.
