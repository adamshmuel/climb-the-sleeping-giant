# 6. Testing

Part of [the architecture](../architecture.md).


### The tool: Jest-Lua, run inside Studio

We compared three options:

| Option | How it runs | Result |
|---|---|---|
| Roblox's built-in `rbx-unit-test` harness | A small runner module plus test modules in ServerStorage, run in Play with `execute_luau` | Works, but its own rule says: if the place already uses a test framework, use that. It also needs Play to run, which is slower. |
| **Jest-Lua** (`jsdotlua/jest@3.10.0` through Wally) run with `execute_luau` | A runner module calls Jest inside Studio's edit mode | **Tested on 2026-10-12 in this Studio:** an existing Jest suite ran 18 tests in 0.2 seconds, in edit mode, with no Play and no special settings. |
| Jest-Lua plus `jest-roblox-cli` (runs tests from the terminal) | Needs Roblox Open Cloud keys, or a Studio plugin, or a second hidden Studio | Not used. The project has no Open Cloud keys, the plugin isn't installed, and a second Studio next to the one the agents use is untested. |

**We use Jest-Lua run with `execute_luau`.** Why: it was proven in this Studio, it's the framework Roblox uses itself, it runs in edit mode in under a second, and it has clear matchers (`toBe`, `toEqual`) and nested `describe` blocks.

### How tests are written

- Each module has one test file in the same place under `src/tests`, named `<Module>.spec.luau`. Example: `src/server/Giant/Noise.luau` is tested by `src/tests/server/Giant/Noise.spec.luau`.
- **When a test file grows past about 600 lines,** it becomes a folder with the module's name, `src/tests/.../<Module>/`, holding one `<Topic>.spec.luau` per topic and, if they share helpers, one `Helpers.luau` (a plain module: Jest only runs files ending in `.spec`). Each topic file keeps the original `describe` names, so a test's full name doesn't depend on which file it is in. The runner's name filter matches the path, so `("RealWorld")` still runs every file in `RealWorld/`. Tests that share an expensive `beforeAll` (such as the stuck scan's real walk map) stay in one file. A helper is never copied into a second file. Stuck safety Task 30 splits today's big test files this way.
- Each `it(...)` checks one behaviour and is named after it, for example `it("adds no noise while standing still")`.
- Every test file starts with `--!strict` and loads Jest like this:
  ```luau
  local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
  local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
  ```
- Modules get what they need passed in (players, clock, random numbers, the world data), so a test can pass simple fake tables instead. Time is passed in as a number, never read with `os.clock()` inside a pure module.
- **Tests never change the place.** A test builds its objects without a parent, or in a folder it destroys at the end. Nothing is parented into `Workspace`, `ReplicatedStorage` or `Players`.
- **Fake worlds (V2).** A test that needs rays or overlap checks builds a few parts inside a `WorldModel` in `ServerStorage` and destroys it at the end, even when the test errors (it is destroyed before anything else that can fail). Its `Archivable` is off, so a world left by a crashed run is never saved with the place. A `WorldModel` answers `Raycast` and `GetPartsInPart` like the Workspace (code_lead checked both in Studio on 2026-10-19; an unparented one answers nothing), **except collision groups: a `WorldModel` ignores them**, in `ServerStorage` or inside the Workspace (the builder found it on 2026-10-19 and code_lead re-checked it the same day). The Workspace obeys them. `PathCheck` takes the world to search as an argument, so the same code runs on a fake world and on the real one.
- **The one exception: the body probe.** `GetPartsInPart` needs a real part in the same world, so `PathCheck` keeps one invisible probe part (no collision, no touch, no query, `Archivable` off, so it is never saved) while it checks the real Workspace, and `PathCheck.cleanup` removes it. Tests call `cleanup` at the end.
- **The second exception: collision-group tests** (stuck safety Task 19). A test that proves a check ignores parts in a group that doesn't collide with `Players` (such as another player's body) can't use a fake world, because a fake world ignores groups. So it builds a small arena in the real Workspace:
  - a `Model` named after its test file plus `GroupArena` (for example `PathCheckGroupArena`), far from the map at (5000, 5000, 5000), `Archivable` off, so a crashed run never saves it;
  - its own temporary group (for example `PathCheckTestLook`), registered in `beforeAll` and set not to collide with `Players`. `Collisions.setupGroup` runs first, so `Players` exists the same way the running game makes it. `Players` is never removed;
  - `beforeAll` first removes anything a crashed run left: the arena, then the temporary group;
  - each test destroys its arena first in `afterEach`, before anything else that can fail, then calls `PathCheck.cleanup`. `afterAll` unregisters the temporary group after every arena is gone.
  Why: it is the only way to see the real effect of a group, and the Workspace is where the game's checks run. The arena is a few parts for a moment, far from everything, like the body probe.
- **Long real-world checks (V2).** The stuck scan takes up to 2 minutes. It yields (`task.wait()`) after every chunk of work, so Studio never freezes long enough to drop the connection, and its test sets a longer Jest time limit than the default 5 seconds.
- Things a test can't check (how it looks, how it feels, several real players) are checked in Play with screenshots, as `agent-workflow.md` asks.

### How tests are run

Rojo must be running and synced (see section 7). Then, in Studio edit mode, with `execute_luau`:

```luau
return require(game:GetService("ServerStorage").Tests.TestRunner:Clone())()
```

It returns `TESTS PASSED` or `TESTS FAILED`, with the count and every failure message. To run some tests only, pass part of the file name, for example `("Noise")`. The `:Clone()` makes sure the newest runner is loaded each time.

**A full run goes in the background (stuck safety Task 51).** A full run takes about a minute, longer than one Studio call may last (about 45 seconds). So it is started and fetched with `ServerStorage.Tests.BackgroundRun`:
- **How Studio stays free:** before every spec file, Jest runs `PauseBetweenFiles`. It counts the file and waits one frame, so Studio answers other calls during the run.
- **Start (one call):** `BackgroundRun.new({ runner = TestRunner.runRaw, folder = <a Folder made for this run>, extra = <optional function returning one line, such as the scan> })`, then `start()`. A second start while a run is going is refused.
- **Wait:** about 60 seconds in the terminal.
- **Fetch (one call):** `fetch(30)` returns a report under 900 characters: the first line, the counts, the extra line, then the failed tests' names. It clears the folder's values once the run is done. The fetch call destroys the folder after reading it, so nothing is left in the place.
- **"Not reachable":** fetch again. Never start a second run.
