# Levran AI Memory — Specification

## Purpose

Provide ChatGPT with durable project and user context between sessions using the user's existing Enggraph installation as the persistent store.

ChatGPT is the intelligent layer. It decides what is worth preserving, classifies durable information as Memory / Plan / Suggestion, determines the project scope, and constructs the record. levran-ai-memory is a validation, routing, and storage gateway; it does not inspect conversation semantics.

## Native Enggraph record model

Enggraph already provides three agent-authored persistent record families:

- **Memory** — durable knowledge such as facts, rules, preferences, constraints, agreements, and decisions.
- **Plan** — future work, templates, and procedures. Plan type is one of `plan`, `template`, `procedure`; lifecycle status is separate.
- **Suggestion** — an observed gap, defect, missing capability, or possible improvement. Supported suggestion kinds are `empty-lookup`, `missing-summary`, `thin-summary`, `not-indexed`, `no-parser`, `stale-index`, `missing-tool`; supported levers are `tokens`, `coverage`, `runtime`.

levran-ai-memory must not create a competing taxonomy.

## Tool contract: save_record

`save_record` is the single write interface exposed to ChatGPT.

Common required fields:

- `record_type`: exactly `memory`, `plan`, or `suggestion`;
- `about`: stable project/scope name, or `*` for global personal/cross-project information;
- `id`: lowercase slug using letters, digits, hyphens, and underscores;
- `title`;
- `content`;
- `tags`: array of semantic retrieval tags; an empty array is valid.

Plan-only fields:

- `plan_type`: `plan`, `template`, or `procedure`;
- `plan_status`: lifecycle status, normally `active` for new plans.

Suggestion-only fields:

- `suggestion_kind`: optional supported Enggraph kind;
- `lever`: optional supported Enggraph lever;
- `suggestion_status`: `open`, `resolved`, or `wontfix`; defaults to `open`.

The gateway validates the record and routes it to the corresponding Enggraph operation:

- memory → `save_memory`
- plan → `save_plan`
- suggestion → `save_suggestion`

The gateway must not reinterpret a record or silently invent missing semantic values.

## When ChatGPT should save

Save only information with durable value beyond the current turn.

Save Memory for permanent rules, durable preferences, constraints, agreements, important facts, accepted architectural decisions, and stable project conventions.

Save Plan for concrete future work, execution roadmaps, reusable templates, and procedures.

Save Suggestion for discovered gaps, defects, missing capabilities, technical debt, risks, and possible improvements that are not yet accepted decisions or plans.

Do not save routine conversation, transient debugging output, temporary actions, one-off requests, or statements with no durable future value.

One conversation statement normally produces at most one record. Do not create multiple records merely because one sentence contains several related ideas.

## Ambiguity rule

If ChatGPT cannot confidently distinguish Memory / Plan / Suggestion and the user has not explicitly selected the type, do not call `save_record`.

If the user explicitly says remember this, save as a plan, or record this as a suggestion, follow that instruction.

If `about` cannot be determined reliably, do not call `save_record`.

## About classification

ChatGPT determines `about` from the surrounding conversation context.

Examples: Family Beacon → `Family_beacon`; Enggraph → `enggraph`; levran-ai-memory → `levran-ai-memory`; durable personal or cross-project information → `*`.

Tags must never be used to infer `about`.

## Tags

Use 2-5 short semantic tags when they materially improve retrieval. Do not invent tags merely to reach a count. Empty tags are valid.

## Tool contract: get_session_context

`get_session_context` is read-only and loads the native Enggraph context needed at the beginning of meaningful project work.

Input:

- `about`: stable project/scope name;
- `limit`: optional per-family limit from 1 to 20, default 20.

Output:

```json
{
  "status": "ok",
  "about": "enggraph",
  "memories": [],
  "plans": [],
  "suggestions": []
}
```

The tool retrieves Memory records for the scope, active Plans for the scope, and open Suggestions for the scope.

ChatGPT should call it at the beginning of a meaningful work session when persistent context could affect the work. It should not be called for trivial conversation.

## Explicit memory lookup

When the user explicitly asks to look through the memory plugin, for example «посмотри через плагин памяти ...», ChatGPT should use `search_memory` with the relevant query and `about` when the scope is known.

ChatGPT must not claim to remember persistent information that was not retrieved or is not present in the current conversation.

## Architecture

ChatGPT
   ↓
levran-ai-memory MCP app
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
- Never guess a project scope.
- Never invent an Enggraph suggestion kind or lever.
- Never silently convert an ambiguous record into another record type.

## Success Criteria

- ChatGPT can call `save_record` for all three native record families.
- ChatGPT can call `get_session_context` and receive Memory + active Plans + open Suggestions.
- ChatGPT can explicitly retrieve memories with `search_memory`.
- Records persist in Enggraph between sessions.
- The model does the semantic classification; the gateway only validates and routes.
- Ambiguous records are not silently saved under the wrong type.