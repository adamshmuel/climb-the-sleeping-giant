# Lessons: Studio, Rojo and scripts

About deleting files, reading output, and writing scripts for Studio. The map of all lessons is `docs/lessons/index.md`.

## Lesson 3: Removing a synced folder crashes Rojo
- **What happened:** `rojo serve` 7.7.1 crashed about 6 times when builders deleted trial folders in `src/`. Each crash cut Studio off, and the user waited about 3.5 hours in all to click Connect.
- **Do instead:** trial scripts live in `work/` and go into Studio through `execute_luau`. Delete a synced folder only with `scripts/rojo-safe-rm.sh`. A hook blocks unsafe deletes (`CLAUDE.md`, "Dev loop").
- **Who checks:** `builder`, the main chat.

## Lesson 6: Never pull the whole console into an agent's memory
- **What happened:** builders often went over their memory limit. One filled up from a single unfiltered `get_console_output` that held the whole earlier test log (Task 37, step 37-3).
- **Do instead:** send long output to a file in `work/`, filter it, and read only the summary (at most about 100 lines).
- **Who checks:** `builder`, `code_lead`.

## Lesson 7: A Luau line can't start with "("
- **What happened:** pasted trial scripts failed to parse because a statement started with `(`, which Luau reads as part of the line before (Tasks 32 and 37). Each failure wasted a Studio call.
- **Do instead:** put the value in a local first, for example `local parts = (...)`, or `local sh: any = shared` before `sh.x = ...`.
- **Came back:** Task 47 step 1 (2026-10-28) lost a Studio call to `(shared :: any).x = ...`. A hook (`.claude/hooks/luau-paren-line.py`) now blocks any Studio script with a line starting with `(` before it is sent.
- **Who checks:** `builder`, and the hook.

## Lesson 22: Long Play work runs in the background
- **What happened:** in Task 37's last Play check, code_lead's two client calls each waited inside the call and came back "Request timeout", so nothing was measured (2026-10-27). The builder's earlier scripts also depended on a helper module it removed before the next check.
- **Do instead:** a client call starts long work with `task.spawn`, stores the results in `shared`, and returns at once; a second call fetches them. A helper module a later check needs stays in Studio until that task closes. A full test run keeps Studio busy the same way: start it, wait in Bash, then fetch the result. A call that comes back "Studio not reachable" means Studio is busy; wait in Bash before the next call, never retry at once.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 28: Each object's recorded places live in one module
- **What happened:** Task 41's flat pillow had its size, place and turn check written twice, in two world-script sections, because the second section copied the first one's numbers (2026-10-27). Changing one would silently break the other.
- **Do instead:** an object's recorded sizes and places go in one shared module that every section and test reads, never copied into a second file.
- **Who checks:** `code_lead` (in the review), `builder`.

## Lesson 29: Fetch background work once, when it's done
- **What happened:** in Task 42 step 2 the builder started the world script and the full tests in the background (Lesson 22), then fetched twice before they finished. Both fetches found nothing new, the step went 2 calls over its cap, and the results were never read (2026-10-27). Lesson 24 had fixed this kind once already, for a different cause.
- **Do instead:** the background job sets a `done` flag and its finish time in `shared`. Before fetching, wait in Bash for the job's usual time (the handoff gives it, for example a full test run). The fetch call itself waits inside for the `done` flag for up to 30 seconds (under Studio's ~45-second limit), then returns what it has. One fetch per job.
- **Also (Task 33 step b):** a job that skipped most of its starts finished in 95 s, but the builder waited the full 300 s and missed the moment it held the player for a shot. Wait for the job's own finish time (it writes its expected end into `shared` at the start), not a fixed time, and take shots inside the job's hold, not after it.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 31: A background job reports as it goes
- **What happened:** Task 33 step 1's Play job (22 walks, about 105 s) wrote its results only at the end. It never finished, two fetches came back empty, and nobody could tell where it hung (2026-10-27).
- **Do instead:** a background job writes one short line into `shared` after every try, plus a heartbeat count, so a fetch always shows how far it got. Keep each job small (one spot or one kind of walk). A fetch that shows no progress means stop and report the last line, never fetch again.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 34: Placing numbers are fixed, and each part gets its own try
- **What happened:** Task 33's handoff left the forehead box's bottom to be worked out from rays inside the placing call. One ray started inside V1's plate, the start check failed, and the whole call stopped, so the beard box wasn't placed either. One Studio call was spent with nothing built (2026-10-27).
- **Do instead:** the measuring call prints every ray start's open check on its own line, and turns the results into fixed numbers (CFrame and size) in the handoff. The placing call only places those numbers, with each part in its own `pcall` and its own pass or fail, so one part's problem never stops the others.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 40: A job a later step reuses lives in a tested module
- **What happened:** Task 27 step 2's list job was pasted straight into Studio and never kept. Step 2b had to rebuild the list by guessing its ray rule, got 678 spots instead of 681, and stopped with nothing done (2026-10-27).
- **Do instead:** a job whose results a later step or task reuses (a list, a set of starts, a grouping) lives in a tested module in `tools/checks/`. Only a short wrapper that calls it is pasted into Studio. One-off jobs are still pasted once and not kept.
- **Also (Task 45 step 3):** the wrapper itself is kept too, in `work/`, and every re-run pastes that same file. Call 6's wrapper wasn't kept, so call 9 rebuilt it with a different ray filter (693 spots, not 691), and the count check stopped it.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 41: One test filter per runner call, and check the suite count
- **What happened:** Task 45 used a test runner filter "SteepList|PlayedList". The runner ignores `|`: it ran only the first name, so one spec looked red or green while the other never ran. It cost a Studio call (2026-10-27).
- **Do instead:** run each name in its own runner call (several calls fit inside one `execute_luau`), and check that each one ran: the runner's report has no suite count, so count the matching spec files in the same call.
- **Also:** Vector3 maths is 32-bit, so a 45° angle reads as about 44.99999°. A "45 or more" test needs a tolerance of about 1e-3 degrees.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 42: A job keeps slow results in `shared`, and takes data shapes from the server's own calls
- **What happened:** Task 45 step 2's wrapper passed the gardens raw from `WorldIndex.loadGardens`, but `Zones.locate` wants the boxes the server makes with `PlayerTracker.gardenBoxes`. The job failed after building the walk map, and the map was in a local variable, so the last allowed Studio call had to rebuild it (2026-10-27).
- **Do instead:** a job that builds something slow (a walk map, a list) stores it in `shared` before using it, so a later bug costs a fetch, not a rebuild. When a wrapper calls game modules, copy how the server calls them (the init script), not the loader's return type.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 44: Check the sync with a free search before the first runner call
- **What happened:** Task 43 step 1: Studio restarted mid-step with a new id and the Rojo plugin disconnected. The builder's red run ran the old code (12 pass), so one of three Studio calls was wasted (2026-10-27).
- **Do instead:** every handoff starts with `list_roblox_studios`, then `script_grep` for a name the step just added or removed (a free call). If Studio doesn't show the change, stop and report before any runner call. Only the user can click Connect.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 46: A Play job counts climbable parts and play time up front
- **What happened:** Task 43 step 2 counted any 3 `Climbing` frames as a hang, so pushes into the real BeardLadder counted. It also ran about 20 s per spot, so one step played only 100 of 203 starts, and 35 hang records were lost when Play stopped (2026-10-28).
- **Do instead:** a Play job's handoff names the real climbable parts it leaves out (ladders), the time per spot and how many spots fit a step, and sends every record to the server before Play stops (Lesson 42). The step that fetches the records writes the whole list to a file in `work/` and checks it holds every label; a handoff never points at labels it hasn't checked are in the file (step 3 lost 16 labels and about 25 minutes this way).
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 49: A test that places a blocker by a body's reach says which check it comes from
- **What happened:** StartCheck's wedge test put its wall at x 0.8, just inside the old upright box's reach (1.0). When Task 46 swapped in the walk map's tilted box (reach 0.77), the test broke, and a ruling plus extra Studio calls were needed (2026-10-28).
- **Do instead:** when a test sets a blocker by a body's reach, its comment gives that reach and names the check it comes from. A plan that changes a shared check lists those tests up front as "setup moves, expectations stay".
- **Who checks:** `code_lead` (in the plan), `builder`.

## Lesson 50: When a real-world test turns red, read the part it checks first
- **What happened:** in Task 46's full run, 3 garden tests went red. The team first blamed two overlapping test runs and spent a clean full run proving it wasn't that. The real cause was `Plot_2.GardenVolume`, moved by hand in Studio since the last clean run (2026-10-28).
- **Do instead:** when a real-world test turns red and the task didn't touch what it checks, first read that part in Edit (position, size, its pair) and compare it with the last clean run, before re-running anything.
- **Also:** a moved part is put back with the same math the world script that built it uses (here `tools/world/01-gardens.luau` step 8), never a guessed rule such as a mirror. The full test runner's result text is cut at 1024 characters, so a run started with `task.spawn` stores its result, and the scan line separately, in a short-lived attribute that a later call fetches.
- **Who checks:** `builder`, `code_lead`.

## Lesson 51: A full test run is fetched again, never started again
- **What happened:** a full test run holds Studio for about 56 seconds, past the tool's limit of about 45. Calls made during it came back "not reachable", the retries started second runs, and Task 46 lost about 10 Studio calls (2026-10-28; second time after Lesson 22).
- **Do instead:** start the full run in the background, with errors caught and a guard that refuses a second start. Wait 60 seconds in Bash, then make one fetch that waits up to 30 seconds and also returns the scan line. After "not reachable", fetch again; never start the run again. The guard that refuses a second start clears any finished run, not only a stopped one; test it against the last run's state before the first Studio call (Task 48 lost a call to an old finished run). The cause fix: the test runner pauses with `task.wait()` after each spec file, so Studio stays reachable (a small task, planned by code_lead).
- **Who checks:** `code_lead` (in every handoff with a full run), `builder`.

## Lesson 52: `expect` takes one value
- **What happened:** Task 51 step 1's green run had 2 failures that were bugs in the tests: `expect(string.find(...))` passed several values, and Jest said "Expect takes at most one argument". It cost a Studio call over the cap (2026-10-28).
- **Do instead:** wrap any function that returns several values in parentheses inside `expect`, for example `expect((string.find(text, "x")))`.
- **Who checks:** `builder`, `code_lead` (in review).

## Lesson 53: A Play job matches labels by their first word, and counts every call
- **What happened:** Task 47 step 2's first list missed 9 of 52 spots, because played starts carry extra words in their labels ("F-165 sq -48,-32"). Patching the list, plus a label query and a server call and a client call that the plan had counted as one, took 7 Studio calls against 4 and 37 tool calls against 30 (2026-10-28). Its fetch printed ok spots without their push distances, so the "backs out" result for the wedges has no numbers.
- **Do instead:** a job that finds starts by label matches the label's first word, and its first call prints the labels with no start before the long run begins. A plan counts the server setup, the client launch, start Play, stop Play and each fetch as separate Studio calls. A fetch prints the numbers each result is judged by, for ok spots too.
- **Who checks:** `code_lead` (in the plan and handoff), `builder`.

## Lesson 54: A check that finds nothing shows its closest case
- **What happened:** Task 47's replay reported "0 hangs" without showing how close any spot came, so nobody could check the zero, and it didn't record where the 2 stuck walk-outs stopped. Task 48 now needs an extra Studio call to measure those points (2026-10-28).
- **Do instead:** a Play job that finds 0 problems also prints its closest case (for hangs: the longest pressed run under 1 stud, and where it was), and records where each failure happened: the point where it stopped and where each push ended, never only distances. A push that starts after the body settles measures from the settle point, not from the trap (Task 48's re-plan).
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 62: A saved walk map goes stale when the world changes
- **What happened:** Task 28 step 1b's handoff would have reused the walk map saved in `shared.T45`, built before Tasks 46-50 changed the world (2026-10-28). code_lead caught it while checking the handoff's world names.
- **Do instead:** a job builds a fresh walk map, unless the saved map was built after the last world change and the handoff says so.
- **Who checks:** `code_lead` (in the handoff), builder.

## Lesson 63: A big job is pasted by a builder with room to spare
- **What happened:** Task 28 step 1b's builder was resumed at 110k to write and paste an 801-line job. Writing it took it to 143k of 150k, so it stopped before the paste (2026-10-28).
- **Do instead:** a job over about 300 lines is split (for example, a starts job and a separate check job), or a fresh builder does only the paste and the fetch. The main chat never resumes a builder above 100k for a step that writes a big job.
- **Also (Task 28 step 1c, 2026-10-28):** a fresh builder writing a 944-line job from pieces of an older one still reached 127k before the paste. Writing and pasting a job over about 300 lines are always two builders: one writes and checks the file, a fresh one only reads it once, pastes it and writes up. The main chat starts them that way even if the handoff names one step.
- **Who checks:** `code_lead` (sizing the step), the main chat (choosing to resume or start fresh).

## Lesson 64: A job's walk map holds every place it measures
- **What happened:** Task 28 step 1b's jump check used a walk map that covered only the giant's box, the landings and 10 more studs. The egg by the Sock, the Sock's west half and the gardens were outside it, so 5 guards "failed" the egg limit and the gardens showed no spots (2026-10-28).
- **Do instead:** a job widens the map to hold every place it measures (eggs, guard tops, gardens, with 20 studs around each) and prints the map's edges before the long part.
- **Who checks:** `code_lead` (in the handoff), builder.

## Lesson 65: A dry check call comes before the long Play run
- **What happened:** Task 28 step 4c spent 8 of 10 Studio calls and got almost nothing. The walks job ran, but the body never moved in 10 of 16 walks (its Move input didn't take). The proofs job stopped at once: it asked for a remote called "T28Route", and the server job, written by another writer, made "T28Rf". Nobody had checked the jobs against each other or tried the walk input (2026-10-28). It was the fourth handoff in a row that broke on a world or name it hadn't checked (Lesson 61).
- **Do instead:** when a step pastes more than one job, `code_lead` lists every name one job expects from another (remotes, folders, attributes) and checks the files match before the handoff. The first Play call of the step is a short dry check: every lookup across all the jobs prints "found N of M", and each walk input runs for one second and prints how far the body moved. The step stops there if anything is 0.
- **Who checks:** `code_lead` (in the handoff), the builder (the dry check call).
