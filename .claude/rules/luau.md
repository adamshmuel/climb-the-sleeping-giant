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
- Never start a line with `(`: StyLua joins it onto the line above and the script breaks with no lint error. Write a cast as `local x = y :: Instance`.

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
- Roblox stores positions, sizes, angles and decimal settings as 32-bit numbers (0.6 reads 0.6000000238). Compare them with `toBeCloseTo` or a margin of about 0.01 (1e-3 for degrees), never `toBe` or 1e-6.
- A rounded number is checked over a span (start minus rate × ticks), with the rounding at both ends as the margin, never tick against tick.
- `expect` takes one value: wrap a call that returns several in parentheses, `expect((string.find(text, "x")))`.
- A Luau `for` loop never visits a key set to `nil`. To test a missing value, build the sample and then set that field to `nil` on it.
- Pass in what a test can't drive: a `died(character, callback)` dependency (Edit never fires `Humanoid.Died`), and a stand-in Humanoid for read-only properties like `MoveDirection`.
- A fake body is put into the world after `CharacterAdded` fires, as the engine does.
- A test that places something by another module's number (a reach, a pixel line) works the position out from that value in the test, and its comment names the source. Never a typed-in number.
- A distance between two places measures the same point on both (feet with feet), with a real body height.
- An object's recorded sizes and places live in one shared module that every world-script section and test reads, never a copy.
- A run report keeps only the first 150 characters of a failure message (`WHY_LIMIT` in `src/tests/BackgroundRun.luau`). Put the key numbers first, and a test that lists every offender puts the whole list first. After fixing the first offender, measure them all again.
- When a check is skipped for one case, remove in the same change any setup only that check used.

## World scripts (`tools/`)
- Never add parts to a folder another world script owns and counts. Add the part to the owning script's records.
- Before placing anything, print how many parts the script will add, and stop unless that matches the plan.
