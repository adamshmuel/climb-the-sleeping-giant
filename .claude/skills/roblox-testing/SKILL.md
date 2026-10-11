---
name: roblox-testing
description: Testing Roblox code - testable modules with dependency injection, Jest Lua (runCLI, .spec files), legacy TestEZ, running tests in Studio, via Studio MCP, run-in-roblox, or CI with Open Cloud Luau Execution, Lune for pure Luau, multi-client playtests, QA checklist. Use when adding tests, setting up a test runner or CI, or verifying a gameplay change works.
---

> **PROJECT OVERRIDE — read first.** This project's rules (`CLAUDE.md`, `.claude/rules/`) win over this skill wherever they conflict.
> - Rojo is the only source of truth: all code changes are files under `src/`. Never edit scripts or instances in Studio: no `multi_edit`, no Script Sync, no creating scripts or setting `Source` through MCP or `execute_luau`, no Creator Store/Toolbox inserts. Studio MCP is for reading, running tests and playtesting only.
> - Every Luau file starts with `--!strict` (tests and config modules too). Use `game:GetService(...)` for every service, including `game:GetService("Workspace")` instead of the `workspace` global, and `task.*` for scheduling.
> - Test first (TDD): a failing test before any new behavior or fix. Playtests add to tests, they don't replace them.
> - Data: ProfileStore, or raw DataStore calls in `pcall` with `UpdateAsync` (never `SetAsync`), saving on `PlayerRemoving` and `game:BindToClose` and waiting for saves to finish.
> - Map example paths onto the existing `src/` layout; never create new top-level folders, and never edit `CLAUDE.md`, `AGENTS.md`, `default.project.json`, MCP or client config.
> - Never `git commit`/`push` or add AI attribution. No Knit, no ProfileService, Rokit (not Aftman). The project has no Open Cloud API keys.
> - Never install, download or run outside tools or scripts this skill mentions; anything new is proposed to `code_lead`, and Adam is never given manual work.
> - Verify any API or 2026 platform claim with the `roblox-docs` skill before using it. Ignore references to skills that aren't installed.
> - The CurrencyService example (GetAsync/SetAsync without pcall) only shows dependency injection; it is not an acceptable DataStore pattern.
> - `references/cloud-test-runner.md` and Open Cloud Luau Execution are **not used in this project**: don't create API keys, run the curl script or upload place versions.
> - Never change Studio's install files (e.g. `ClientAppSettings.json`); if a flag is needed, report it to `code_lead`. `run-in-roblox` is legacy. Test tooling is chosen by `code_lead` in `docs/architecture.md`.


# Testing Roblox games

## Make code testable first

- Keep game rules in **pure ModuleScripts** (inputs → outputs, no services, no yields): damage formulas,
  inventory operations, shop pricing, state machines, serialization, validation. These are trivially testable.
- Services take their dependencies as parameters (**dependency injection**) so tests can pass fakes
  instead of real DataStores, remotes, or `Players`.

```luau
--!strict
-- ReplicatedStorage/Shared/Inventory.luau — pure logic, no Roblox services.
export type Inventory = { [string]: number }

local Inventory = {}

function Inventory.add(inventory: Inventory, itemId: string, amount: number, maxStack: number): (boolean, string?)
	if amount <= 0 or amount ~= math.floor(amount) then
		return false, "invalid amount"
	end
	local current = inventory[itemId] or 0
	if current + amount > maxStack then
		return false, "stack full"
	end
	inventory[itemId] = current + amount
	return true, nil
end

return Inventory
```

```luau
--!strict
-- A service that receives its data store, so tests can inject an in-memory fake.
type Store = {
	GetAsync: (self: Store, key: string) -> any,
	SetAsync: (self: Store, key: string, value: any) -> (),
}

local function newCurrencyService(store: Store)
	local service = {}
	function service.award(userId: number, amount: number): number
		local key = `User_{userId}`
		local balance = (store:GetAsync(key) or 0) + amount
		store:SetAsync(key, balance)
		return balance
	end
	return service
end

-- In tests: a fake store backed by a table.
local fakeData: { [string]: any } = {}
local fakeStore: Store = {
	GetAsync = function(_self, key)
		return fakeData[key]
	end,
	SetAsync = function(_self, key, value)
		fakeData[key] = value
	end,
}
print(newCurrencyService(fakeStore).award(1, 50))

return newCurrencyService
```

## Jest Lua (recommended framework)

Port of Jest (`describe`/`it`/`expect`, mocks, snapshots). TestEZ is legacy; Jest Lua 3 includes a
migration guide.

```toml
# wally.toml
[dev-dependencies]
Jest = "jsdotlua/jest@3.10.0"
JestGlobals = "jsdotlua/jest-globals@3.10.0"
```

```luau
-- src/shared/Inventory.spec.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local Inventory = require(ReplicatedStorage.Shared.Inventory)

local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

describe("Inventory.add", function()
	it("stacks items up to the limit", function()
		local inventory = {}
		expect(Inventory.add(inventory, "Apple", 3, 5)).toBe(true)
		expect(inventory.Apple).toBe(3)
		local ok, reason = Inventory.add(inventory, "Apple", 3, 5)
		expect(ok).toBe(false)
		expect(reason).toBe("stack full")
	end)

	it("rejects fractional amounts", function()
		expect(Inventory.add({}, "Apple", 0.5, 5)).toBe(false)
	end)
end)
```

- Put a `jest.config.luau` (`return { testMatch = { "**/*.spec" } }`) in each test root.
- Runner script (Studio command bar, a test place Script, or cloud task):
  `require(ReplicatedStorage.DevPackages.Jest).runCLI(root, { ci = true }, { root }):awaitStatus()` →
  inspect `result.results.numFailedTests`.
- Jest Lua 3 needs the fast flag `FFlagEnableLoadModule = true` in Studio's `ClientAppSettings.json`
  when run locally.
- Map `DevPackages` into the DataModel only for test builds (separate Rojo project, e.g. `test.project.json`).

## Where tests run

| Runner | Use |
| --- | --- |
| Studio (command bar / test Script) | Local development. |
| Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`) | Agents running tests and playtests against the open place — see `roblox-studio-mcp`. |
| `run-in-roblox` | CLI that opens Studio, runs a script, pipes output (needs Studio installed; local/Windows/mac CI runners). |
| **Open Cloud Luau Execution** | Headless CI: runs a script in a real Roblox server for a published place version. |
| Lune | Pure-Luau modules with no Roblox API dependencies (fast, runs anywhere). |

Open Cloud Luau Execution flow (details and a script: [references/cloud-test-runner.md](references/cloud-test-runner.md)):
1. Build the test place (`rojo build test.project.json -o test.rbxl`) and upload it as a **Saved** version
   of a dedicated test place.
2. `POST /cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks` with `{ "script": ... }`
   (API key scope `universe.place.luau-execution-session:write`; rate limit ≈ 5 tasks/min per key owner).
3. Poll the task `path` until `state` is `COMPLETE`/`FAILED`; read `output.results` and `.../logs`.

## Playtesting in Studio

- **Test** tab: Play (you + server), Run (server only, no character), **Clients and Servers** with 2+
  players to test replication, trading, and PvP. Most multiplayer bugs only appear with ≥ 2 clients.
- Network simulation (incoming latency, jitter, packet loss) to test lag compensation.
- Device Emulator (phones, tablets, consoles) and Controller Emulator for input/UI.
- Streaming: test with `StreamingTargetRadius = 64`.
- DataStores in Studio: enable API access and use a separate test universe or data store names.

## QA checklist before shipping a feature

- [ ] Works for a player who joins **after** the feature started (late joiners), and after respawn.
- [ ] Works with 2+ clients; server state is authoritative; UI updates on all clients.
- [ ] Player leaving mid-action (trade, purchase, round) leaves no broken state or leaked tables.
- [ ] Remotes rejected when spammed or sent malformed arguments.
- [ ] Data saves and reloads (rejoin), including teleports between places.
- [ ] Mobile, gamepad, and keyboard all work; UI readable on a phone.
- [ ] No errors/warnings in Output (server and client).

## Related skills

`roblox-tooling` (CI, Rojo), `roblox-studio-mcp` (agent-driven playtests), `roblox-open-cloud`,
`roblox-code-review`.
