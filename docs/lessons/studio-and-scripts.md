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
