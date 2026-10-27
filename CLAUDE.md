# MyRobloxGame

**The goal: a game that can go viral.** Every look, feel and gameplay decision answers "Could it go viral looking and feeling like this?" and "Would a kid pick ours over the top game next to it?" (`.claude/rules/viral-goal.md`). This comes before every other rule.

Roblox game built with Rojo. The code's source of truth is `src/` in git; Roblox Studio is driven through the Roblox Studio MCP.

## Layout (default.project.json)
- `src/shared` → `ReplicatedStorage.Shared` (ModuleScripts used by both sides)
- `src/server` → `ServerScriptService.Server` (`init.server.luau` = Script)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (`init.client.luau` = LocalScript)
- `tools` → `ServerStorage.Tools` (world scripts; run by requiring a copy)

Logic goes in ModuleScripts. `init.*.luau` files only require and wire things up, which keeps the logic unit-testable.

## Agents
Project agents live in `.claude/agents/`: `game_creator` (ideas, gameplay, business), `designer` (look and feel, mockups), `product` (specs, build reviews), `code_lead` (architecture, plans, code review, progress) and `builder` (code and tests). The main chat is the messenger between them and Adam. The flow, the approval gates and who owns what are in `.claude/rules/agent-workflow.md`.

Agent definitions are generic, so they can be reused for other Roblox games. Facts about this game go in skills, rules and `docs/`, never in `.claude/agents/` (`.claude/rules/generic-agents.md`).

## Docs layout
Each version or large feature set is a folder, so an agent only reads what it needs and stays under its memory limit:
- `docs/specs/<version>/index.md`: a short map with one line per feature (its file, status and build order). Each feature has its own small spec, `docs/specs/<version>/<feature>.md`, with at most 15 rules.
- `docs/plans/<version>/index.md` plus `docs/plans/<version>/<feature>.md`: the same shape for build plans.
- `docs/design/<version>/`: the look for that version (look study, style guide, art list, build check, mockups). A later version holds only what it adds or changes. The earlier style guide still applies unless the new one replaces a part of it.
- Research and owner input for a version go in `docs/specs/<version>/research/`.
- An agent gets the index and only the feature files it works on, never the whole folder.
- V1 is partly older: its design is in `docs/design/v1/`, but its spec and plan are still `docs/specs/core-heist.md` and `docs/plans/core-heist.md`.

## Source of truth
- Change code by editing files in `src/`. Never use MCP `multi_edit` on Rojo-synced scripts, because Rojo overwrites Studio edits on the next sync.
- Use the MCP for runtime and world work: `execute_luau` for building and inspecting non-synced instances (Workspace parts, maps, lighting), plus playtesting, console output and screenshots.
- Anything built in Studio that must persist lives in the place file (the user saves it) or gets exported into the Rojo tree. Say which one when you build something.

## Roblox Studio MCP
- Call `list_roblox_studios` first to get the `studio_id`.
- Deleting or replacing instances in Studio needs no confirmation from Adam when the change matches the spec, the gameplay and the game idea. If the owner of that topic (`product`, `game_creator` or `designer`) has approved it, go ahead. Ask Adam first only for the bigger changes listed in `agent-workflow.md`, "Asking the user".
- Use the built-in MCP skills via the `skill` tool: `rbx-unit-test` for tests, `rbx-debug`, `rbx-perf-profiling`, `rbx-scene-analysis` and `rbx-device-simulator-lua` when relevant.

## Docs
Use the project `roblox-docs` skill before relying on memory for any Roblox API. Never guess API names or signatures.

## Dev loop
0. **Keep the Mac awake.** Before any Studio work, the main chat checks `pgrep -x caffeinate`. If nothing runs, it starts `caffeinate -d -i -u` in the background (only one copy). This stops the Mac and its screen from sleeping, so long Studio jobs, playtests and `screen_capture` don't fail. Stop it when the session's Studio work is done.
1. Edit `src/`. The PostToolUse hook runs StyLua and selene on `.luau` files, so fix any lint errors it reports.
2. Make sure this project's `rojo serve` is running and the Studio plugin is connected. Start it in the background if it isn't running. Rojo only syncs in edit mode, and the plugin can disconnect after playtests (`[Rojo-Warn] Disconnected` in the console). Before trusting Studio, `script_read` a file you changed. If it's stale, ask the user to click Connect in the Rojo plugin.
   - **Trial and harness scripts never go in `src/` or `tools/`.** Deleting a synced file crashes `rojo serve` (`NotFound` in `change_processor.rs`), which disconnects the plugin and needs the user to click Connect. Keep trial scripts in `work/` and paste them into Studio with `execute_luau` (build any temporary ModuleScripts there, and destroy them in the same call).
   - **Delete synced folders only with `scripts/rojo-safe-rm.sh <path>`.** `rojo serve` 7.7.1 crashes when a synced folder is removed or moved while it still has files, or right after its files change (tested 2026-10-27). The script deletes the files, waits, then removes the empty folders. Deleting a single file is safe. A PreToolUse hook (`.claude/hooks/rojo-safe-delete.py`) blocks `rm -r`, `rmdir` and `mv` on folders under `src/` and `tools/`.
   - **Port 34873, not Rojo's default 34872.** Another game on this Mac (Grab-It & Run!) serves on 34872. Connecting to it once copied that game's code into this place (2026-10-26). `servePort` in `default.project.json` sets 34873, and the plugin's port box must say 34873.
   - **Check before asking for Connect:** `curl -s localhost:34873/api/rojo | strings | grep -A1 projectName` must print `MyRobloxGame`. After connecting, Studio must not have `ServerScriptService.GameServer`, `ServerScriptService.GrabItModules` or `ReplicatedStorage.GrabIt`. If it does, disconnect, close the place without saving, and reopen the file.
3. `start_stop_play` → `get_console_output` → fix → stop play.

Tools are pinned in the Rokit manifest; run `rokit install` after cloning.

## Luau / Roblox rules
- Start every file with `--!strict`. Use `game:GetService(...)` and the `task.*` library (never `wait`, `spawn` or `delay`).
- Server-authoritative: the server validates every RemoteEvent/RemoteFunction argument (type, range, ownership, rate). Never trust client values for currency, damage or position.
- DataStores: wrap every call in `pcall`, prefer `UpdateAsync`, and save on `PlayerRemoving` and `game:BindToClose`.
- Disconnect connections and destroy instances you create. Don't leak them per player or per round.
