---
paths:
  - "src/**/*.luau"
  - "tools/**/*.luau"
---

# Luau code and tests

## Luau and Roblox
- Start every file with `--!strict`. Use `game:GetService(...)` and the `task.*` library (never `wait`, `spawn` or `delay`).
- Logic goes in ModuleScripts. `init.*.luau` files only require and wire things up, so the logic stays unit-testable.
- Server-authoritative: the server validates every RemoteEvent and RemoteFunction argument (type, range, ownership, rate). Never trust client values for currency, damage or position.
- DataStores: wrap every call in `pcall`, prefer `UpdateAsync`, and save on `PlayerRemoving` and `game:BindToClose`.
- Disconnect connections and destroy instances you create. Don't leak them per player or per round.
- Look up any Roblox API with the `roblox-docs` skill. Never guess names or signatures.
- The PostToolUse hook runs StyLua and selene on `.luau` files. Fix what it reports.

## Test first
1. **Red:** write a failing test. Run it, and watch it fail for the right reason.
2. **Green:** write the least code that makes it pass.
3. **Refactor:** clean it up while the test stays green.

- No implementation code before a failing test exists for it.
- One behavior per test, named after the behavior.
- Never change a test to make a broken implementation pass.
- A test that passes the moment it is written tests nothing. Fix the test.
- Test helpers start from a brand-new player (nothing earned, nothing saved), unless a test asks for something else by name.
- Every feature that affects a full play session gets at least one end-to-end test: join, play, keep going past the first goal, and check what the player really gets.
- Tests run in Studio (`roblox-testing` skill). A full run goes to the `runner` (`writing-handoffs` skill).
