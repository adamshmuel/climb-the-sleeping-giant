# MyRobloxGame

Roblox game built with Rojo. The code's source of truth is `src/` in git; Roblox Studio is driven through the Roblox Studio MCP.

## Layout (default.project.json)
- `src/shared` → `ReplicatedStorage.Shared` (ModuleScripts used by both sides)
- `src/server` → `ServerScriptService.Server` (`init.server.luau` = Script)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (`init.client.luau` = LocalScript)

Logic goes in ModuleScripts. `init.*.luau` files only require and wire things up, which keeps the logic unit-testable.

## Agents
Project agents live in `.claude/agents/`: `game_creator` (ideas, gameplay, business), `designer` (look and feel, mockups), `product` (specs, build reviews), `code_lead` (architecture, plans, code review, progress) and `builder` (code and tests). The main chat is the messenger between them and Adam. The flow, the approval gates and who owns what are in `.claude/rules/agent-workflow.md`.

## Source of truth
- Change code by editing files in `src/`. Never use MCP `multi_edit` on Rojo-synced scripts, because Rojo overwrites Studio edits on the next sync.
- Use the MCP for runtime and world work: `execute_luau` for building and inspecting non-synced instances (Workspace parts, maps, lighting), plus playtesting, console output and screenshots.
- Anything built in Studio that must persist lives in the place file (the user saves it) or gets exported into the Rojo tree. Say which one when you build something.

## Roblox Studio MCP
- Call `list_roblox_studios` first to get the `studio_id`.
- Deleting or replacing instances in Studio needs no confirmation from Adam when the change matches the spec, the gameplay and the game idea. If the owner of that topic (`product`, `game_creator` or `designer`) has approved it, go ahead. Ask Adam first only for the bigger changes listed in `agent-workflow.md`, "Asking Adam".
- Use the built-in MCP skills via the `skill` tool: `rbx-unit-test` for tests, `rbx-debug`, `rbx-perf-profiling`, `rbx-scene-analysis` and `rbx-device-simulator-lua` when relevant.

## Docs
Use the project `roblox-docs` skill before relying on memory for any Roblox API. Never guess API names or signatures.

## Dev loop
1. Edit `src/`. The PostToolUse hook runs StyLua and selene on `.luau` files, so fix any lint errors it reports.
2. Make sure `rojo serve` is running and the Studio plugin is connected. Start it in the background if it isn't running. Rojo only syncs in edit mode, and the plugin can disconnect after playtests (`[Rojo-Warn] Disconnected` in the console). Before trusting Studio, `script_read` a file you changed. If it's stale, ask the user to click Connect in the Rojo plugin.
3. `start_stop_play` → `get_console_output` → fix → stop play.

Tools are pinned in the Rokit manifest; run `rokit install` after cloning.

## Luau / Roblox rules
- Start every file with `--!strict`. Use `game:GetService(...)` and the `task.*` library (never `wait`, `spawn` or `delay`).
- Server-authoritative: the server validates every RemoteEvent/RemoteFunction argument (type, range, ownership, rate). Never trust client values for currency, damage or position.
- DataStores: wrap every call in `pcall`, prefer `UpdateAsync`, and save on `PlayerRemoving` and `game:BindToClose`.
- Disconnect connections and destroy instances you create. Don't leak them per player or per round.
