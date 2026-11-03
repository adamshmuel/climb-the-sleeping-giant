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
- **Also (Task 28w, 2026-10-28):** a small fix that removed `tonumber(` from the front of an expression left a line starting with `(` in a job file. Only a grep caught it. After every edit pass on a job file, the writer runs `grep -n "^[[:space:]]*(" <file>`, and a replacement starts with a non-`(` token (for example `0 + (...)`).
- **Who checks:** `builder`, and the hook.

## Lesson 22: Long Play work runs in the background
- **What happened:** in Task 37's last Play check, code_lead's two client calls each waited inside the call and came back "Request timeout", so nothing was measured (2026-10-27). The builder's earlier scripts also depended on a helper module it removed before the next check.
- **Do instead:** a client call starts long work with `task.spawn`, stores the results in `shared`, and returns at once; a second call fetches them. A helper module a later check needs stays in Studio until that task closes. A full test run keeps Studio busy the same way: start it, wait in Bash, then fetch the result. A call that comes back "Studio not reachable" means Studio is busy; wait in Bash before the next call, never retry at once.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 28: Each object's recorded places live in one module
- **What happened:** Task 41's flat pillow had its size, place and turn check written twice, in two world-script sections, because the second section copied the first one's numbers (2026-10-27). Changing one would silently break the other.
- **Do instead:** an object's recorded sizes and places go in one shared module that every section and test reads, never copied into a second file.
- **Also (Task 33b step 4, 2026-10-28):** the handoff called job-p's 1.0 s "HangRule's number", but `HangRule.HANG_SECONDS` is 0.5, so the new Play job would have missed hangs between 0.5 and 1.0 s. A handoff or job copies a rule's number from the rule's own file and line, and names that file and line in a comment, never from an older job.
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
- **Broken again (Task 61d step 1, 2026-11-02):** a handoff asked for one red run over "the five spec names", so three specs never ran. Now `scripts/job-check.sh --handoff` fails a filter line with several names or a `|`.

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
- **Came back (Task 54 Play, 2026-10-28):** the handoff asked one writer for a whole Play job with no size limit; it grew to 1106 lines and the writer ran out of memory at 162k before it was clean. **Now:** every handoff that asks for a job file gives it a line budget of at most 300 lines. A job that needs more is split into separate files (for example setup, walks, re-test), each pasted in its own call or loaded by the first. A writer that passes the budget stops and reports for a split.
- **Came back (Task 33b step 4, 2026-10-28):** one writer got three job files. Each had a 300-line budget, but together they came to about 950 lines, and the writer stopped at 136k of 150k with two files over budget. **Now:** one writer writes one job file (at most 300 lines). A step with several job files starts one writer per file, in parallel, each with its own state note. A job split into parts is pasted joined in one Studio call, so a split never adds a call. Check it with `scripts/job-check.sh --joined <part-a> <part-b>` (each part's size, then everything else on the parts joined).
- **Also (Task 12c step 2, 2026-10-29):** the joined check always failed on three warnings that come only from joining separate pastes: re-declared names, a later part's `--!strict` line, and code after a part's last `return`. That buried any real warning. **Now:** `--joined` lints each part on its own and drops only those three kinds from the joined type check, so a joined FAIL is a real problem (proved: a type error in a part still fails it). The same step gave one writer 4 files (about 950 lines) and it ended at 143k of 150k: the main chat starts one writer per job file, even when the handoff names one step.
- **Who checks:** `code_lead` (sizing the step), the main chat (choosing to resume or start fresh).

## Lesson 64: A job's walk map holds every place it measures
- **What happened:** Task 28 step 1b's jump check used a walk map that covered only the giant's box, the landings and 10 more studs. The egg by the Sock, the Sock's west half and the gardens were outside it, so 5 guards "failed" the egg limit and the gardens showed no spots (2026-10-28).
- **Do instead:** a job widens the map to hold every place it measures (eggs, guard tops, gardens, with 20 studs around each) and prints the map's edges before the long part.
- **Who checks:** `code_lead` (in the handoff), builder.

## Lesson 65: A dry check call comes before the long Play run
- **What happened:** Task 28 step 4c spent 8 of 10 Studio calls and got almost nothing. The walks job ran, but the body never moved in 10 of 16 walks (its Move input didn't take). The proofs job stopped at once: it asked for a remote called "T28Route", and the server job, written by another writer, made "T28Rf". Nobody had checked the jobs against each other or tried the walk input (2026-10-28). It was the fourth handoff in a row that broke on a world or name it hadn't checked (Lesson 61).
- **Do instead:** when a step pastes more than one job, `code_lead` lists every name one job expects from another (remotes, folders, attributes) and checks the files match before the handoff. Each job checks itself first, before its long part: every lookup across the jobs prints "found N of M", and each walk input runs for one second and prints how far the body moved. The job stops there if anything is short (product chose this over a separate dry check call, which costs a Studio call).
- **Also (code_lead's probe, 2026-10-28):** the walks drove `Humanoid:Move` from Heartbeat, copied from older jobs. Roblox's control script overwrites Move and Jump every frame, so it only worked when frame timing let it through (the probe lost 21% of the distance). Every job drives Move and Jump from one `BindToRenderStep` at Input+1, and stops with "INPUT DEAD" if the first second moves under 8 studs.
- **Also (Task 28 step 4d, 2026-10-28):** job-1d, written from pieces of job-1c, used `T.jumpClosest` but never created it, so the cushion's jump result threw and was lost. Its result table was typed `any`, which hides a missing field from the type check. A job's result table gets a real type (or every field it fills is listed when it is made), and the writer runs `luau-lsp` on it before the paste.
- **Who checks:** `code_lead` (in the handoff), the builder (the dry check call).

## Lesson 66: Job scripts in work/ pass the type check with a require cast
- **What happened:** in Task 28 step 5, luau-lsp rejected `require(<Instance variable>)` in a work/ job ("Unknown require: unsupported path"), and a macOS `sed -i 's|..|..|' file` took the script as a backup suffix and broke the edit (2026-10-28).
- **Do instead:** in a job script, cast once: `local requireModule: (ModuleScript) -> any = require :: any`, and call that. On macOS, edit with the Edit tool or `sed -i ''`, never a bare `sed -i`.
- **Who checks:** the writer builder.

## Lesson 68: A task's close clears its own shared keys
- **What happened:** at Task 28's close, 14 run guards and walk maps from finished jobs were still sitting in `shared` in Edit mode (2026-10-28). A stale guard can make a new job think it already ran, or read an old map.
- **Do instead:** each task's last Studio call clears the `shared` keys its jobs made, unless a named later task still needs one (then the handoff says which and why).
- **Who checks:** `code_lead` (in the close handoff), the builder.

## Lesson 71: A check passes on the unchanged world before it judges a trial
- **What happened:** in Task 54 call 2 the nest-route check found 0 of 4 routes even with no tuft placed, and a name search found 0 of 4 nests, so neither could judge the trial tufts. One of the task's few Studio calls was spent partly blind (2026-10-28).
- **Do instead:** each check in a trial call runs once on the world without the change first, and must pass there, before it scores any trial. A handoff names every part a check needs by its full path (the nests too), never by a name search.
- **Came back (Task 54 call 3, 2026-10-28):** the next measure ran the baseline first, as this lesson says, and the nest-route check again found 0 of 4, so a second call judged nothing. It had rewritten the test suite's nest check with a typed start and 1-stud spacing, while the test (`OnTheGiant.spec.luau`) starts at the ladder's top end and spaces spots 2 studs apart. **Now:** a measure that repeats a test's check calls the same helpers the test uses (for example `WalkFacts.ladderEndSpots`) with the test's spacing and pass rule, never a rewrite.
- **Who checks:** `code_lead` (in the job), the main chat (in the handoff).

## Lesson 73: The hook counts an agent's tool calls, not the agent
- **What happened:** Task 54 place step 3's builder had to write a new 409-line job and then run it. It spent 36 shell reads finding the pieces, used 51 tool calls against a cap of 30, and reported "about 24 of 30" (2026-10-28). The main chat had started one builder for both writing and pasting, against Lesson 63.
- **Do instead:** the memory hook (`.claude/hooks/agent-memory-cap.py`) counts each agent's tool calls since its last prompt or resume. From call 25 it shows the real count. Past 30 only a Studio call (to finish a world change or fetch a running job) or a note still works; past 35 only a note. Reports give the hook's count, never a guess. A handoff step that writes a new job over about 300 lines and runs it is always two builders (Lesson 63), even when the handoff names one step.
- **Who checks:** the hook; the main chat (splitting the step); `code_lead` (sizing the handoff).

## Lesson 74: A Studio script requires a tools module through a clone
- **What happened:** in Task 54's names check, a plain `require` of `ServerStorage.Tools.checks.StartCheck` in Edit gave back an old cached copy, so `nearSpot` was nil ("attempt to call a nil value") and the start re-check was lost (2026-10-28). The builder's call 7 used `require(...StartCheck:Clone())` and worked.
- **Do instead:** in **Edit**, a Studio script requires a tools or test module as `require(module:Clone())`, the same way the test runner is run. A plain `require` returns whatever copy Studio cached first, even after Rojo synced a newer one.
- **Came back the other way (Task 54 Play call 10, 2026-10-28):** the Play setup cloned `WorldIndex` too. A clone has no parent, and `WorldIndex` loads `script.Parent.Parent.Giant.Zones`, so it failed with "Requested module experienced an error while loading" and the whole Play run was lost. **Now:** clone only a module that never uses `script.Parent` (check with grep first). In **Play**, require game modules the plain way: Play starts a fresh copy of the place, so nothing is cached from Edit. A handoff lists, for each module a job requires, "clone" or "plain" and why.
- **Who checks:** whoever writes the script (grep each module for `script.Parent`); `code_lead` (in the handoff).
- **Came back in a ready-made script (Setup 7, 2026-10-29):** `scripts/studio/full-run-start.luau` cloned `TestRunner` but required `BackgroundRun` the plain way. So after Setup 7 synced, Task 12h's real report still came from the old copy and showed no failure messages, although Setup 7's own tests passed. **Now:** every module an Edit-time ready-made script requires from `ServerStorage` is cloned, and `scripts/check.sh` fails a plain one. A change to what a report prints is proven in one real run (a probe or the next full run), not only by its unit tests.

## Lesson 75: Re-check a start from the point it was found from
- **What happened:** Task 54's Play setup re-checked each start with `StartCheck.nearSpot(feet, 1)`, using the feet point that `find` had returned. `find` puts the feet 0.1 stud above the highest of its 5 ground rays, so on a slope they sit more than 1 stud above the ground under the centre. All three starts on slopes (the cap top and both brim crease points) were dropped with "no walk-map spot" (2026-10-28).
- **Do instead:** a re-check starts from the same point the start was first found from, with the same reach (for example 3 studs), never from the lifted feet point with a smaller reach. It prints how far each start moved.
- **Second time (Task 7 call 19, 2026-10-28):** Rare egg 1 sits in a dip of his belly. The job's 1.5-stud settle limit compared the resting body with `find`'s feet (the highest corner + 0.1), so it fired "slid or fell" when the body only dropped 2.16 straight down to the ground under its middle, and the grab and bounce-off moved to Task 7c. A settle limit is measured from the ground under the body's middle, or the job starts the root at a resting point already measured in Play. The cause fix (Task 55, 2026-10-28): `StartCheck.find`'s result now has `ground`, the centre ray's hit under the body's middle, next to `position` (the highest hit + 0.1). A settle or floor limit uses `ground`; a start uses `position`.
- **Who checks:** `code_lead` (in the handoff), whoever writes the job.

## Lesson 76: A job script is checked in the shell before its first paste
- **What happened:** Task 54 lost 3 Studio calls (calls 3, 4 and 10) to measure and setup scripts that stopped before they judged anything: a rewritten check, a wrong expected count, and a module loaded as an unparented clone. Each was the script's first run anywhere (2026-10-28).
- **Do instead:** before a new or changed job script's first Studio paste, the writer runs `scripts/job-check.sh <files>` (size, "(" lines, clones of modules that use `script.Parent`, format, lint, types) until it passes. Then `code_lead` reads the script against the lessons the handoff names. The script stops early with a clear message if anything it needs fails to load or comes up short, so a broken setup never lets the long job run.
- **Who checks:** the writer builder (the check script), `code_lead` (the read before the paste), the main chat (no paster starts before both).

## Lesson 79: Every stop prints the check that fired and its own failure
- **What happened:** Task 33b's measure stopped at its baseline gate because the hang-place test came back false, but the stop message always printed the sides line. The hang test's own words were never printed, so the cause couldn't be told without another Studio call. The same run also judged "within limits" with a 1e-6 margin, while Studio stores 101.4 as 101.4000015, so every shape would have failed (2026-10-28).
- **Do instead:** every stop names the check that fired and prints that check's own first failure line. A check that compares a stored position or size uses a margin of 0.01, never 1e-6. `code_lead`'s read before the paste (Lesson 76) looks at each stop message and each margin.
- **Also (Task 33b call 2, 2026-10-28):** a `say(text, ...)` wrapper passed a boolean to `%s`; the type check couldn't see it through `...`, and the crash lost the last 4 lines. Call `string.format` directly at each site; `scripts/job-check.sh` now fails on the wrapper.
- **Who checks:** the writer, `code_lead` (the read before the paste).

## Lesson 80: A job never picks a part by a search; the handoff names it
- **What happened:** Task 7's handoff told the Edit start job to find a "belly patch": the patch nearest the belly path whose top faces up. No such patch exists (the nearest of 154 was 49 studs away, and the "faces up" test passed every block), so the job picked a filler sealed under his skin, the start sat inside the giant, and the job stopped before judging anything (2026-10-28). It was the fifth stop of this kind, after Lessons 71, 61, 76 and 79. The pick was first seen by the paste.
- **Do instead:** every part a job picks by a rule ("nearest", "the one that faces up") is picked once in `code_lead`'s names-check call, with a `nearSpot` on the picked part when it is a start. The handoff then names the part by its checked full path with its measured numbers, never by what it is assumed to be. A pick that can only happen in Play (for example, the landing spot nearest where the player landed) is marked "(runtime pick)". `scripts/job-check.sh --handoff <handoff>` fails on a pick line with no path, position or that mark; `code_lead` runs it before any writer starts.
- **Also (Task 7 re-paste, 2026-10-28):** the handoff's Rare egg 1 start had to stand within 1.0 stud of the egg's Base, but the names check had already measured 4.65, and every try stood 1.38 to 4.80 over. The job stopped again, and product lowered the bar to the player's need (in grab reach). Before a handoff sets a limit, it checks the limit against the value already measured, and writes it as what the player needs.
- **Also (Task 7c call 1, 2026-10-28):** the names check stopped on its own 0.1 limit around a ground height worked back from a rest point (40.60), when the real ground was 40.21; it never reached the rest of its job. A names check is for measuring: it prints what it measures and stops only on a missing part or module, never on an expected value that wasn't measured. On a slope or dip, a stand limit covers the range from the middle hit to the highest corner. A handoff marks each number "measured" or "worked back", and a tight limit uses only measured ones (product). A walk-map section in one Studio call has a time limit and maps only the parts its filter can pass.
- **Who checks:** `code_lead` (names check and `--handoff`), the main chat (no writer starts on a handoff that fails it).

## Lesson 81: A look check measures where the client draws, with the client's own ray
- **What happened:** Task 7's Play job judged the belly slam circle at the server's slam point. That point sat on an invisible walk ramp (`CrossingRamp_Knee`), 1.03 studs over his skin, so the job stopped with "circle floating". But the client draws the circle at its own ray's hit, which was on his visible skin. One Play call and one cause call were lost (2026-10-28).
- **Do instead:** a check of something the player sees copies the client's own ray, list and fallback from the source file and line (Lesson 28), and judges the spot the client draws at. A server value is only an input to it.
- **Also (Task 55 walk-parts list, 2026-10-28):** four invisible guard walls built inside the boots read "31 over Terrain": the down ray passed through the boot mesh, so the "gap" was the wall's height, not a float. A float check first asks whether the part sits inside a visible mesh, and reports a wall's height apart from a float.
- **Who checks:** `code_lead` (job read, Lesson 76), the writer.

## Lesson 82: Set the phone in Edit, and take a "keeps X" shot before another rule can remove X
- **What happened:** Task 7c turned the phone on during Play, in the same call that placed the player, and the phone shot showed no grab pill; the shot couldn't tell a device-switch problem from a real bug. Its landing shot came about 9 s after the wake, after a hand slam had caught the player, so the empty back couldn't prove "players keep their egg" (2026-10-28).
- **Do instead:** set the device in Edit before Play starts. A shot that proves something is kept (an egg, a pill, a sign) is taken right after the event, before any later rule (a slam, a timer, a refill) can take it away, and the job prints the state at the moment of the shot.
- **Who checks:** `code_lead` (in the handoff), the paster.

## Lesson 84: A job stops only on a lost or broken input, never on a cross-check count
- **What happened:** Task 7c call 1 stopped on a worked-back ground height, and Task 8b slot 3 (Play server) stopped on `onHim 259, slot N 260`: all 350 legs had arrived, and the on/off-him split only sets the walk order, so nothing depended on it. Each stop cost Studio calls and a product ruling (2026-10-28). Lesson 80 had covered names checks only.
- **Do instead:** a job prints cross-check counts next to the number it expected and keeps going. It stops only when an input is lost or broken (a missing part, a lost leg, a total that is short), and the handoff marks each such stop "(lost input)". `scripts/job-check.sh --handoff` fails a stop rule that rests on matching a measured count.
- **Who checks:** `code_lead` (in the handoff and the read before the paste), `scripts/job-check.sh --handoff`.

## Lesson 85: A press that waits for a landing stops at touchdown, and every fail line says why
- **What happened:** in Task 8b's bot walk, 3 ladder drops kept pressing "away" for the whole 8 s, so the bot landed, walked about 112 studs across the meadow and never settled (NO_LANDING): a job fault that cost a re-run. The 13 short fail lines printed only each start, so a whole fix task is needed just to learn why they failed. And drop #346 passed as "let go from the top" without ever grabbing the ladder (2026-10-28).
- **Do instead:** once a body has fallen, the press stops as soon as the feet touch a floor. Every fail line, short or full, prints its reason word and end feet; it costs no call. A leg that should grab something logs whether it did, and the proof says so when it didn't.
- **Who checks:** `code_lead` (in the handoff and the read before the paste), the writer.

## Lesson 86: A walk job measures what the body really did, never what the plan expected
- **What happened:** in Task 8c the step-off press stopped only near the leg's planned landing height, so #279 landed on a higher ledge and pressed into a wall for 8 s (a false NO_LANDING). The walk-out re-placed the bot at its end feet, which can't work for a ladder hang. And the touchdown fix changed how every leg moves, so old passes could turn into fails (2026-10-28).
- **Do instead:** a rule about falling measures the fall itself (feet drop since the fall began), never the planned target. An escape from a hang presses from where the body is, without re-placing it. A job fix that changes how every leg moves says so in the proof, and the next full walk re-checks every leg on the new job.
- **Who checks:** `code_lead` (plan and job read), the writer.

## Lesson 87: Prove a check ran, and fetch only what is saved
- **What happened:** in Task 8c a joined job-check was given file names from another folder, found no files, checked an empty job and "passed"; code_lead's re-run found a real type error. A fetch re-pasted the whole 470-line job (about 7k tokens) when the lines were already in `shared`. And the re-walk's shot plan only picked unknown reason words, so a NO_LANDING that fit no row would have had no shot (2026-10-28).
- **Do instead:** a report pastes the last line of each check it ran; job-check now fails on a missing file. A fetch reads the saved state (for example `shared.T8cRewalk.lines`) with a short call. A shot plan also names any known reason that fits no table row.
- **Who checks:** `code_lead` (re-runs the checks before the paste), the builder.

## Lesson 88: A test helper can't pass nil through a loop
- **What happened:** in Task 9 the test "saves nothing with no ground under the feet" failed although the module was right. Its `sample(overrides)` helper copied the overrides with a `for` loop, and a Luau table loop never visits a key set to `nil`, so `groundNormal = nil` never reached the module (2026-10-28).
- **Do instead:** a test that needs a missing value builds the sample first and then sets that field to `nil` on it directly. A helper with overrides is only for values that exist.
- **Who checks:** the builder, and `code_lead` in review.

## Lesson 90: Edit mode never fires Died
- **What happened:** in Task 10 step 3 the death test waited for `Humanoid.Died`, but a Humanoid in a WorldModel or an Edit-mode Workspace never fires it, so the test could not pass (2026-10-28).
- **Do instead:** a module that listens for a death takes a `died(character, callback)` dependency from the start. The game passes the real `Humanoid.Died`; tests call the callback themselves.
- **Who checks:** `code_lead` (handoff), the builder.

## Lesson 91: A Studio job gets its own copy of a module
- **What happened:** Task 10 step 5 planned to read the live rescue module's state from a job (`Recovery.current()`). A `require` from `execute_luau` gives the job a separate copy of the module, so it read nil, and the helper became dead code (2026-10-28).
- **Do instead:** a Play job never reads live module state. It starts its own instance from the module, or checks by effect (where the body is, what the remote sent). No code is added only so a job can reach it.
- **Who checks:** `code_lead` (plan and handoff).

## Lesson 92: Set the phone device before its orientation
- **What happened:** in Task 10 step 5 `SetOrientationAsync` errored on the default device and ended the job before the phone check (2026-10-28).
- **Do instead:** a job sets the device with `SetDeviceAsync` first, then sets the orientation in its own `pcall`.
- **Who checks:** the job's writer, and `code_lead` before the paste (Lesson 76).

## Lesson 93: Look up every property a job sets
- **What happened:** a Task 10 job set `SoundService.Volume = 0`. SoundService has no such property, the type check let it through, and the job died in Play before judging anything (2026-10-28).
- **Do instead:** every property or method a job uses is looked up in the docs (`roblox-docs`) before the first paste. `scripts/job-check.sh` now checks each service's sets and calls against the class list, but only for locals made with `game:GetService`.
- **Who checks:** the job's writer, and `code_lead` before the paste.

## Lesson 94: A "nothing happened" check also proves something was tried
- **What happened:** Task 10's Play check passed "no noise while shaking" because the meter read 0 before and after, but the body never moved, so the check proved nothing (code_lead's review, 2026-10-29).
- **Do instead:** a Play check that something stays quiet also prints how much the cause really happened (for example the body's biggest move in one tick). A try where the cause didn't happen doesn't count and is made again.
- **Who checks:** `code_lead` (plan's "Done when"), `product` (approves the check).

## Lesson 95: A job finds what the game makes through the game's own lookup
- **What happened:** Task 11 step 5's Play job looked for GiantState inside Remotes, where the handoff said it was. The game's `Net.setup` puts it next to Remotes, so the job stopped on its first call, before judging anything (the eighth stop of that kind, 2026-10-29).
- **Do instead:** a job finds objects the game makes at runtime (remotes, state folders) through the same code the game uses, such as `Net.waitForClient`. It never spells their names itself. `scripts/job-check.sh` now fails a job that does.
- **Who checks:** `code_lead` (reads the job before its first paste), `scripts/job-check.sh`.

## Lesson 96: Press a button where the new and old results differ
- **What happened:** Task 11's Play check pressed Roblox's real Reset button in the garden, where the old Reset and the new one do the same thing, so it couldn't prove the new path (code_lead's review, 2026-10-29).
- **Do instead:** a Play check presses the button where the new behaviour gives a different result (on the giant). If it can't, the report names that check as not proven, and the plan names the task that proves it.
- **Who checks:** `code_lead` (plan's "Done when"), `product` (approves the check).

## Lesson 101: Tests run red before any code is written
- **What happened:** In Task 12 step 1 a builder wrote the code and its tests together, then stubbed the code out to see a red.
- **Do instead:** write the tests first, run them and watch them fail, and only then write the code (`tdd.md`). Every step prompt says so in one line.
- **Who checks:** `builder`, `code_lead` (review), the main chat (prompt).

## Lesson 102: Pass in the lookup when a property is read-only
- **What happened:** A Humanoid's `MoveDirection` can't be set by a script, so a client test couldn't drive a real one (Task 12 step 3).
- **Do instead:** the module takes the Humanoid lookup as a dependency, and the test passes a stand-in with `MoveDirection` and `GetPropertyChangedSignal`.
- **Who checks:** `builder`, `code_lead` (review).

## Lesson 104: Write job text with backtick strings
- **What happened:** StyLua spread long `..` and `string.format` lines over many lines, so a 280-line job became 425, over the 300-line limit (Task 12 step 4).
- **Do instead:** write job text with backtick interpolation, and plan a two-part split from the start when a job is near the limit.
- **Who checks:** `builder`, `scripts/job-check.sh` (size).

## Lesson 106: A grab step checks the prompt is really shown
- **What happened:** A grab reused from an earlier task did nothing in a new session (Task 12 step 5): the hold fired nothing.
- **Do instead:** before the hold, the job prints whether the prompt is enabled and shown, the distance, and where the camera faces. It never assumes the hold works.
- **Who checks:** `builder`, `code_lead` (reads the job).

## Lesson 108: A silent-meter check runs with and without an egg
- **What happened:** A "the meter never rose" check ran with no egg, so it said nothing about the rule for carriers (Task 12 step 5b).
- **Do instead:** a silent-meter check runs with and without an egg, each with its own control.
- **Who checks:** `code_lead` (handoff), `builder`.

## Lesson 109: A Play job reads the game's own signal and stops input when it fires
- **What happened:** Two Play reruns failed on the job's own checks: it measured the move from where the try began and kept pressing after the rescue (Task 12 step 5b).
- **Do instead:** the job reads pass or fail from the game's own event (for example the Rescued remote's from and to) and stops the player's input the moment it fires.
- **Who checks:** `code_lead` (reads the job), `builder`.

## Lesson 110: Compare feet with feet
- **What happened:** The rescue compared a safe spot's feet with the body's middle, about 3 studs higher, so "at least 4 studs" let 2.65 through (Task 12 step 5b).
- **Do instead:** a distance between two places measures the same point on both, and its test uses a real body height.
- **Who checks:** `builder` (tests), `code_lead` (review).

## Lesson 111: Listen to changes with times, don't poll afterwards
- **What happened:** A check that read `Carrying` from 1.3 s after the grab could miss an egg taken and lost in between (Task 12 step 5).
- **Do instead:** the job listens to the change event from the start and keeps every change with its time.
- **Who checks:** `builder`, `code_lead` (reads the job).

## Lesson 114: Carry an egg home into the garden box, not onto the spawn spot
- **What happened:** Task 12d's job "carried the egg home" by moving onto the plot's SpawnSpot, but that spot is 18 studs outside the garden, so nothing was banked and it looked like a game bug.
- **Do instead:** a job that carries an egg home moves to the plot's `GardenVolume` pivot, inside the fence. Its writer checks the bank zone in `src/` (`Eggs/Banking.luau`) before writing the job.
- **Who checks:** `builder` (job), `code_lead` (reads the job).

## Lesson 116: Start a timed action from a signal inside the key call
- **What happened:** Task 12e's Play job started pressing in one Studio call and sent the Reset keys in the next. The agent's own pause between the two calls could pass the 3.7 s before the stuck rescue fires, so the rescue could move the player instead of the Reset.
- **Do instead:** start any timed action from a signal that fires inside the key call itself (here, `GuiService.MenuIsOpen` turning true when Escape opens the menu), never from a call before it.
- **Who checks:** `builder` (job), `code_lead` (reads the job).

## Lesson 117: Measure "stands still" along the ground
- **What happened:** Task 12e's Play check said "the root moves less than 0.5 studs in the held second", measured in 3D. A rescue lands the feet 0.5 studs above the spot, so the body settled 0.6 studs down while the player was held, and a good try failed by 0.026 studs. The rerun cost 4 Studio calls over the task's cap.
- **Do instead:** measure "stands still" along the ground (X and Z), and check separately that the body doesn't rise. Before writing a distance limit, look up any lift or drop the game itself makes (here `LIFT` in `Recovery.luau`).
- **Who checks:** `code_lead` (pass list), `builder` (job).

## Lesson 118: A job prints its own proof of a fail
- **What happened:** Task 12e's phone check failed "meter never rose" (0.8). The job kept the meter's ticks under the key `B1#1`, but the builder read `B1`. Play was stopped, so the only proof of when the meter rose was lost, and finding the cause needs a rerun over the task's cap.
- **Do instead:** when a check fails, the job itself prints the moment it failed (the tick, the value and what the body was doing) in its result lines. It never relies on a second read by key. Each table a job keeps prints its exact key next to it.
- **Who checks:** `code_lead` (reads the job), `builder` (job).

## Lesson 119: A handoff writes each Studio call with its service
- **What happened:** Task 12f's handoff said only "`SetDeviceAsync`". The builder guessed the service and wrote `DeviceSimulatorService` instead of `StudioDeviceSimulatorService`. The call failed and used the step's spare Studio call.
- **Do instead:** every Studio call in a handoff names its full path, for example `StudioDeviceSimulatorService:SetDeviceAsync("iphone_14")`, so nobody has to guess a name.
- **Who checks:** `code_lead` (handoff).

## Lesson 120: Every Play step starts with a dry start
- **What happened:** Task 12b's beard start came from an Edit-time probe. In Play it was 5.9 studs in the air above a 44° slope, so the body fell, walked past the wedge and woke the giant. The wedge itself had been measured next to a trial box that was later removed. This was the ninth job that stopped before judging anything, and Lesson 65 (a dry check call comes before the long Play run) was there but nothing enforced it.
- **Do instead:** every Play step that uses Studio begins with a dry-start call. It puts the body on each start, settles it for 2 s, presses for 1 s, and prints the drift and the floor height under the feet. It stops with "(lost input)" if any start drifts more than 1 stud. A start's feet go on the ground straight below it, with the root 3.25 studs above. A spot measured beside a trial part is proven again in Play once that part is gone. Any older start chosen by an Edit-time probe (StartCheck) is suspect: the W6 start was also 3.6 studs above a 67° slope, so a handoff that reuses one re-measures the floor under it first. `scripts/job-check.sh --handoff` fails a Play step with no "dry start".
- **Who checks:** `code_lead` (handoff), `scripts/job-check.sh --handoff`.
- **Also (Task 12c step 3 rerun, 2026-10-29):** the Rare 1 grab start was called "proven" because a grab walk began there, but it had never held still. In the dry start it slid 7.2 studs and stopped the whole job, so the beard walks (the main proof) never ran. **Now:** a start is proven only if it held still (1 stud or less) in an earlier dry start, and the handoff line says so ("held 0.19 in <task> dry start"). A dry start stops only on the starts its main proof uses; every other start only prints. `scripts/job-check.sh --handoff` fails a "proven" line with no held number.

## Lesson 121: Judge "held still" and "silent" only once the body has settled
- **What happened:** Task 12b-1's notch tries failed every check, though the rescue fired all 3 times and the egg was kept. The job took its "landed" reference on the first frame after the move, 0.5 studs in the air, so the drop counted as movement. It judged Silent from the stall, while the walk-in was still inside the tracker's 1 s walking window. Its Moved clock waited for a Climbing run at a spot where the body stands. 12 Studio calls proved nothing.
- **Do instead:** measure "held still" from the first frame on the ground with low speed. Judge Silent from 1 s after the stall starts. Start a timing clock at the stall when the body doesn't climb. A job's pass rule is read against how the body really reaches the spot (standing, climbing or falling) before its first paste, and the dry start prints the pose the body stalls in, so a rule that needs a pose is checked before the long run.
- **Who checks:** `code_lead` (job review, Lesson 76).

## Lesson 122: A move's grace lasts until the body is on the ground and still
- **What happened:** The notch rerun (Task 12b-1) held and landed every rescued player correctly, but the meter rose after every rescue, once by a whole thud (+35). The server places the body 0.5 studs up, and `PlayerTracker.moved` ignored the move for one tick only. The drop lasted several ticks, so the landing detector saw "in the air, then on the ground" and paid a thud, which Rule 31 (Being stuck is silent) forbids.
- **Do instead:** when the server moves a player, keep the "this was a move, not a step" grace until the body is on the ground and still (with a time limit), never for a fixed single tick. Test it with a body that falls over several ticks.
- **Who checks:** `code_lead` (plan and review), `builder` (tests).

## Lesson 123: A Play job always judges a rescue that happens
- **What happened:** Task 12b-2's beard job returned "NOT REACHED" when the body stalled 5 studs from the planned wedge point, even though the server rescued all 5 walks. Moved, Held, Egg and landing were never judged, and the beats were lost when Play stopped. The planned point had been measured beside a trial box that was later removed.
- **Do instead:** once a rescue (or any game signal the step proves) fires, the job judges every check on it, whatever the place. The planned point is a separate printed check, never a gate in front of the judging. Results a later ruling may need are printed in the job's summary before Play stops, not kept only in `shared`.
- **Who checks:** `code_lead` (job review, Lesson 76).

## Lesson 124: A job that carries an egg grabs from a held start and prints why the egg left
- **What happened:** Task 12c's last run grabbed the Rare from a start marked "(not a start)", which had slid 7.2 studs in the dry start before. The body fell, a second grab took the Rare, and 2.4 s later the egg was gone before any beard try. Nothing printed which of the 5 ways to drop an egg fired, so nobody could say if it was the job or the game.
- **Do instead:** a grab's start is a start: it held still in an earlier dry start, and the handoff line says "held N in <task> dry start". Every Play job that carries an egg adds one Server watcher that prints the time, the reason and the garden whenever `Carrying` changes.
- **Who checks:** `scripts/job-check.sh --handoff` fails a grab with a position and no "held N"; `code_lead` checks the watcher (job review, Lesson 76).

## Lesson 126: Mute in the game, never the Mac
- **What happened:** Task 13 step 5b's handoff said "Sound muted" and didn't say how, so the Play builder ran the Mac's AppleScript mute command. That can pop up macOS prompts Adam would have to answer.
- **Do instead:** a Play job mutes only the game's own sounds, from its Client paste (the "Muting the sound in Play" steps in `docs/progress/index.md`: a SessionMute SoundGroup at Volume 0). Every handoff that says "muted" points to those steps.
- **Who checks:** `.claude/hooks/no-osascript.py` refuses the command for every agent; `code_lead` checks the handoff wording.

## Lesson 127: Check every start again after a start-check change
- **What happened:** Task 13 step 5b's grab start was marked "(runtime pick)". The names check only proved the name existed. Task 12i had made `StartCheck.nearSpot` stricter since that start was last tried, so the job found no start and stopped before testing anything (6 Studio calls).
- **Do instead:** every Play handoff's names check runs `nearSpot` on each start row in Edit (one read-only call), and the row says "open in Edit" or "held N in <task> dry start".
- **Who checks:** `scripts/job-check.sh --handoff` refuses a start row with neither (setup change, with a fixture test).

## Lesson 128: Measure "home" against the spawn spot, not a box near it
- **What happened:** Task 13's Play job judged "went home" by the plot's GardenVolume box. The home spawn sits 44 studs along the box's Z, outside its 29.9 reach, so two deaths that did go home were marked fail.
- **Do instead:** "home" is within 4 studs (flat) of the own plot's SpawnSpot. Before a job relies on a box, check the spot it expects is inside it.
- **Who checks:** `code_lead` in the job review (Lesson 76).

## Lesson 129: Fakes must spawn bodies in the engine's order
- **What happened:** Task 13's unit tests were green, but in Play the new body after a fall stayed on the home spawn. The fakes fire CharacterAdded with the body already in the world; the engine fires it before the body is put in the Workspace, so a deferred move can run too early.
- **Do instead:** a test of anything placed on respawn puts the fake body into the world after CharacterAdded, and checks the move happens after that.
- **Who checks:** `code_lead` when reviewing respawn tests.

## Lesson 130: Re-prove only what failed
- **What happened:** after Task 13's 5d Play, the planned re-proof would have run all three deaths again, though deaths B and C were already measured correctly and only the job's check was wrong.
- **Do instead:** a re-proof Play covers only the rules that failed on the feature. The rest are accepted from the failed run's measured lines.
- **Who checks:** `product` when ruling on a re-proof, and `code_lead` when sizing it.

## Lesson 131: Measure a move right after a spawn before the first fix
- **What happened:** Task 13's move of a new body after a death failed three Plays (49 Studio calls, about 25 planned). Each fix was a guess about engine timing, and the tests' stand-in bodies couldn't show the real order.
- **Do instead:** for any move right after the engine spawns a body, measure it in Play first (position and who runs its physics, every frame for 1 s), then fix. If the task's size can't hold that, move the feature to a later spec.
- **Who checks:** `code_lead` when planning the task, `product` when ruling on an overrun.

## Lesson 133: Compare decimal settings as "close", never "exactly"
- **What happened:** Task 14's look test checked a puff's light setting with `toBe(0.6)`. Roblox stores that setting as a less exact number (a 32-bit float) and read it back as 0.6000000238, so a correct puff failed the green run and cost one more full run.
- **Do instead:** any setting that isn't a whole number is compared with the spec's `close` helper or `toBeCloseTo`, never `toBe`.
- **Who checks:** `builder` when writing the test, `code_lead` when reviewing the tests before the red run.

## Lesson 134: Studio's console never shows an analytics event's name or values
- **What happened:** Task 15's Play step was meant to read three "Unstuck" lines in the console. Studio printed each custom event only as "AnalyticsService: LogCustomEvent event fired.", with no name and no fields, so the values could not be seen in Play.
- **Do instead:** a Play step that proves an analytics event checks only how many of those lines appear and when (next to the job's own lines). The event's name and values are proven by unit tests.
- **Who checks:** `code_lead` when writing the Play step's pass list.

## Lesson 135: A red pass rule quotes the real error and counts the failures
- **What happened:** Task 15's red run failed exactly the 13 new tests, but the Haiku runner called it "not a pass". The handoff said the tests fail "on the missing `unstuck`", while Roblox printed "attempt to index nil with 'Connect'". The run report also lists only about 4 failed names, then "and N more", because Studio cuts a result at 1024 characters.
- **Do instead:** a red step's pass rule gives the exact error text Roblox will print, and the expected number of failures (the new tests) with the old passed total. The runner checks the count first, then the names it can see.
- **Who checks:** `code_lead` when writing the handoff, `scripts/job-check.sh --handoff` cannot see this.

## Lesson 136: A Play job with a pause for every shot is planned in two parts
- **What happened:** Task 16's handoff planned one Client paste for a Play job with five moves and four shots. Each shot needs a pause and a "go on" step, so the script reached 464 lines, over the 300-line limit (Lesson 63). The builder split it into helpers and the flow, which added one Studio call to each Play step (2026-11-01).
- **Do instead:** a client Play job with more than two shots is planned from the start as two pastes: the helpers (which return "LIB READY"), then the flow. The handoff counts both pastes in the step's Studio calls.
- **Who checks:** `code_lead` when writing the handoff.

## Lesson 137: A rounded number is checked over a span, never tick against tick
- **What happened:** Task 16's session test compared the stuck meter between two ticks in a row, within 0.001. The meter drains 0.15 a tick but is shown rounded to 0.1, so the change seen each tick goes 0.1, 0.2, 0.1, and the test failed with nothing wrong (2026-11-01). The red run hid it, because the test failed earlier on the planned break.
- **Do instead:** check a rounded number over a whole span against the expected change (start value minus rate × ticks), with the rounding at both ends as the margin. Keep the margin smaller than the smallest change the rule forbids.
- **Who checks:** `code_lead` when writing a test's pass rule in the handoff.

## Lesson 138: A Play job holds a prompt only after the game shows it
- **What happened:** Task 16's Play job held the Rare egg's prompt after a fixed 1 s wait. It passed on the computer but got "Carrying = nil" on the iPhone 14. It recorded nothing about why, so code_lead couldn't find the cause from the code, and the rerun went to product past the plan (2026-11-01).
- **Do instead:** a Play job waits for the game's own `PromptShown` for that prompt before it holds. It prints when the prompt was shown, its input type, the distance, when the hold began and when it triggered, with times, so one failed run is enough to tell a late prompt from a missing one.
- **Who checks:** `code_lead` when reading a Play job before its first paste (Lesson 76).

## Lesson 139: A grab job faces the prompt before it holds
- **What happened:** Task 16's Play job teleported the player next to the Rare egg without turning the player or the camera. On the narrower iPhone 14 view the egg was off screen, and Roblox never showed its prompt ("NEVER SHOWN", 3.26 studs away). On the wider computer screen it passed (2026-11-01). Roblox uses the camera direction to choose which prompt to show.
- **Do instead:** every Play job that holds a prompt first faces the player and the camera toward its part. It prints whether the part is on screen before it holds.
- **Who checks:** `code_lead` when reading a Play job before its first paste (Lesson 76).

## Lesson 140: A probe records whether a prompt is shown right now
- **What happened:** Task 16's phone probe cleared its "shown" record between stages. The prompt stayed shown from stage 1, so no new `PromptShown` arrived, and stage 2 read "shown false" while the prompt was really on (it triggered in stage 3). code_lead had to rule on a misleading line (2026-11-01).
- **Do instead:** a probe tracks whether a prompt is shown now (shown, and not hidden since), never "a new shown since the last stage".
- **Who checks:** `code_lead` when writing a probe, and when reading a Play job before its first paste (Lesson 76).

## Lesson 141: A shot camera looks at the prompt from the side
- **What happened:** In the Task 16b phone probe, the game drew the grab pill: 44 px tall, on, with its egg's point in the middle of the view. But the shot showed no pill (2026-11-01). It was first put down to the camera sitting behind the player, with the body covering the egg. Lesson 143 showed the real cause: `screen_capture` doesn't draw always-on-top billboards. A billboard's `AbsolutePosition` reads 0,0, so where it sits on screen can't be read from it. Task 16b closed on a hand check instead of a proof.
- **Do instead:** a shot job aims its camera at the prompt's part from the side, with nothing between the camera and the part. It finds where a billboard sits on screen from its adornee's screen point, never from the billboard's `AbsolutePosition`, and checks that point against the shot.
- **Who checks:** `code_lead` when writing a probe, and when reading a Play job before its first paste (Lesson 76).

## Lesson 143: Screenshots don't draw always-on-top billboards
- **What happened:** The grab pill never appeared in any shot (Tasks 7c, 16 and 16b, and build review Part 1), while probes found it built, on and inside the view. The build review almost failed the grab as "no pill". An A/B job proved the cause on 2026-11-01. Shot A, with the pill as built (`AlwaysOnTop` true), showed no pill. Shot B, from the same camera with the live pill's `AlwaysOnTop` set to false, showed it. Spot labels with `AlwaysOnTop` false showed in every shot. The Task 25 handoff had noted this limit, but it never became a lesson.
- **Do instead:** a shot job that has to show an always-on-top billboard sets that billboard's `AlwaysOnTop` to false while Play runs, never in `src/`, and aims the camera from the side so nothing covers it. A missing billboard in a shot is never judged a game bug until this flip has been tried. The player's own eyes at the gate stay the final check.
- **Who checks:** `code_lead` when writing a shot job, and `product`, `designer` and `game_creator` when judging shots.

## Lesson 144: A job that reuses a shared check prints why it refused
- **What happened:** Build review Part 5 re-walked 9 step-off legs with the bot-walk job from Task 8b. Task 12i (Lesson 125) had since made `StartCheck` refuse starts on floors steeper than about 49 degrees, so 139 starts came back "not open" (2 in Task 8b), and 4 of the 9 legs never walked. The server printed only the count, so the cause had to be worked out afterwards. The same job also called every failed leg with no rescue "stuck", though #150 was still falling at 8 studs a second (2026-11-01).
- **Do instead:** a job that reuses a shared check prints the reason for each start it refuses. A re-walk starts from the start the earlier run walked from. A leg is called "stuck" only by Rule 22 (What counts as stuck), never because it failed.
- **Who checks:** `code_lead` when writing or reusing a job; `scripts/job-check.sh` when it can.

## Lesson 146: A Play proof recreates the bug shot's camera
- **What happened:** Task 56 Step 1 measured the phone grab pill with the default camera and found it 74-80 px clear of the footprints chip, so the cause wasn't confirmed. The bug shot (build review p2-05) came from a low, close camera turned up at the sky. The step's pass assumed the default camera would put the pill where the bug shot showed it (2026-11-01).
- **Do instead:** before writing a Play pass, check that the step's camera and spot really recreate the bug shot, and hold that camera on purpose (for example, a camera bind on RenderStepped). Count the device set and reset in the step's calls (Lesson 89).
- **Who checks:** `code_lead` when writing a Play step; `scripts/job-check.sh --handoff` for the device calls when it can.

## Lesson 147: A test on a pixel line works its numbers out from the line
- **What happened:** Task 56 Step 4's test "follows again past the 84 px line" put the pill's point at y 290 by eye. The box bottom was 312, but the line was at 388 - 84 = 304, so the code was right and the test failed. The step was at its tool-call cap and couldn't fix it (2026-11-01).
- **Do instead:** in a test that puts something on or past a pixel line, compute the position from the line in the test itself (for example `viewportHeight - Layout.pin.unpin - halfHeight`), never a typed-in number. Size a step with a red, a green and more than 5 files as two steps.
- **Who checks:** `builder` when writing the test; `code_lead` when sizing a step.

## Lesson 148: A Play step's camera is worked out from the screen point it must give
- **What happened:** Task 56 Step 6's camera (5 studs behind, 1 below, 25° up) was copied from the words describing shot p2-05 and never checked against the phone's view. It put the egg's point about 68° below the view centre, but a phone sees only about 35° below centre, so the point was off the screen and no prompt showed. The start on the egg's round top also slid 5.8 studs, as Step 1's start had slid 3.3 (2026-11-01).
- **Do instead:** aim the camera at the target, then tilt it by the angle that puts the target at the wanted screen y, and print that y before any shot. Never start a Play proof on a round or sloped top: start from `StartCheck.nearSpot` (Lesson 120).
- **Who checks:** `code_lead` when writing a Play step; the builder's dry-start call prints the y.

## Lesson 149: A phone press is aimed from the game point, and its landing is checked
- **What happened:** two phone holds on the pinned "Hold to Grab" pill (Task 56 Step 6 and product's Part 2) did nothing, and the first looked like a game bug. product put a listener on the input (it only records, it changes nothing) and found the tool's presses arrive as touch, but 58 px too low: the aim added Roblox's top bar (58 px), which the tool already allows for. The right aim is the button's game point plus (47, 0). Aiming from the shot is wrong too, because the shot is scaled about 1.44 times (2026-11-01).
- **Do instead:** in any phone press or thumbstick test, aim at the button's or thumbstick's game point (its AbsolutePosition and half its AbsoluteSize) plus (47, 0), never from the shot's picture and never with the top bar added. Before judging a press that "did nothing", log where the first press landed with a listener that only records.
- **Who checks:** `code_lead` when writing a Play step with a phone press; the builder prints where the press landed.

## Lesson 150: A pill beside the egg is aimed from the egg, or pinned first
- **What happened:** in product's review Part 2f, the "Hold to Grab" pill showed whole beside the egg, but a 2.6 s hold missed. The pill sits on a billboard, so its position (30, 8) is its place inside the billboard, not on the screen. The aim came from the shot instead, and the camera turned between shots. No egg was carried, so the wedge-and-rescue check couldn't run (2026-11-01).
- **Do instead:** to hold a pill that follows the egg, aim at the egg's anchor point on screen (`Camera:WorldToViewportPoint`) plus the pill's offset, with the camera held still. Or pin the pill first (camera low) and hold its known point. Print the carry state ("Get it home" chip) before any step that needs the egg carried.
- **Who checks:** whoever writes a Play job with a grab; `code_lead` for a builder's handoff.

## Lesson 151: A full-run pass line names only what the fetch prints
- **What happened:** Task 57 Step 2's pass line asked for "the stuck scan's line unchanged". It was copied from Task 56's plan, but the full run's fetch prints only counts, so the runner had nothing to match. It was the second pass rule worded differently from what the run really prints (the first was Task 15 Step 2's red error) (2026-11-01).
- **Do instead:** word a full-run pass line only from what `scripts/studio/full-run-fetch.luau` prints: "N passed, 0 failed", "could not run", the spec-file count and the failing test names. Check it against the script, never against an older step. `scripts/job-check.sh --handoff` now fails a full-run pass line that names a line, a scan, a print or a quote. Never name world parts either: the fetch cuts each failure's text short, so Task 58 Step 2's "for CapLadder and BeardLadder" couldn't be checked (third time, 2026-11-01). The check now also fails a full-run pass line with a CamelCase name that isn't a spec file.
- **Who checks:** `code_lead` when writing a full-run step; `job-check.sh --handoff` before the runner starts.

## Lesson 152: The always-on-top flip is for shots only, never before a touch hold
- **What happened:** in product's review Part 2d, a phone hold on the pill beside the egg was aimed right, but an input listener showed the touch landing on the world. The shot setting from Lesson 143 (the pill's `AlwaysOnTop` set to false) was on. With it off, the same hold grabbed at once. This also explains the Part 2f miss (2026-11-01).
- **Do instead:** use the Lesson 143 flip only in shot jobs with no input. Before any touch hold or press on a billboard, set it back to the built value, and say so in the job.
- **Who checks:** whoever writes a Play job with a press; `code_lead` for a builder's handoff.

## Lesson 154: A handoff that grows a job file near 300 lines plans its split first

Task 58b Step 1 added a rule to a 287-line world script. It reached 401 lines, job-check failed at the very end, and the step ran out of calls before it could split it (Lesson 63 sets 300 lines per job file).

- When a step adds to a job file over about 200 lines, the handoff says how the file is split before the builder writes.
- A world script in `tools/` is never split into `--joined` parts: `scripts/check.sh` lints each `tools/` file by itself, so a part that uses another part's names fails. Move helpers into a module the pasted script loads as a fresh copy (as `15-real-shape/Run.luau` does).
- The builder counts lines against 300 while writing, not only at the final check.

## Lesson 155: The fetch names every failure first

Task 58b Step 2's red run had 5 failures, but the fetch gave each one a 150-character message, so only 3 names fit in the report and the rest were "and 2 more". The pass rule ("nothing else fails") couldn't be checked, and the red had to be run again.

- The full-run report lists a name line for every failure first, then adds messages in the room left.
- "and N more" appears only when even the names don't fit.

## Lesson 157: A part pasted with the one before it is linted with it

The Task 58b trial script was 348 lines, so it was split into two parts pasted together in one call. `job-check.sh --joined` linted each part alone, so part b failed selene with 26 "not defined" errors for names part a declares. The same gap had blocked a split in `tools/` before.

- A part that starts with `--!strict` is its own paste, and is linted alone.
- A part that doesn't start with `--!strict` goes in the same paste as the part before it, and `--joined` lints them joined.

## Lesson 158: Write a full-run pass line with no quote marks

In the Task 58b step-trial handoff, `job-check.sh --handoff` rejected the full run's pass line because it had quote marks round "N passed, 0 failed". The check treats any quote mark on a full-run pass line as a printed name (Lesson 151).

- Write it bare: Pass: N passed, 0 failed.

## Lesson 164: The 300-line job cap is for work/ jobs, not world scripts

In Task 58b, `job-check.sh` failed `tools/world/18-upright-ladders.luau` (546 lines) on Size. The 300-line cap (Lesson 63) keeps a pasted trial job small. A world script in `tools/world/` is a kept file, so the project's 1000-line file rule applies instead.

- `job-check.sh` checks files under `tools/world/` against 1000 lines, and `work/` jobs against 300.

## Lesson 165: A names check prints each copied template's shape

In Task 58b Step 2, `18-upright-ladders.luau` stopped on its own guard because the ladder's Rail is a Cylinder, and the script took every template for a Block. The names check (Lesson 61) had listed parts by name and kind, but not by shape.

- When a world script copies a part's look, the names check also prints that template's ClassName, Shape, Size and turn.
- World scripts size a Cylinder along its X axis (its length), and turn it to point the way the plan needs.

## Lesson 166: A world script checks itself read-only before its first Play paste

In Task 58b Step 2, `18-upright-ladders.luau` stopped twice in Play on a wrong guess about a part already in the world. First the ladder's Rail was a Cylinder, not a Block. Then the nest Model's real name was `"nest"]`, not `nest`. A separate names check (Lessons 61 and 165) guesses again at what the script looks up. Only the script's own guards are the full list.

- Every world script that edits existing parts has a `CHECK_ONLY` switch. With it on, the script runs every lookup and guard, prints "CHECK ONLY ... passed", and changes nothing.
- Before its first Play paste, it runs once read-only in Edit (Haiku, 1 Studio call), as its own handoff step.
- `job-check.sh` fails a new `tools/world/` script with no `CHECK_ONLY` line, and warns for older ones.

## Lesson 168: A noise trial waits for a calm meter before each measure

In Task 58b Step 2, the climb trial read noise as "highest minus start". While the meter was falling, that read 0 for real noise. And because the meter was never let down between tries, the giant woke during the long trial and sent the body far away, which counted as 2 failed climbs.

- Before each noise measure, wait until the meter is under 5.
- A body more than 20 studs from the test spot is SENT AWAY: log it, and retry the try once. Never count it as a fail.
- Split a step's rise into its parts (for example, the end of the climb and the landing), so a loud part can be named.

## Lesson 169: A fetch reads the same `shared.` name its job writes

In Task 58b, the rerun jobs wrote `shared.T58bRerun`, but their fetch was copied from the old trial and still read `shared.T58bUp`. Every fetch would have said NOT STARTED, and job-check missed it. code_lead caught it while reading the jobs before the paste.

- When a job is copied into a new job, rename its `shared.` name in the fetch too.
- job-check compares the `shared.` names a job writes with the names its fetch reads, and fails if they don't match.

## Lesson 170: A noise trial watches the meter for 3 s after the player stands still

In the Task 58b rerun, the beard slip read as quiet (6.2). But the game only counts a thud (the noise when a fall ends) after the player has been at rest for 0.3 s, and then the meter updates. The job had already stopped watching, so a loud slip passed.

- Every noise measure that ends at a landing keeps watching the meter for 3 s after the player stands still, and reads the highest value.
- Before setting a noise bar, check the game's own noise rule. A slip is a jump, and every jump makes a thud of 20 times the zone's multiplier.

## Lesson 171: A fall caught by a ladder is not a fall

In the Task 58b cap trace, the player slipped off the front of the truss top, grabbed the ladder again and climbed back up. The server checks the ground with a ray straight down. While the player was back on the ladder, that ray hit the deck 25 studs below, so the slip and the climb back counted as one fast fall. It thudded (made a landing noise) of 62.3, when no thud should have happened at all.

- A fall-end check that uses a downward ray also watches the Humanoid's state: entering Climbing cancels the fall.
- When a ladder top is loud, rule out the noise code before reshaping the ladder. Here the world had no gap, and changing it would not have helped.

## Lesson 172: Putting a task's code back also puts its world back

The first try at Task 58b was dropped, and its code files were put back to Task 58's commit. But the shorter side walls it built stayed in the edit world. The next full run then showed changed reds, with a new count and new problems, and nobody could tell at first where they came from.

- When a task's code is put back, put its world changes back too, or write them down in the progress row.
- Before the next full run, check the edit world against what the last commit expects (a read-only names check).

## Lesson 174: A job script is pasted as written, comment lines aside

In Task 58b's beard slip rerun, a builder retyped the job scripts without their comments to save memory. The output matched, but a retyped paste is not the text `code_lead` checked (Lesson 76).

- Paste each job file as written. Only whole comment lines may be left out.
- Never change, move or drop a code line.
- The report says when comment lines were left out.
- **Who checks:** `builder`, `runner`, `code_lead` (in every Play prompt).

## Lesson 177: A run report lists every failed name before any message

In Task 58b's red run, the fetch showed 7 of 11 failed tests, then "and 4 more". So 4 new tests were never seen red. That was the second time the report's size cap hid names.

- The fetch prints every failed test's name, uncut, before any error message text.
- The size cap applies only to the message text after the names.
- A red step that can't see every new test's name is not a red. The run is fixed first.
- **Who checks:** `code_lead` (when judging a red run), `runner` (reports a cut list as a question).

## Lesson 178: A script is pasted as the text of one Studio call, never loaded from elsewhere

In Task 58b Step 5, the main chat's prompt said "paste a big script with the shell". No tool can do that. So the builder ran a local web server, turned on the place's HttpEnabled and loaded the scripts from it: 2 extra Studio calls and a place setting changed for a moment.

- A pasted script goes into `execute_luau` as its own text. Only whole comment lines may be left out (Lesson 174).
- Never load a script over HTTP, or turn on HttpEnabled or a similar setting, to paste it.
- If a script is too big for one call, the handoff splits it into parts (Lesson 154). The agent never invents a way round it.
- A prompt only names ways of working that a tool really has.
- **Who checks:** the main chat (in every prompt), `code_lead` (in handoffs), `builder`.

## Lesson 182: A run report pages every failed name and keeps its results until the end

In Task 58b's Step 6 run, 5 of 13 failed names were hidden again: the third time. The report's size cap dropped names ("and N more"), and the fetch that saw "done" removed the results folder, so nothing was left to fetch. Studio also cuts any result at 1024 characters.

- The report pages: every failed name comes before any message, and no page says "and N more".
- A page that isn't the last ends with "fetch again". The runner fetches again until a page ends with "end of report".
- The results folder is removed only after the "end of report" page.
- Lesson 177 said what to show. This lesson is how: the same kind three times means the cause gets fixed in the fetch script and its tests, not worked round.
- **Who checks:** `code_lead` (when judging a run), `runner` (fetches until "end of report").

## Lesson 183: Check the sync of a script whose name has a dot with script_grep

In the fetch-names fix Step 1, `script_read` couldn't find `BackgroundRun.spec`, because its name has a dot. The builder tried other ways and went over its Studio cap (8 calls against 3).

- A sync check of a script whose name has a dot (every `.spec` file) uses `script_grep` for a line that was just changed.
- Handoffs and prompts name `script_grep` for such checks.
- A red step budgets one re-run, in case a new test passes by accident the first time.
- **Who checks:** `code_lead` (in handoffs), the main chat (in prompts), `builder`.

## Lesson 185: The runner reads a script before its Studio call, and never sends a placeholder

Twice in Task 58b a runner (Haiku) made a Studio call that did nothing: in Step 4 a comment-only script, and in Step 7 the word "placeholder" sent before it had read the fetch script. Each one is a wasted call, and a cheap model is more likely to do it.

- The runner reads each script file in its own call first, then pastes that text into `execute_luau`.
- Every Studio call carries a whole script the prompt names, never a placeholder, a comment-only or an empty one.
- The rule is in `.claude/agents/runner.md`, step 3.
- **Who checks:** `runner`, the main chat (counts the runner's Studio calls in each report).

## Lesson 186: A measure job keeps the whole message of the one test it needs

In Task 58b the stuck scan's test message listed its stuck spots after the first 150 characters. The full-run fetch cuts each message short, so the spots were cut off, and a second job had to measure them again.

- A job that needs a test's details (positions, names, counts) runs that one test and keeps its whole message, not the run report's short form.
- The short form is for pass and fail lines only.
- **Who checks:** `code_lead` (when it writes a measure job).

## Lesson 188: A red run filters to the step's own tests, and its cap counts every page

Twice on 2026-11-02 a builder's red step went over its Studio cap. In Task 58e Step 2 the builder ran the wide "RealWorld" filter, so the report came in 3 pages, each one a fetch the cap didn't count. The failure messages were still cut short, so it ended with 3 questions instead of fixes.

- A builder's red run uses the narrowest filter: the step's own spec names, so the report fits on one page and keeps each failure message whole.
- A handoff step's Studio cap counts one fetch per report page it expects.
- The rule is in `.claude/rules/agent-workflow.md`, "Ready-made run scripts".
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 189: A cut failure message hides the next offender

In Task 58e Step 4 (2026-11-02), the egg-spot test "no egg stands inside a prop" still failed after Rare egg 3 was moved. Rare egg 4 had been inside the FootLedge since Task 58b, but the failure message was cut at 150 characters. The test runner's fixed header used about 100 of them, so only the first egg's name ever showed. Rare egg 4 stayed hidden behind Rare egg 3 for a whole task.

- When a test lists every part that breaks it, the report must show the whole list. Drop the test runner's fixed header before cutting the message.
- After fixing the first part on the list, measure all of them again before calling the fix done.
- **Who checks:** `code_lead` (in the handoff and review), `builder`.

## Lesson 190: Run a world script by requiring its synced copy, never by pasting it

In Task 58e Step 4b (2026-11-02), a builder read tools/world/08-route.luau (986 lines) whole only to paste it into Studio. Reading it and pasting it cost about 30k tokens, and the builder ran out of memory before its test runs.

- To run a world script, use one execute_luau call: `require(ServerStorage.Tools.world["<name>"]:Clone())`. First check the sync with a short script_read.
- Read a world script only to edit it, and then only the lines you need.
- Handoffs say "require a clone of its synced copy", never "paste script NN".
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 195: A world script that removes parts saves a copy of them first
- **What happened:** world script 18 removed the side trusses, side walls and old ladder parts with no undo. When the red alert sent the face ladders back (2026-11-02), the revert had to rebuild them from older build scripts and the last commit.
- **Do instead:** every world script that removes or replaces parts first saves a copy of what it removes in `work/<task>/` (or keeps it in ServerStorage), so going back is one step.
- **Who checks:** `code_lead` (handoffs with a world change), `builder` (writing the script).

## Lesson 205: Write test names in a Pass line without quote marks
- **What happened:** a full-run pass line that named a test in quote marks failed `scripts/job-check.sh`, which rejects any `"` in a Pass line (2026-11-02).
- **Do instead:** write failing test names in Pass lines without quote marks.
- **Who checks:** `code_lead` (handoffs and runner jobs).

## Lesson 222: Give a walk bot measured waypoints, and start spots that have a floor
- **What happened:** climb test job 1 sent the walk bot from the belly to the pillow with no waypoints. Pathfinding took it over the outer shoulder and down the arm, so it looked like the route was blocked. code_lead measured a height map and found a walk with no step over 1.4 studs. Two start spots were guessed: one over a steep plate, one under the cap (2026-11-02).
- **Do instead:** before any walk test, measure the route (height map plus route search) and give the bot those waypoints. Every start spot comes from a measured floor hit, and the job loads the area first, because the place streams parts in only near the player.

## Lesson 223: A job script's background loop stops on a flag, and a walk script sets the real walk speed
- **What happened:** climb test job 1c started a 30-second background loop that set the walk speed to 0 at its end. The left walk didn't finish, so the loop kept running into the right side, froze the right walks, and the stuck safety then moved the player. It looked like a route fail (2026-11-02).
- **Do instead:** every background loop in a job script stops on a flag that the clean-up script sets. A walk script sets the real walk speed from `Config` itself, never a value it saved earlier.

## Lesson 224: Walk tests on the giant hold the sleep meter at 0 and log any move the game makes
- **What happened:** job 1c's walks ran with the wake rule live. Three bot walks filled the meter, the giant woke and bounced the player to the ground, and it looked like a fall off the cap (2026-11-02).
- **Do instead:** a walk test that isn't testing noise holds the sleep meter at 0 for that Play session only, and logs any jump over 10 studs in one frame as "moved by the game".

## Lesson 225: Smoke-run the first case of a Play job before the job runs
- **What happened:** three climb-test jobs in one day failed before testing anything. Each was written from facts nobody had run in the game: guessed start spots (job 1), a loop left running and a wake (job 1c), and a mockup built for looks that no player could climb (job 2a: the bottom rungs lean over the head, and the cap's side sits outside the upper rungs). About 65 tool calls were spent with nothing tested (2026-11-02).
- **Do instead:** before a Play job runs, a builder runs its first case once, on one side, using the job's own scripts in order (about 6-8 tool calls). Pass: the player climbs 5 studs or reaches the first waypoint, the giant stays asleep, and no loop is left running. The job starts only after this smoke run passes.

## Lesson 226: Test movement only on the real build, and build one side first
- **What happened:** the cap ties' mockup was built for looks and then used as a climb test. It could not be climbed, and a pass on it would not have proved the real build anyway. Fixing the mockup first would have cost about 100 tool calls before the real build (product ruling, 2026-11-02).
- **Do instead:** a mockup is for looks only. Climbing, walking and slipping are tested on the real build. When a pair is built (left and right), build one side, climb-check it, then mirror it, so a finding reworks one side, not two.

## Lesson 228: In scripts, put a type cast in a local variable, never at the start of a line
- **What happened:** StyLua joined a line that started with `(x :: Instance)` onto the call on the line above. The script broke with no lint error, and the builder had to find it by hand (Task 61a step 1, 2026-11-02).
- **Do instead:** write the cast as `local x = y :: Instance` and use `x`. Never start a line with `(`.

## Lesson 241: Measure each limit only over the zone its pass line names

In the Task 61a gate, the "Rails hold" line was about the railed strip (y 100 to 110). But the job kept one running maximum up to y 111, past the rails' top, and logged no height. So nobody could tell where the 6.17-stud drift happened, and the gate's result was unclear.

**Do instead:** a job measures each limit only over the zone its pass line names. It also logs the height where the limit is first crossed.

## Lesson 247: A task that changes the world ends with a full run before its accepted reds are final

Task 60 moved the face ladders and listed its accepted reds (tests expected to fail until a later task) from narrow runs only. Five world reds it missed first showed up in Task 61d's full run, so 61d's review had to sort them out.

**Do instead:** a task that changes the world runs the full test suite before it closes. Its accepted-red list is written from that full run, with each red's later task named.

## Lesson 248: A rule that quiets some climbs names the parts it covers, not only the zones

Task 61d's handoff said a fall "straight from a climb" is quiet, without saying which ladders. So any climb counted, including a boot ladder. The fix then keyed on zones only (Nightcap or Beard), which left a player who climbs a cap tie from its foot and lets go low still thudding. That needed a new task (61h).

**Do instead:** a rule that changes what happens after a climb names the parts it covers (for example "the two cap ties"), and the code checks those parts, not only the body zones.

## Lesson 249: A look-only part can't be found by rays, so tests measure it from its shape

In Task 61a the tie's straps were made look-only (CanQuery off, so rays pass through them). A test that found the strap's face with a ray then hit nothing, and failed for a reason that had nothing to do with the climb.

**Do instead:** when a task makes a part look-only, check every test and script that measures it with rays first. Measure such a part from its position and size (`CFrame` and `Size`), not with a ray.

## Lesson 250: Before naming a world script as a fix, match what the test reads with what the script writes

Task 61g was planned to run script 11a, picked because it works on every `Mockup_` folder. But the failing mockup test reads `MockupTransparency` (the saved look), and 11a only saves the collision values. 11a said "already done", the test stayed red, and code_lead had to find the cause.

**Do instead:** before a plan or review names a world script as the fix for a red test, list the attribute or property names the test checks, and check that the script writes those exact names.

## Lesson 251: A fix for a red test covers every kind of object the test checks

Task 61g's first copy script fixed only the mockup's parts, the kind the cut-off failure line listed. The test also checks effects (lights, sparkles, labels) and avatars, and 10 egg effects still had no saved value. The test stayed red for a second run.

**Do instead:** before writing a fix, read the test and count every kind of object it checks, in one read-only call. A runner's report copies a failing test's whole message, never only its first line.

## Lesson 252: Check a job's scripts as script files, not its written page

Task 61a's climb job was checked with `scripts/job-check.sh` straight on its `.md` page. The check read the plain-English text as code and failed.

**Do instead:** save each script of a job as its own `.luau` file in `work/` and check those files. Check the `.md` page with `--handoff` only.

## Lesson 253: A rescue can end a climb case on the goal without a climb

In Task 61a's climb job, cases 2 and 4 got stuck on the tie. After 3 s the game's stuck rescue moved each player to an old safe spot on the cap, so the case "ended on the cap" though the climb never reached the top.

**Do instead:** a Play job logs the position just before any move of more than 8 studs and labels it a rescue, never a pass. A climb case passes only on a logged climb to the top.

## Lesson 254: The smoke run runs every script of the job once

Task 61a's smoke run covered case 1 only. Script X (a stand-in second climber) was new and first ran at case 5, where its guessed wait spot never caught the climber.

**Do instead:** the smoke run runs every script of a Play job at least once, including a script that starts only in a later case. Every spot or line a script waits for is measured from a real run (Lessons 26, 219 and 225).

## Lesson 255: Compare two sides of a slope at the same spot, with the added part left out

In Task 61a, code_lead compared the cap's slope on the two sides of the tie at different x, with the tie inside the measure. One side looked steeper (69-70 degrees against 58-62), and product almost ruled the tie unfair. Measured again at the same x with the tie left out, both sides match within about 3 degrees.

**Do instead:** compare two sides at the same x (or the same distance along), and leave the new part out of a measure of the ground under it.

## Lesson 264: Read a tool's real limit in its code before a lesson relies on it

Lesson 188 promised that a narrow run keeps each failure message whole. In Task 61a Step 3b, the report still cut the seam test's message short. code_lead found the cut in the test runner itself (`WHY_LIMIT = 150` in `src/tests/BackgroundRun.luau`), not in the fetch script, so Lesson 188's promise was never true.

**Do instead:** before a lesson or a handoff relies on what a tool keeps or shows, find the limit in the tool's code and quote it. Until the runner keeps longer messages for small runs, put the key numbers of a failure message in its first 150 characters.

## Lesson 267: A Play climb job steers like a player when it stalls

A climb job held the stick at one angle. The character got wedged between the cap tie and the giant's head, and the team read it as a slow climb. Adam saw from one screenshot that a player would turn and try again.

**Do instead:** before calling a climb slow or stuck, measure the gaps around the climb line and take a screenshot from the player's camera. When a scripted climb stalls, it reacts like a player (turn, step back, jump, a few times). A turn that works is a pass.

## Lesson 269: A climber can't swivel round a truss with the stick

While Climbing, the engine keeps the character facing the truss: a sideways or turned stick doesn't turn him or move him sideways (measured at y 66 and y 76.8, AutoRotate on). The docs don't say this. Two trial loops left running at once also mixed their log lines.

**Do instead:** to get round a truss, test it as a player would: climb down, jump to the side, walk round, push into the other face. Finish or unbind each trial loop before starting the next.

## Lesson 276: Each walk case starts standing on the ground

A reach-walk case started with the character still hanging on the last case's ladder. The start move was over 20 studs and tripped the teleport watcher, a false fail.

**Do instead:** each walk case first moves the character to its start spot and waits for Grounded before its own start.

## Lesson 277: List every mirrored line before reusing a walk script

A walk script mirrored its spots with a sign `s` inside its own table. A copy given new spots for both sides would have mirrored the right side twice.

**Do instead:** a job that reuses a walk script lists every line that uses the mirror sign before the first paste.

## Lesson 280: A scripted press uses the walk's own input

A reach probe called `Humanoid:Move` once. The control script reset it, so the probe stopped before any walk ran (Lesson 65 was known, but nothing enforced it).

**Do instead:** a job's press uses `MoveTo`, or `Move` from `BindToRenderStep`, never a single `Move` call.

## Lesson 283: A server watcher gets its case marks through a RemoteEvent

A Play script set player attributes on the client. The server never saw them, so the meter and thud checks never ran.

**Do instead:** a server watcher gets its case marks through a RemoteEvent, and the smoke run proves it ("seen <case>").

## Lesson 284: Measure gaps to meshes with raycasts

`GetPartBoundsInBox` reports a mesh's whole bounding box, so every face of the tie looked blocked.

**Do instead:** measure the gap from a climb line to a mesh with raycasts.

## Lesson 285: Stall steering turns toward the open face

The test bot's stall steering aimed at the tie's middle and pushed him back into the hat's brim.

**Do instead:** when a scripted climb stalls, it turns toward the open face, the way a player would.

## Lesson 286: Mark "between" and settle before each teleport

A job named the next case only after teleporting the character, so a landing still settling was filed under the wrong case.

**Do instead:** mark "between" and let him settle before each teleport, then name the new case.

## Lesson 287: One sleep-meter hold per Play session, with a heartbeat

The script that holds the giant's sleep meter lived inside each run and stopped between runs. Twice the giant woke mid-trial and bounced the character, and the results looked real (a bounce looked like a bad rescue).

**Do instead:** paste one hold per Play session (`scripts/studio/session-hold.luau`) that writes a heartbeat. Every run marks itself VOID when the heartbeat is missing. Check a strange landing against the game's own landing spots before calling it a bug.

## Lesson 288: Run luau-lsp and a dry run in Edit before a trial script's first paste

Two script bugs (a function that doesn't exist and a broken compare) were pasted into Play untested, and each cost a run.

**Do instead:** run luau-lsp and a dry run in Edit on every trial script before its first paste. `scripts/job-check.sh --handoff` checks this.

## Lesson 294: A names check marks which names exist only in Play

A handoff said an Edit dry run "must find GiantState". The server makes that folder only when Play starts, so the builder spent 2 Studio calls finding out, and the step went over its caps.

**Do instead:** the handoff's world table marks each name "exists in Edit" or "made at Play by <script>". A dry run in Edit reports a Play-only name as "not found (made at Play)" and doesn't fail.

## Lesson 295: A stall with no measured cause gets a trace step first

Task 61a changed a world script before its stall had a measured cause. The fix didn't help, and the task ran about 4 hours before its first red flag.

**Do instead:** a stall with no logged x, z and touching parts gets a read-only trace step before any fix step. After its restart, 61a's trace found the cause and the task closed in 43 minutes.

## Lesson 296: Keep job scripts short from the start

One trace job grew past the 300-line job-file limit once StyLua spread its long format calls over many lines.

**Do instead:** write job scripts with short format helpers, and put the dry start and the read in their own file from the start.

## Lesson 297: A Play trace retries like a player and shows the stall

Task 61a's Step 2 trace gave up after two turns, with no step back and no shot from the player's camera, so its -20° stop couldn't be judged. This is the same kind of problem as the 2026-11-02 wedge between a ladder and the giant's head.

**Do instead:** every Play trace includes a player's full retries (turn, step back, turn again) and a shot at any stall it reports. Because it happened twice, `scripts/job-check.sh` gets a rule that fails a Play job that can report STUCK without a step back and a stall shot.

## Lesson 302: A trimmed paste voids that call

In Task 61i's Step 1 the builder trimmed the dry run and the read scripts, although the handoff said to paste each script whole. code_lead accepted the result only because the climb script itself was pasted whole.

**Do instead:** a handoff's stop rules say that a trimmed or edited paste voids that call's result. The builder pastes the script exactly as written, or stops and asks.

## Lesson 304: Use the game's own signal, and size job files before the step

In Task 61h's Step 4 the builder wrote a 649-line drop script, because it rebuilt the game's own landing check as a "shadow" copy to read the result. Reading that script cost two builders most of their memory, and it pushed the task past its planned time.

**Do instead:** before a job copies one of the game's own checks, look for a signal the game already gives (here, the console's "event fired" line). The handoff sizes every job file under 300 lines before the step starts.

## Lesson 306: A Play job's memory is mostly its pastes

In Task 61h the drop script was pasted many times, and each paste put the whole file back into the builder's memory. Two builders ran out of memory before the job ran (code_lead, 2026-11-03).

**Do instead:** a Play step's caps give paste lines (file lines times pastes). A step over about 2000 paste lines is split before it starts. Each pass item names the game signal it reads, and code_lead checks the signal with a grep before the builder writes the script.

## Lesson 307: Measure the floor under a Play case's path, and end it like a player
A case "walk off the fold" waited for a fall. Off the fold the cap is only 1 stud lower, and a Humanoid walks down that without ever being in the air. So the job pushed for 6 s, twice, and walked him 90 studs off the giant. The fix between the runs changed only the timing (Task 61h Step 5, 2026-11-03).
→ Before writing a case that expects a drop, cast rays down along its path and write the height from the start floor to the end floor. Under 2 studs it is a walk: the case ends on "on the ground, off the start part", then lets go of the stick. When a case ends far from where it should, first check whether he was ever in the air, before changing any timing.

## Lesson 309: Release the stick on the game's state, and aim every retry at what the case climbs
Task 61h case 4 failed twice from the job, not the game (2026-11-03). First the let-go push stayed held through the fall, and air control carried him 54 studs off the giant. Then the fix released the stick on a 0.3 s timer while he still hung on the ladder, so try 1 stalled with no line printed. Try 2 turned 25° off the tie, walked past it under the cap, and the held walk push carried him 140 studs onto Terrain.
→ Release the stick on the game's own state (off the ladder, or falling), never on a timer. Keep each retry aimed at the thing the case climbs, and end a try that walks past it. Print one line per try: why it ended, its start, its highest point, whether he climbed, and where it ended.

## Lesson 310: Write each pass word as the game's own value, and name a spot after the part its ray hit
Task 61h case 4 failed a third time on the job, not the game (2026-11-03). The game did all the plan asked (Belly zone, quiet, one puff), but the pass wanted "lands on the Pillow" and a "CapDrop" ending "pillow". The handoff's world row had called the belly under the tie's foot "Pillow", though its own ray hit `body_geom`, and the game's rule (`CapDrop.landing`) calls that spot "shoulders". Each fix round fixed only the item that had just failed.
→ Name every measured spot after the part its ray hit. Write each pass word as the value the game's own function returns, checked with a grep before the first run. Before every rerun, re-check the whole pass list against the plan's words, not only the failed item (rule "A pass list quotes its plan").

## Lesson 311: A push away from a Roblox ladder climbs down; trace one let-go before rewriting a climbing job
Three case-4 job fixes guessed how a held stick behaves on a ladder (2026-11-03). Pushing away from a TrussPart climbs down it instead of letting go, so the job never saw him "in the air" and called a clean landing STUCK. The end-rule fix from the round before had been applied to cases up to 3 only.
→ Before rewriting a climbing job, trace one let-go (state, y and floor every 0.1 s) and build the end rule from what the trace shows. After an end-rule fault, check every case still to run against the fix.

## Lesson 313: Budget a full run from the last run's page count
The Task 61c handoff gave the full run 2 Studio calls (2026-11-03). The last full run's report was 5 pages long, so the runner needed 1 start plus 4 page fetches and went over its cap. Lesson 188 already said to count one fetch per page, but the handoff counted one fetch in total.
→ Give a full-run step 1 start, plus 1 fetch for each page of the last full run, plus 1 spare (5 pages now, so 7 Studio calls). Its tool-call cap is the Studio calls plus 5, for the reads, the wait and the write (12 now).
Update (Task 61b Step 6, 2026-11-03): a runner at exactly that cap spent 2 calls on a Studio check and ran out before the write, so 4 fetched pages were lost (a fetched page is gone). → The runner writes each page to the file right after fetching it, never all at the end, and the tool-call cap is the Studio calls plus 7 (14 now).
Update (Task 61n Step 3, 2026-11-03): a 4-page run needed 17 tool calls against 14, because each page costs a fetch, a write and a wait, and the reads are 2 or 3. → The tool-call cap is 3 times the expected pages, plus 4 (16 for 4 pages), and the prompt asks for no extra reads (the old list of failing names goes in the prompt itself).

## Lesson 314: A shot step names the camera method that works
- **What happened:** Task 61b Step 4 went over both caps (28 of 24 tool calls, 21 of 18 Studio calls). The phone shots in Play took 3 tries, because a camera set by script doesn't show in `screen_capture`. Only `screen_capture`'s own `camera_position` and `look_at_position` arguments placed it. Phone shots also come back small (416x186 for an 840x368 simulated phone).
- **Do instead:** every handoff step that takes fixed-camera shots in Play says to pass the camera through `screen_capture`'s `camera_position` and `look_at_position`, never a script. The after shots use the same method and size as the before shots, so the pairs compare like for like.

## Lesson 315: Measure what a check's ray hits before ruling it onto a new kind of piece
- **What happened:** Task 61b Step 5a moved rung-ladder checks onto the cap ties, a near-vertical truss. The ray along `axis.back` and the ground read 1 stud past the top gave false fails: the rails "touched" the skin 19-21 times, and the top read the nightcap. The ruling was written before anyone measured the left tie, so the builder spent 3 unplanned Studio calls probing, and a second ruling round followed.
- **Do instead:** before a check is ruled onto a new kind of piece, the ruler measures what its ray really hits on the built piece (one read-only call). Where that piece already has a stricter test of its own, reuse it and skip the old one, with a comment.

## Lesson 321: A red run's report grows with its failures
Task 61w Step 1 had a cap of 3 Studio calls (2026-11-03). Its narrow red run had 17 failing tests, so its report was 4 pages long. The builder used 4 calls and still left the last page unfetched, which the next step had to clear first.
→ A red step's Studio cap counts 1 start, plus 1 fetch for about every 5 failing tests it expects, plus 1 spare. A step that inherits an unfetched page budgets one extra fetch to clear it.

## Lesson 322: StyLua makes a job file longer than you wrote it
Task 61v Step 1 (2026-11-03): a Play job written to a 220-line cap came out about 300 lines after StyLua, because it splits long `table.insert(...)` and `string.format(...)` calls at column 120 into 4 to 6 lines. The builder rewrote it twice to fit and ran out of memory before its first Studio call.
→ Write job lines short (for example `rows[#rows + 1] = ...`) and check `wc -l` right after the first save. A job a few lines over its cap is fine; only the 300-line limit is hard. A step that writes a job of more than about 150 lines gets its own step, before the Studio step.

## Lesson 323: Build each paste from the file's text, never retype a line
- **What happened:** In Task 61v Step 3 the builder retyped one expression of the Edit dry-run paste instead of copying it from the job file. code_lead ruled the dry run void (Lesson 302), though the verdict stayed the same.
- **Do instead:** every paste into Studio is built from the file's own text (read and paste whole, or cut by line numbers). Never type a line again by hand.

## Lesson 332: Play ignores a camera set once; bind it every frame
- **What happened:** In Task 61x round 2, `screen_capture` in Play used the live player camera, not the spot the job had set once.
- **Do instead:** a Play shot that needs a set view uses the ready-made Client `BindToRenderStep` camera from the look-shots job, checks the spot is off the player's facing line, and unbinds it and puts the camera back on Custom after.

## Lesson 339: Check the folder before naming a new world script
- **What happened:** On 2026-11-03 plans named world script numbers without looking in `tools/world/`. Task 5's `16-lap-landing` clashed with `16-meadow-bush`, and plan 4's `19-rank-eggs` clashes with the built `19-ways-up-ladders`.
- **Do instead:** list `tools/world/` and the other plans' script names before writing a new script number into a plan.
