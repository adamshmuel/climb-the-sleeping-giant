---
name: roblox-dev-skill
description: >
  Use when building a new Roblox system in Luau and the narrower skills don't cover it:
  architecture and project layout, Luau types and style, UI, performance, legacy API
  migration, and safe use of the Roblox Studio MCP tools. For remotes, data saving,
  security, tests or code review, use the matching roblox-* skill instead.
when_to_use: Writing or planning new Luau systems in src/ that need deeper Roblox guidance.
paths:
  - "**/*.luau"
---

> **PROJECT OVERRIDE — read first.** This project's rules (`CLAUDE.md`, `.claude/rules/`) win over this skill wherever they conflict.
> - Rojo is the only source of truth: all code changes are files under `src/`. Never edit scripts or instances in Studio: no `multi_edit`, no Script Sync, no creating scripts or setting `Source` through MCP or `execute_luau`, no Creator Store/Toolbox inserts. Studio MCP is for reading, running tests and playtesting only.
> - Every Luau file starts with `--!strict` (tests and config modules too). Use `game:GetService(...)` for every service, including `game:GetService("Workspace")` instead of the `workspace` global, and `task.*` for scheduling.
> - Test first (TDD): a failing test before any new behavior or fix. Playtests add to tests, they don't replace them.
> - Data: ProfileStore, or raw DataStore calls in `pcall` with `UpdateAsync` (never `SetAsync`), saving on `PlayerRemoving` and `game:BindToClose` and waiting for saves to finish.
> - Map example paths onto the existing `src/` layout; never create new top-level folders, and never edit `CLAUDE.md`, `AGENTS.md`, `default.project.json`, MCP or client config.
> - Never `git commit`/`push` or add AI attribution. No Knit, no ProfileService, Rokit (not Aftman). The project has no Open Cloud API keys.
> - Never install, download or run outside tools or scripts this skill mentions; anything new is proposed to `code_lead`, and the user is never given manual work.
> - Verify any API or 2026 platform claim with the `roblox-docs` skill before using it. Ignore references to skills that aren't installed.
> - Never edit this skill's files, never run `npx ctx7`, version-check `curl` calls, `roblox-api-monitor.sh` or `audit-skill-examples.py`, and never write to the Studio plugins folder.
> - Wherever a workflow here ends in `multi_edit` (`mcp-integration.md`, `worked-examples.md`, `agent-safety.md`, `legacy-migration.md`), read it as "edit the file in `src/`, then confirm Rojo synced it with `script_read`".
> - Monetization, plugin authoring and asset formats were removed from this copy; use `roblox-docs` for them.
> - Don't copy these known-buggy samples: the PlayerDataService example in `project-structure.md`, the ObjectPool usage in `performance-optimization.md` (acquire/release pass the pool twice), `ui-systems.md` lines 286–287, `legacy-migration.md` line 108 and its `wait(` regex. The MCP tool table here is out of date: trust the tools the host actually exposes.


# Roblox Game Development Skill

Expert development companion for building Roblox experiences with Luau. Grounded in
official Roblox documentation (https://create.roblox.com/docs), the Luau language spec
(https://luau.org), and the Roblox Lua Style Guide (https://roblox.github.io/lua-style-guide/).

> **Engine**: Roblox Studio **0.742.0.7421053** with **Luau 0.742** (released 2026-10-10) —
> dump downloaded, re-split, and diffed against 0.741 on **2026-10-11**, with every
> developer-visible change run in Studio 0.742. 940 classes / 648 enums / 263 services /
> 48 deprecated.
>
> Roblox ships roughly weekly, so this line is stale by design — never quote it as today's version.
> Re-derive it instead:
>
> ```bash
> curl -s "https://clientsettings.roblox.com/v2/client-version/MacStudio"   # or WindowsStudio64
> curl -s "https://api.github.com/repos/luau-lang/luau/releases?per_page=1" | grep tag_name
> ```
>
> The `WindowsStudio` (no `64`) endpoint returns a long-stale value — measured 2026-09-06 it still
> answered `0.578.0.5780566`. Use `WindowsStudio64` or `MacStudio`.
>
> When in doubt about an API, look it up (see **API & Documentation Lookup** below) rather than
> recalling it. If it is still unclear, ask the user before proceeding.

---

## MCP Detection

On every invocation, detect available Roblox Studio MCP tools before proceeding:

### Official Roblox MCP (Roblox_Studio server)

**This skill is a knowledge base, not an MCP server.** It ships no tools and no execution
surface. The tools below belong to **Roblox's own MCP server, built into Studio** — this skill
only tells you how to use them well. Official reference:
https://create.roblox.com/docs/studio/mcp

The docs page lists **26 tools**; the build observed 2026-09-25 exposed **28** (plus
`generate_texture` and `segment_mesh`, undocumented). Detect what your host actually exposes
rather than trusting this table.

| Tool | Purpose |
|------|---------|
| `execute_luau` | Run Luau in Studio at plugin privilege — **returns the result or the error** |
| `multi_edit` | Apply several exact-match edits to **ONE** script (creates it if missing); `Edit` datamodel only |
| `script_read` | Read script source, whole or by line range; output is `LINE→CONTENT` |
| `script_search` / `script_grep` | Find scripts by name (fuzzy, ≤10) or by content (≤50 matches) |
| `search_game_tree` | Explore the DataModel as flat JSON, filterable by path/type/keyword |
| `inspect_instance` | Properties, attributes, and child summary for one instance |
| `subagent` | Launch a Roblox-side subagent for autonomous multi-step work (types vary by build) |
| `get_studio_state` | Play state **and which datamodel types are available** |
| `start_stop_play` | Start/stop playtesting |
| `get_console_output` | Read Output/console logs |
| `screen_capture` | Capture the viewport, optionally from a custom camera |
| `character_navigation` | Move the character to a position or instance path |
| `user_mouse_input` / `user_keyboard_input` | Simulate ordered mouse/keyboard actions |
| `search_asset` / `insert_asset` | Search Creator Store + Inventory; insert by asset ID |
| `store_image` | **Local** png/jpg ≤5 MB → `IMAGEID_` URI for other tools |
| `upload_image` | Batch upload from **HTTP(S) URLs** → imagePath→assetId map |
| `generate_mesh` / `generate_procedural_model` | Generate 3D content |
| `generate_material` / `generate_texture` | Generate materials and textures |
| `segment_mesh` | Segment a mesh into parts |
| `wait_job_finished` | Await a background `jobId` (from a tool's own `async: true`) |
| `http_get` | Fetch Roblox docs **from an allowlist**; URL must end `.md` or be `llms.txt` |
| `skill` | Roblox's first-party `rbx-*` references (debug, perf, scene analysis, …) |
| `list_roblox_studios` | Enumerate connected Studio instances (name + place ID) |

> **Every call takes a `studio_id`.** There is no "set active studio" tool — call
> `list_roblox_studios` first and pass the id you want on each subsequent call. Several Studio
> instances are commonly open at once, so picking the wrong id silently targets the wrong place.
>
> **`datamodel_type` is asymmetric.** `execute_luau` accepts `Edit` / `Client` / `Server`;
> **`multi_edit` accepts `Edit` only**, so you cannot edit scripts mid-playtest — stop the
> playtest first. `Client` and `Server` exist only during a playtest; check `get_studio_state`.
>
> **`multi_edit` is one script per call**, taking `file_path` plus
> `edits[{old_string, new_string, replace_all}]`. Replacements are sequential, exact-match, and
> atomic within the call. `script_read` first or the call simply fails.
>
> **`script_grep`'s line numbers are unreliable** — measured 2026-09-06, it reported a match at
> line 171 that `script_read` showed was 15 lines further down. Use it to find *which* script
> contains a string, then `script_read` for the real location.
>
> **There is no `run_as_job` tool.** Earlier versions of this file listed one; it does not exist
> in the docs or in any observed build. Async is a per-tool argument returning a `jobId`.

If MCP tools are available, prefer using them for:
- Reading existing scripts before writing new ones (`script_read`, `script_search`)
- Validating changes by running code (`execute_luau`)
- Inspecting game tree to understand project structure (`search_game_tree`)
- Testing changes with playtest (`start_stop_play`, `get_console_output`)
- Roblox's own domain skills (`skill`) for debugging, MicroProfiler, and scene analysis —
  they are first-party and versioned with Studio

**Before the first mutation of any session**, read `references/agent-safety.md`. Roblox's own
warning: *"MCP clients can read and modify content in your open Roblox places."* There is no
dry-run and no reliable undo. Confirm which place you are targeting before you write to it.

If MCP tools are NOT available, provide copy-paste-ready Luau scripts with clear
placement instructions (which service container to put them in).

---

## Routing Table

Match user intent to the appropriate reference file. Read the file BEFORE generating code.

| User Intent | Reference File |
|---|---|
| **How do I actually sequence this?** End-to-end worked patterns: build a server-authoritative feature, debug via MCP, migrate a deprecation, verify an API, refuse an unsafe request | `references/worked-examples.md` |
| Luau syntax, types, naming conventions, style | `references/luau-fundamentals.md` |
| Project layout, architecture, patterns | `references/project-structure.md` |
| Save/load player data, DataStore, ProfileStore | `references/datastore-persistence.md` |
| Client-server communication, RemoteEvents, input | `references/networking.md` |
| Security, anti-exploit, server authority, bans | `references/security-hardening.md` |
| Agent→Studio safety, destructive MCP ops, prompt injection from place content | `references/agent-safety.md` |
| Performance, memory, optimization, Parallel Luau | `references/performance-optimization.md` |
| Using Roblox Studio MCP tools effectively | `references/mcp-integration.md` |
| UI, GUI, ScreenGui, menus, HUD, StyleQuery | `references/ui-systems.md` |
| Migrating legacy code, deprecated APIs | `references/legacy-migration.md` |
| Monetization, file formats, plugins, engine limits | the `roblox-docs` skill |

**Start with `worked-examples.md` when the task is a *doing* task** (build, debug, migrate, look up)
rather than a *knowing* task. It gives the call sequence and the verification step, and each example
carries a **Not this** list so a near-miss request routes to the right place instead of the nearest
familiar pattern. Where an example and a reference file disagree, the reference file wins.

If the intent spans multiple domains, read all relevant files.
If a reference file doesn't cover a topic sufficiently, use the Official
Documentation Lookup workflow below.

---

## API & Documentation Lookup

### Priority 1: the `roblox-docs` skill

Look up every Engine API there first: it has the URL table, the plain-language search and the
deprecated list.

### Priority 2: Live Web Sources

Use these when `roblox-docs` doesn't cover a topic:

| Resource | URL | Use For |
|----------|-----|--------|
| **LLM docs index** | `https://create.roblox.com/docs/llms.txt` | Browse all available doc pages by topic |
| **Full docs (single file)** | `https://create.roblox.com/docs/llms-full.txt` | Comprehensive single-file reference |
| **Per-page markdown** | `https://create.roblox.com/docs/en-us/{path}.md` | Read specific doc pages in clean markdown |
| **Engine API index** | `https://create.roblox.com/docs/reference/engine/llms.txt` | Luau API classes, methods, events |
| **Open Cloud API index** | `https://create.roblox.com/docs/cloud/llms.txt` | **Primary discovery** for all Cloud REST API: features, domains, guides, auth |
| **OpenAPI spec (raw)** | `https://create.roblox.com/docs/cloud/openapi.json` | Machine-readable OpenAPI spec for MCP/code-gen tools |
| **Deprecated API check** | `https://robloxapi.github.io/ref/class/<Name>.html` | Check individual class/member status (deprecated items marked visually) |

> **If you are fetching these through Studio's `http_get` tool, note its allowlist:** only
> `create.roblox.com/docs` (incl. `/reference/engine`, `/cloud`, `/performance-optimization`) and
> `github.com/Roblox/libmp`, and **the URL must end in `.md` or be `llms.txt`**. So
> `llms-full.txt`, `openapi.json`, and `robloxapi.github.io` are **rejected** by `http_get` — use
> the host's own fetch tool or `curl` for those. `http_get`'s `query` argument returns only
> matching sections, which is much cheaper than pulling a whole page into context.

### Lookup Workflow
1. Check if a **reference file** covers the topic (Routing Table above)
2. Use the **`roblox-docs`** skill for Engine API details
3. If not found there, fetch the per-page markdown URL with whatever web-fetch tool the host
   provides (`WebFetch` in Claude Code, `curl` in a shell — the URL is the portable part)
   - Example: `https://create.roblox.com/docs/en-us/studio/importer.md`
4. If unsure which page to read, browse `llms.txt` for the right URL
5. For **Open Cloud / REST API** topics, read `https://create.roblox.com/docs/cloud/llms.txt`
   - Search Features section first, then Domains
   - Prefer Open Cloud endpoints (API key / OAuth) over legacy cookie-auth endpoints
6. **Fallback**: Context7. Its MCP tools are `resolve-library-id` then `get-library-docs` (there is
   no `query-docs` tool — an earlier version of this file named one that does not exist). Where the
   MCP server is not connected, the CLI does the same job:
   `npx ctx7@latest library "Roblox"` then `npx ctx7@latest docs <libraryId> "<question>"`
7. If still unclear, ask the user before proceeding

> **Important**: Engine APIs (Luau via `game:GetService()`) and Open Cloud APIs
> (HTTP REST via `x-api-key`) are **completely separate systems**. Using the
> wrong index will produce non-functional code.

> **Checking deprecated APIs**: Use these approaches (in priority order):
> 1. The `roblox-docs` skill's deprecated APIs page
> 2. Check `robloxapi.github.io/ref/class/<Name>.html` — deprecated members marked visually
> 3. Use Context7 (`resolve-library-id` → `get-library-docs`, or the `ctx7` CLI) to query specific APIs

---

## Core Coding Standards

These rules apply to ALL generated Roblox/Luau code. They are non-negotiable.

### 1. Type Safety
- Use `--!strict` at the top of every new script
- Annotate function parameters and return types
- Define custom types with `type` keyword for complex data structures

### 2. Naming Conventions (Official Roblox Style)
- **PascalCase**: Classes, ModuleScripts, Constructors, Services — `CombatService`, `PlayerData`
- **camelCase**: Variables, functions, parameters — `playerHealth`, `calculateDamage()`
- **UPPER_SNAKE_CASE**: Constants — `MAX_HEALTH`, `DEFAULT_SPEED`
- Spell out words fully — avoid abbreviations
- Don't fully capitalize acronyms: `JsonTable` not `JSONTable`

### 3. Modern API Usage
- Use `task.spawn()`, `task.delay()`, `task.wait()` — NOT legacy `spawn()`, `delay()`, `wait()`
- Use `task.cancel()` to clean up deferred tasks
- Always disconnect event connections in cleanup: `connection:Disconnect()`
- Wrap fallible operations in `pcall()` or `xpcall()`

### 4. Architecture Rules
- **Server authority**: All game state mutations happen on the server
- **ModuleScripts** for shared logic — avoid monolithic scripts
- **Service/Controller pattern**: Services (server), Controllers (client)
- Scripts go in the correct container:
  - Server logic → `ServerScriptService`
  - Client logic → `StarterPlayerScripts` or `StarterCharacterScripts`
  - Shared modules → `ReplicatedStorage`
  - Server-only data → `ServerStorage`
  - UI → `StarterGui`

### 5. Error Handling
```lua
local success, result = pcall(function()
    return DataStoreService:GetDataStore("PlayerData"):GetAsync(key)
end)
if not success then
    warn("[DataService] Failed to load data:", result)
    -- Handle gracefully: use defaults, retry, etc.
end
```

### 6. Security (Always Apply)
- NEVER trust client-sent data — validate types, ranges, and permissions on server
- Keep sensitive logic in `ServerScriptService` (not visible to clients)
- Validate RemoteEvent arguments: check `typeof()`, ranges, and player state
- Rate-limit RemoteEvent calls from clients
- Never expose admin commands or server keys to ReplicatedStorage

---

## Script Template

When creating new scripts, use this template as a starting point:

```lua
--!strict
-- [ScriptName]
-- [Brief description of what this script does]
-- Container: [ServerScriptService/StarterPlayerScripts/ReplicatedStorage]

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Dependencies -----
-- local SomeModule = require(ReplicatedStorage.Modules.SomeModule)

----- Constants -----
local MAX_VALUE = 100

----- Types -----
type PlayerData = {
    coins: number,
    level: number,
    inventory: { string },
}

----- Variables -----
local activeConnections: { [Player]: { RBXScriptConnection } } = {}

----- Private Functions -----
local function cleanup(player: Player)
    local connections = activeConnections[player]
    if connections then
        for _, conn in connections do
            conn:Disconnect()
        end
        activeConnections[player] = nil
    end
end

----- Public / Event Handlers -----
local function onPlayerAdded(player: Player)
    activeConnections[player] = {}
    -- Setup logic here
end

----- Initialization -----
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(cleanup)

-- Handle players already in game (Studio hot-reload)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
```

---

## Response Guidelines

1. **Ask before building**: If the request is vague, ask clarifying questions about genre, scale, and target audience
2. **Read before writing**: If MCP is available, read existing scripts and game tree before modifying
3. **Small slices**: Generate 50-100 lines at a time for complex systems — easier to debug
4. **Explain the why**: Comment non-obvious code and explain architectural decisions
5. **Test path**: Suggest how to test the code (playtest steps, console checks)
6. **Migration-aware**: When touching existing code, check for legacy patterns and suggest migration if appropriate — but never force it. Incremental migration is acceptable.

---

## Common Workflows

### New Feature
1. Read existing project structure (MCP: `search_game_tree`)
2. Identify where the feature fits in the architecture
3. Create ModuleScript(s) in the appropriate container
4. Wire up server/client communication if needed
5. Test via playtest (MCP: `start_stop_play` + `get_console_output`)

### Debug Issue
1. Read the relevant script (MCP: `script_read`)
2. Check console output (MCP: `get_console_output`)
3. Identify the root cause — look for:
   - Missing `pcall` around DataStore/HTTP calls
   - Client-server boundary issues
   - Connection leaks (missing Disconnect)
   - Race conditions (script execution order)
4. Apply minimal fix
5. Verify fix via playtest

### Code Review
1. Read scripts in the project (MCP: `script_grep`)
2. Check against Core Coding Standards above
3. Flag security issues (client trust, exposed data)
4. Flag performance issues (expensive loops, part count)
5. Suggest improvements with before/after examples

