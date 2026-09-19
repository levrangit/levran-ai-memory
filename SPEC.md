# Levran AI Memory — Specification

## Purpose

Provide ChatGPT with durable memory between sessions using the user's existing Enggraph installation as the persistent store.

ChatGPT remains the intelligent layer: it decides what information is important enough to remember, when a memory lookup is useful, and which project or scope a memory belongs to.

## Value Proposition

The app should let ChatGPT:
- automatically preserve durable user preferences, decisions, rules, agreements, constraints, architecture decisions, and other context likely to matter later;
- assign saved memories to the most appropriate project/scope based on the conversation context;
- retrieve previously stored context when the user explicitly asks for memory lookup.

Automatic saving does not require confirmation for every record.

## Memory scope / project classification

The "about" field is the memory scope.

ChatGPT should determine "about" from the current conversation context before calling save_memory.

Rules:
- If the memory clearly belongs to a named project, use that project's stable name as "about".
- Use the same project/scope spelling consistently across memories.
- If the conversation is clearly about Family Beacon, use "Family_beacon".
- If the conversation is clearly about Enggraph, use "enggraph".
- For other projects, use their project name when the context identifies one.
- For durable personal preferences, global rules, or information that intentionally applies across projects, use "about: *" when supported by Enggraph.
- If the correct project cannot be determined reliably, omit "about" rather than guessing. Enggraph will apply its normal default scope.
- Project classification must not be inferred from tags alone; the surrounding conversation context is authoritative.

The MCP tool description must explicitly tell ChatGPT to choose "about" from conversation context. The tool itself does not inspect the conversation and therefore must not pretend to perform this classification.

## Product Context

Existing Enggraph deployment:

https://levranio.duckdns.org/mcp/enggraph

The app must not modify Enggraph, Family Beacon, or existing infrastructure automatically.

No automatic deletion of memories.

## UX Flows

### Automatic memory save
1. Normal ChatGPT conversation.
2. ChatGPT identifies durable information important enough to remember.
3. ChatGPT determines the appropriate "about" scope from the conversation context.
4. ChatGPT calls save_memory, passing "about" when the scope is known.
5. Enggraph stores the memory.
6. Conversation continues normally.

### Explicit memory retrieval
1. User says: «посмотри через плагин памяти …».
2. ChatGPT identifies the topic and relevant project/scope from the conversation context.
3. ChatGPT calls search_memory.
4. Enggraph returns relevant memories.
5. ChatGPT uses the retrieved context in its answer.

## UI

The first version is tool-only. No custom React view is required.

## Tools

### save_memory

Input:
- memory_id
- title
- text
- optional summary
- optional tags
- optional about

Behavior:
- ChatGPT chooses "about" from the conversation context when a project/scope is identifiable.
- Forward the memory and selected scope to Enggraph's save_memory operation.
- Do not invent a project solely to avoid leaving "about" empty.

### search_memory

Input:
- query

Behavior: search Enggraph memory using get_memory and return relevant results to the model.

## Architecture

ChatGPT
   ↓
Levran AI Memory MCP App
   ↓
https://levranio.duckdns.org/mcp/enggraph
   ↓
Enggraph MCP
   ↓
PostgreSQL

## Safety

- Never modify Family Beacon without direct user permission.
- Never modify the existing Enggraph deployment without direct user permission.
- Never delete memories automatically.
- Keep secrets out of source control.
- Never guess a project scope when the conversation does not establish it reliably.

## Success Criteria

- The app starts locally.
- ChatGPT can invoke save_memory.
- ChatGPT can invoke search_memory.
- Memories persist in Enggraph between sessions.
- ChatGPT supplies the appropriate "about" scope for project-specific memories when the conversation identifies the project.
- Global memories can be explicitly stored with "about: *".
- The phrase «посмотри через плагин памяти …» can trigger retrieval.
- No per-record confirmation is required.
