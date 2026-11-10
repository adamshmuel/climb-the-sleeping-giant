---
name: studio-jobs
description: How to write, paste and fetch a Studio job script (a script in work/ pasted with execute_luau, in Edit or Play) - lookups, long work in the background, fetches, self-checks, printing, starts, walks, prompts, the phone, and the Studio facts that break jobs. Use when writing a job script, reading one before its first paste, pasting it, or fetching its results.
---

# Studio jobs

A job is a script in `work/` pasted with `execute_luau`. `scripts/job-check.sh` runs on every save of one (a hook). This skill covers what it can't check. What the handoff around a job says (caps, world table, pass list, smoke run) is the `writing-handoffs` skill.

## Studio facts
- A call waits about 45 s at most. "Studio not reachable" means Studio is busy: wait, then fetch. Never start the work again.
- Studio cuts a call's returned text at about 1024 characters. Print the key result lines first, and end with `string.sub(text, 1, 1000)`. When you cut output yourself, keep the result lines (they come last), not the start.
- In Edit, a plain `require` returns the copy Studio cached first, even after Rojo synced a newer one. In Play, nothing is cached. A `require` from a job gets its own copy of a module, never the game's live one.
- Roblox's control script resets `Humanoid:Move` and `Jump` every frame. A scripted press uses `MoveTo`, or `Move` and `Jump` from one `BindToRenderStep` at Input+1.
- Attributes a client sets on a player don't reach the server. A server watcher gets case marks through a RemoteEvent, and the smoke run proves it ("seen <case>").
- Roblox picks which prompt to show by the camera's direction.
- A billboard's `AbsolutePosition` reads 0,0. Shots and billboards: `playing-the-game` skill.
- The console prints an analytics event only as "AnalyticsService: LogCustomEvent event fired.", with no name or values.

## Finding parts
- Find every part by its full path or from its model first (the model, then the part in it). Never by a bare name or a name search: a copy or a mirror twin has the same name.
- A name with a dot in it (`CaughtCard.spec`): use `FindFirstChild("CaughtCard.spec")` on its parent, never a dotted path.
- Every lookup prints "found N of M". Expected counts come from one fresh count of every child with that name. Only a missing part, or a surplus of a part the job changes or measures, stops the job; a surplus of a part it only leaves alone is reported.
- Print a stored line raw first. Parse it only after seeing its format.

## Long work
- Start long work with `task.spawn`, store results in `shared`, and return at once. A second call fetches.
- The job writes its expected end time into `shared` at the start, one short line after every try, a heartbeat count, and a `done` flag.
- Wait until the job's own end time (`python3 -c "import time; time.sleep(N)"`; a hook blocks Bash `sleep`), then fetch once. The fetch waits inside for `done` for up to 30 s. A fetch that shows no progress: stop and report the last line.
- A fetch reads the saved state with a short call and the same `shared` name its job writes. It never pastes the job again.
- A test-run report keeps only about 150 characters of each failure message. To read a long message (for example every stuck spot), run the check's own logic in a dump job that saves the whole list, like `work/p5t13b/stuck-dump.luau` (p5t13b, 2026-11-08).
- Take shots inside the job's own hold, not after it.
- Keep each job small: one spot or one kind of walk. Store anything slow to build (a walk map, a list) in `shared` before using it.
- Play records go to the server before Play stops. The fetch writes the whole list to a file in `work/` and checks every label is there.
- A helper module a later check needs stays in Studio until the task closes. The task's last Studio call clears the `shared` keys its jobs made, unless the handoff names a later task that needs one.
- A saved walk map is reused only if it was built after the last world change and the handoff says so.

## Writing the job
- Requires: in Edit, `require(module:Clone())` for a module with no `script.Parent`; in Play, the plain way. Cast once: `local requireModule: (ModuleScript) -> any = require :: any`.
- Write text with backtick strings, not `..` or `string.format` over many lines (StyLua stretches them).
- A result table gets a real type, never `any`.
- Copy any number or rule the game uses (a time limit, a ray, a lift) from its source file and line, and name that file:line in a comment. Never from an older job.
- When a job calls game modules, copy how the server calls them (its init script), not the loader's return type.
- A job a later step reuses lives in a tested module in `tools/checks/`. The short wrapper that calls it is kept in `work/`, and every re-run pastes that same file.
- A measure that repeats a test's check calls the test's own helpers, with its spacing and pass rule.
- Placing: each part goes in its own `pcall` with its own pass or fail.
- A world script in `tools/` `return`s its main function; the job calls it inside `pcall` and reads the report from a `shared.<Name>Report` table, not from the console. A Studio script line never starts with `(`. <!-- 15a, 2026-11-08 -->
- A change to what a report prints is proven in one real run, not only by unit tests.

## Checks the job runs on itself
- Before the long part: every lookup and every name one job expects from another (remotes, folders, attributes) is checked, and the job stops with a clear message if anything is missing.
- Each check runs once on the world without the change and must pass there before it judges a trial.
- Every walk input runs for 1 s and prints how far the body moved. Under 8 studs: stop with "INPUT DEAD".
- A walk map covers every place the job measures, with 20 studs around each, and prints its edges.
- A job that finds starts by label matches the label's first word, and its first call prints labels with no start.
- A report pastes the last line of each check it ran.
- **A world script's state is checked only with a CHECK_ONLY clone** (gsub the flag on a clone of its Source). Never run one for real to see "already done": a script whose done-test predates later fixes rebuilds over them. Undo and Redo are blocked by a hook; a rollback clones from `WorldBackups`. <!-- p5t16b, 2026-11-10: a real re-run of 22 plus Undo lost CuffWalk -->

## Printing results
- Every stop names the check that fired and prints that check's own first failure.
- Every fail line prints its reason word, end feet and the moment it failed (tick, value, what the body did). Each kept table prints its exact key.
- A check that can fail names each failing point (its label and which test missed), not only a count.
- Print the numbers each result is judged by, passes too. A check that finds 0 problems prints its closest case and where it was.
- Record where each failure happened (points), never only distances.
- A job that reuses a shared check prints the reason for each start it refuses.
- Results a later ruling may need go in the printed summary before Play stops.
- Print the state a step needs (for example carrying the item) before the step that needs it.

## Starts
- A walk or Play handoff lists only starts that an Edit-mode call already printed as open (from `StartCheck.nearSpot`), as fixed numbers. The Play job never searches for starts. Never start on a round or sloped top.
- Every start list says whether its points are feet or root, and adds the lift in one named line (feet to root: 3.25). A start's feet go on the ground straight below it.
- Every run starts from its own start, never from where the last run ended. A re-walk starts from the start the earlier run walked from. A place a fix has filled is replayed from its original walk's recorded start, never walked into from beside it.
- A spot measured next to a trial part is proven again once that part is gone.
- Re-check a start from the point it was found from, with the same reach. Print how far it moved.
- A start meant to be inside a gap or under an overhang prints the roof height above it, and is dropped if it isn't under that roof.
- Stand spots are where players really walk (the walk map, a route), never "the nearest part of a kind".
- **Dry start:** put the body on each start, settle 2 s, press 1 s, print drift, floor height and the pose it stalls in. Stop "(lost input)" only if a start the main proof uses drifts over 1 stud; other starts only print.

## Walks and bodies
- "Held still": from the first frame on the ground with low speed, measured along the ground (X and Z), plus a separate "doesn't rise" check. "Silent": judged from 1 s after the stall starts. A timing clock starts at the stall when the body doesn't climb.
- Read the pass rule against how the body really reaches the spot (standing, climbing or falling).
- A fall rule measures the fall itself (feet drop since it began), never the planned target. Once a falling body touches a floor, the press stops.
- An escape from a hang presses from where the body is, without re-placing it. Each push try logs its highest point.
- A wedge counts as "got out" only when a walk-out (4 directions plus a jump) moves the player away. Walk logs print the feet height for both the end and the wedge. Each walk leg stops on arrival before it can count a wedge; a re-test counts only if its wedge is within a few studs of the original, on the same part.
- **The stick follows the game.** Release a push on the game's own state (off the ladder, falling), never on a timer. Keep each retry aimed at what the case climbs, and end a try that walks past it. Print one line per try: why it ended, start, highest point, whether it climbed, end. After a fix to an end rule, apply it to every case still to run.
- **Moves the job didn't make.** Log the position before any move over 8 studs in one frame and label it "moved by the game" (rescue, bounce). It is never a pass or a fail; check it against the game's own rescue and landing spots.
- Pass or fail comes from the game's own event (for example a Rescued remote). Stop the player's input the moment it fires, and judge every check on it wherever it happened.
- Listen to change events from the start and keep every change with its time. Never poll afterwards.
- **Many tries in one call pair.** A job that waits for each try's first move and records it, plus one timed keyboard call (about 6 s per try), runs about 7 tries per pair. Never one call per try. A start spot's ground ray begins just above the spot, not high above it, or it lands on a higher surface. <!-- p5t15b, 2026-11-09: 75 calls, turn cap -->

- A timed action starts from a signal inside the key call itself (for example `GuiService.MenuIsOpen` turning true), never from an earlier call.
- **Loops and copies.** Every background loop stops on a flag the clean-up script sets; finish one trial loop before starting the next. A walk script reads the walk speed from the game's config, never a saved value. A job that reuses a walk script lists every line that uses its mirror sign before the first paste.
- A job fix that changes how every leg moves says so, and the next full walk re-checks every leg.
- **Slides and falls need a real walk off the edge.** `character_navigation` finds a safe path and never walks off a seam, and setting the root's velocity doesn't move the body. Walk off the edge with a client `hum:Move(direction)` loop. <!-- p5t10, 2026-11-10 -->

## Prompts
- Face the player and the camera toward the part, and print whether it's on screen.
- Wait for the game's own `PromptShown`, then hold. Print shown time, input type, distance, hold start and trigger time.
- Track whether a prompt is shown now (shown, not hidden since), never "a new shown since the last stage".
- A leg that should grab something logs whether it did.

## Phone and shots
- Set the phone exactly as the `look-check` skill's [shots job](../look-check/shots-job.md) does (`Phone_844x390` through `StudioDeviceSimulatorService`, in the Client during Play) and turn it off the same way. Write every Studio call with its full service path.
- Shot cameras are placed and aimed the `look-check` skill's way ("Shots").
- A shot that proves something is kept is taken right after the event, before another rule can remove it. Print the state at that moment.
- A shot camera looks at a prompt's part from the side, with nothing between. Find a billboard's screen point from its adornee, never its `AbsolutePosition`.
- A look check copies the client's own ray, list and fallback and judges where the client draws. A server value is only an input.
- A float check first asks whether the part sits inside a visible mesh, and reports a wall's height apart from a float.

## Muting the sound in Play
Never saved. Only in Play, only in the Client: run it with `execute_luau` and `datamodel_type` "Client", so it vanishes when Play stops.
1. Make a `SoundGroup` named `SessionMute` in `SoundService` with `Volume` 0, and set every `Sound`'s `SoundGroup` to it, also for sounds added later (`DescendantAdded`).
2. For the newer audio objects, every `Wire` whose `TargetInstance` is an `AudioDeviceOutput` gets `TargetInstance` nil, also for wires added or re-aimed later (anything wired to an `AudioDeviceOutput` is heard).
3. Wrap each object in `pcall`.

Never run it in Edit or on the Server: Edit changes are saved with the place. Never touch `UserGameSettings` or any Studio setting: they are the user's own and outlive the session. `SoundService` has no `Volume` property.

## Driving a climb
- `user_mouse_input` drives the phone's thumbstick: press at (90, 285) and drag to (90, 225). Don't use the `ThumbstickStart` path after the first use.
- A climber frozen mid-ladder (anchored, animation stopped) can't be unfrozen without a drop, so start each shot from a fresh teleport.
- A `Scriptable` camera set with `execute_luau` is reset before `screen_capture`: use a render-step bind or the capture's own camera arguments.

## This game
- **A warning in a Play shot shows the real meter above 85**, never a Warning fired by hand with the meter at 0 (that shows the dark, empty "Giant is sleeping" bar). At a spawn spot a real crossing can't happen, so write `GiantState.Meter = 95` from a Server `execute_luau`, then fire the Warning with 85: that shows the real 85% look (orange meter, tip, glow).
- **To spawn at garden N,** do what `Spawning` does: `PlotIndex`, `RespawnLocation = Plot_N.SpawnSpot`, `LoadCharacter`; then leave the game's own spawn camera alone.
- **Not bugs** (designer, `docs/specs/v2/research/decisions-plans.md`): the pink and purple patch right of the belly is in the giant's own body texture, and the grey box over the bottom-left of the phone screen is the simulator's thumbstick area (`DynamicThumbstickFrame`).
- Reduce Motion in Play and Studio's id: `docs/progress/v2/new-player-safety.md`, "Task 11 points for later", points 2 and 4.
- `StartCheck.find` returns `position` (highest hit + 0.1) and `ground` (the hit under the body's middle). A settle or floor limit uses `ground`; a start uses `position` (`tools/checks/StartCheck.luau`).
- The server lifts a rescued body 0.5 studs (`LIFT`, `src/server/Players/Recovery.luau`).
- Banking an egg: move to the plot's `GardenVolume` pivot, inside the fence (`src/server/Eggs/Banking.luau`). The SpawnSpot is outside the garden.
- "Went home" means within 4 studs (flat) of the player's own plot `SpawnSpot`. Before relying on a box, check the expected spot is inside it.
- A job that carries an egg adds one server watcher that prints the time, reason and garden whenever `Carrying` changes.
- "Stuck" means Rule 22 (What counts as stuck) in the stuck-safety spec, never "failed".
- The walk map has no spots on the forehead's walking band. Near the band, measure with rays from the band's walking height down to the spot; "no walk-map link" there doesn't mean "not reachable".
