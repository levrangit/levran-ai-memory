# Levran AI Memory — Specification

## Purpose

Provide ChatGPT with durable memory between sessions using the user's existing Enggraph installation as the persistent store.

ChatGPT remains the intelligent layer: it decides what information is important enough to remember and when a memory lookup is useful.

## Value Proposition

The app should let ChatGPT:
- automatically preserve durable user preferences, decisions, rules, agreements, constraints, architecture decisions, and other context likely to matter later;
- retrieve previously stored context when the user explicitly asks for memory lookup.

Automatic saving does not require confirmation for every record.

## Product Context

Existing Enggraph deployment:

`https://levranio.duckdns.org/mcp/enggraph`

The app must not modify Enggraph, Family Beacon, or existing infrastructure automatically.

No automatic deletion of memories.

## UX Flows

### Automatic memory save
1. Normal ChatGPT conversation.
2. ChatGPT identifies durable information important enough to remember.
3. ChatGPT calls `save_memory`.
4. Enggraph stores the memory.
5. Conversation continues normally.

### Explicit memory retrieval
1. User says: «посмотри через плагин памяти …».
2. ChatGPT identifies the topic to search for.
3. ChatGPT calls `search_memory`.
4. Enggraph returns relevant memories.
5. ChatGPT uses the retrieved context in its answer.

## UI

The first version is tool-only. No custom React view is required.

## Tools

### save_memory
Input:
- `memory_id`
- `title`
- `text`
- optional `summary`
- optional `tags`
- optional `about`

Behavior: forward the memory to Enggraph's `save_memory` operation.

### search_memory
Input:
- `query`

Behavior: search Enggraph memory using `get_memory` and return relevant results to the model.

## Architecture

```
ChatGPT
   ↓
Levran AI Memory MCP App
   ↓
https://levranio.duckdns.org/mcp/enggraph
   ↓
Enggraph MCP
   ↓
PostgreSQL
```

## Safety

- Never modify Family Beacon without direct user permission.
- Never modify the existing Enggraph deployment without direct user permission.
- Never delete memories automatically.
- Keep secrets out of source control.

## Success Criteria

- The app starts locally.
- ChatGPT can invoke `save_memory`.
- ChatGPT can invoke `search_memory`.
- Memories persist in Enggraph between sessions.
- The phrase «посмотри через плагин памяти …» can trigger retrieval.
- No per-record confirmation is required.
