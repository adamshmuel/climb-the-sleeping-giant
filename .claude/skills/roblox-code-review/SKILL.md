---
name: roblox-code-review
description: Review Roblox/Luau code for exploits, data loss, memory leaks, performance problems, lifecycle bugs, policy issues, and deprecated or superseded APIs, using a severity-ranked checklist and the full 2026 deprecation map. Use when reviewing a PR or script, auditing a game before launch, modernizing legacy code, or asked what is wrong with some Roblox code.
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
> - Raise to **High**: any DataStore call outside `pcall`, read-modify-write not done with `UpdateAsync`, a missing `PlayerRemoving` or `BindToClose` save (ProfileStore handles these internally: don't flag correct ProfileStore use), any Studio-only change that bypasses Rojo, any file missing `--!strict`, connections never disconnected, player-keyed tables never cleared, and new behavior or fixes with no test that failed first.
> - Report findings only; never apply fixes yourself — the builder does, test first.
> - Verify `HasRobloxSubscription` / `PromptRobloxSubscriptionPurchase` (deprecated-apis.md) with `roblox-docs` before recommending them.


# Roblox code review

Review in severity order. Report each finding with **file:line, severity, what breaks, and the fix**.
Verify claims against the code (and the engine reference when unsure) — don't pattern-match blindly.

## Severity guide

| Severity | Examples |
| --- | --- |
| **Critical** | Client-authoritative rewards/damage/currency; unvalidated remote args (NaN, instance spoofing); purchases granted outside `ProcessReceipt` or non-idempotent; data saved with `SetAsync` from multiple servers without session locking; secrets/API keys in replicated code; unfiltered player text shown to others. |
| **High** | Data loss paths (no `BindToClose`, saving default data after a failed load, no retry); memory leaks (connections, player-keyed tables); `InvokeClient`; per-frame remotes; infinite yields (`WaitForChild` without timeout on optional instances, `RemoteFunction` handlers that can yield forever); streaming-unsafe client indexing. |
| **Medium** | Deprecated/superseded APIs; `wait`/`spawn`/`delay`; polling loops; server-side tweens; missing `pcall` on network/yielding APIs; missing late-joiner handling; race conditions on `CharacterAdded`. |
| **Low** | Style, naming, missing types, magic numbers, dead code, minor inefficiencies. |

## Checklist

**Security** (`roblox-security`)
- Every `OnServerEvent`/`OnServerInvoke`: types checked with `typeof`, numbers `math.isfinite`, strings
  length/UTF-8 checked, instances `IsA` + `IsDescendantOf(trusted)`, rate limited, context checked.
- No server-only logic, admin lists, or secrets in `ReplicatedStorage`/`StarterPlayer`/`Workspace`.
- `ProximityPrompt`/`ClickDetector`/`Touched` handlers re-validate distance/state on the server.
- Gameplay-critical unanchored parts are server-owned.

**Data** (`roblox-data-stores`)
- Session locking (ProfileStore or equivalent); `UpdateAsync` for read-modify-write; retries with backoff.
- `BindToClose` flushes saves in parallel; no saves of `Instance`/`Vector3`/mixed tables.
- Failed loads never overwritten with defaults; player-keyed tables cleared on leave.
- Keys stable (`User_{UserId}`), Studio uses a separate store/universe.

**Monetization** (`roblox-monetization`)
- Single `ProcessReceipt`; idempotent by `PurchaseId`; returns `PurchaseGranted` only after persisting.
- Pass perks checked on join **and** after in-session purchase; prices not hardcoded; paid random items
  disclose odds and respect `PolicyService`.

**Correctness & lifecycle** (`roblox-architecture`)
- Handles players already in game (`for _, p in Players:GetPlayers()`) and characters already spawned.
- Per-character state rebuilt on respawn; per-player state cleaned on `PlayerRemoving`.
- No yields at module top level; no circular requires; one owner per piece of state.
- Deferred-event safe (doesn't rely on handlers running synchronously).
- Client code streaming-safe (`WaitForChild`/nil checks for `Workspace` content).

**Performance** (`roblox-performance`)
- No per-frame `FindFirstChild`/`GetDescendants`/`Instance.new`; params objects reused.
- Event-driven instead of polling; think loops throttled and staggered.
- Tweens and cosmetic effects on clients; remotes batched/throttled; payloads minimal.
- Connections disconnected / instances destroyed; no unbounded caches.

**Text & safety** (`roblox-text-chat`)
- All player-authored text shown to others filtered server-side (`FilterStringAsync`), fail closed.
- Chat uses `TextChatService`; public editable text rate-limited (≥ 1 minute).

**Modern API usage**
- `task.*`, `*Async` variants, `Raycast`, mover constraints, `PivotTo`, `Animator:LoadAnimation`,
  `TextChatService`, `UIDragDetector`, `workspace` collision-group APIs, `CreatePath`+`ComputeAsync`.
- Full map of deprecated and superseded members: [references/deprecated-apis.md](references/deprecated-apis.md).

**Code quality** (`roblox-luau`)
- `--!strict` with typed public APIs; services via `GetService`; no `_G`/`shared`.
- Clear module boundaries; config separated from logic; tests for pure logic (`roblox-testing`).

## Output format

```text
## Summary
<2–3 sentences: overall risk, the most important fixes>

## Findings
1. [Critical] src/server/Shop.server.luau:42 — Price read from client argument.
   Impact: exploiters buy anything for 0 coins. Fix: look up ITEMS[itemId].price on the server.
2. [High] ...

## Modernization (optional)
- Replace `wait()` → `task.wait()` (12 occurrences) ...
```

Offer to apply fixes; when fixing, keep behavior identical except for the bug, and re-run the relevant
checks (type check, tests, Studio playtest via `roblox-studio-mcp`).
