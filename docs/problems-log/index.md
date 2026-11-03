# Problems log

One line for every unplanned stop: anything that halted or slowed the work and wasn't part of the plan. The main chat adds the line as soon as it happens, in the file for the area, feature or gameplay part it belongs to. **The same kind twice means fix the cause** (`agent-workflow.md`, "Learning from experience"), and the learning goes to its home: a hook, a rule, a skill or the agent's own memory (`closing-a-task` skill).

Kinds: **Rojo crash**, **Studio out of date**, **Idle turn** (nothing ran and nobody knew), **Over memory limit** (an agent went past its limit), **Script error** (a pasted script failed), **Over budget** (a task went past its planned size), **Scenery overrun** (a second task on the same scenery object), **Fix planned on an unconfirmed cause** (a fix aimed at a part nobody measured).

**How to use it.** Agents read this map and only the area files that match their work. Before logging a problem, check the "Open kinds" table: a kind already there means this is the second time, so the cause gets fixed now.

**Files by area, never by date.** One file per area of the project, feature or gameplay part, for example `world-scenery.md`, or a feature from the spec index such as `stuck-safety.md`. A problem that fits no file starts a new one, with a line in the "Area files" table. No file here goes over 1000 lines: when one nears the limit, split it into narrower areas (for example `world-scenery.md` into `the-sock.md` and `the-pillow.md`) and update this map.

## Open kinds

A kind stays here until its cause is fixed. Then its row moves to "Fixed kinds".

| Kind | Times | Last seen | Area file |
|---|---|---|---|
| A rerun rebuilt from memory | 2 | 2026-10-27 | `teamwork.md` |
| A new test hidden by the red break | 1 | 2026-11-01 | `teamwork.md` |
| A job given to an agent without its tools (cause fixed: `job-check.sh --handoff` fails a Haiku step that needs shots, Play or input) | 2 | 2026-11-03 | `teamwork.md` |
| A second task on the same object (ladder width) | 4 | 2026-11-01 | `world-scenery.md` |
| A bot never entered Climbing on a tie | 2 | 2026-11-02 | `world-scenery.md` |
| A picked fix failed its confirm run | 1 | 2026-11-02 | `world-scenery.md` |
| A full-run report hid failed names (fix queued: the fetch lists every failed name first) | 3 | 2026-11-02 | `studio-and-scripts.md` |
| The sleep-meter holder stopped between Play runs (cause fix due) | 2 | 2026-11-02 | `studio-and-scripts.md` |
| A Play push that never stops (a step-down is not a fall) | 1 | 2026-11-03 | `studio-and-scripts.md` |
| A Play pass list stricter than its plan (a loop of job fixes) | 1 | 2026-11-03 | `studio-and-scripts.md` |
| A card step capped below its real call count | 1 | 2026-11-03 | `teamwork.md` |

## Fixed kinds

| Kind | Fixed by | Date |
|---|---|---|
| A Play trace didn't retry like a player (2 times: the 2026-11-02 ladder wedge, Task 61a Step 2) | A Play trace retries like a player and shows the stall (`job-check.sh --handoff` fails a Play step that can report STUCK with no "step back" retry or no stall shot) | 2026-11-03 |
| A Play job's script never run before failed (1 time, Task 61a Step 3: script X first ran at case 5) | The smoke run runs every script of the job once; every spot a script waits for is measured | 2026-11-02 |
| A world script's guess about an existing part didn't match the world (2 times, Task 58b Step 2) | CHECK_ONLY switch, read-only run in Edit first; job-check fails a new world script without it | 2026-11-01 |
| A runner mistyped a file path | 2 times (Task 58b cause job, Task 58b names check): `runner.md` step 1 (copy paths letter by letter; on "File does not exist" compare with the working directory and retry once) and a runner copies file paths from its prompt, never from memory | 2026-11-01 |
| A pass rule worded differently from the real error | 3 times (Task 15 Step 2 red error; Task 57 Step 2 full run; Task 58 Step 2 part names): a full-run pass line names only what the fetch prints and a `job-check.sh --handoff` rule that fails a full-run pass line naming output the fetch doesn't print, or a CamelCase name that isn't a spec | 2026-11-01 |
| Check started inside a mesh, or a start check that's wrong | 13 times (thirteenth: Task 12c beard run, a grab start `StartCheck.nearSpot` picked slid 2.45 in the dry start: cause with code_lead; tenth: Task 12c step 1, a handoff's own box check; eleventh: Task 12c step 3, StartCheck-open stand spots slid off in the dry start; twelfth: the step 3 rerun, the Rare 1 grab start slid as a still stand); product ruled it "stuck on one problem": Task 53 (`StartCheck.nearSpot`, starts only from the walk map's open spots) and never start a walk, check or camera inside a mesh, extended | 2026-10-28 |
| Rojo crash | Removing a synced folder crashes Rojo | 2026-10-27 |
| Studio out of date | Removing a synced folder crashes Rojo, and after it came back check the sync with a free search before the first runner call | 2026-10-27 |
| Idle turn | Never end a turn on a promise | 2026-10-27 |
| Scenery overrun | Scenery gets the cheap fix, and after a planned fix broke sink scenery instead of fitting parts to it, a new learning rechecks the open tasks | 2026-10-27 |
| Studio busy ("not reachable") | Long Play work runs in the background, extended to test runs; came back 2026-10-28 (Task 46): a full test run is fetched again, never started again and a runner task that pauses between spec files | 2026-10-27 |
| Script error | A Luau line can't start with "(" (A Luau line can't start with "("), long Play work runs in the background; came back 2026-10-28 (Task 47): a hook blocks the "(" line | 2026-10-27 |
| Task over its size (step over its call cap) | The handoff names the exact files and lines, and after it came back fetch background work once, when it's done and a background job reports as it goes; came back 2026-10-28 (Task 54 place step 3, 51 of 30 calls): the hook counts an agent's tool calls, not the agent, the hook counts each agent's tool calls; again 2026-10-28 (Task 10 step 5, 25 of 30 calls spent reading): a step's reading fits inside its cap, a step's reading fits inside its cap; again 2026-11-01 (Task 58b step 1, a job file grew past 300 lines at the end): a handoff that grows a job file near 300 lines plans its split first, the handoff plans the split; again 2026-11-02 (Task 60 step 5, 20 of 20 Studio calls planned, one failed): a Studio step with no spare call can't absorb one failed call, one spare call per Play session; again 2026-11-02 (Task 61m step 2, a folder made only at Play was expected in Edit): a names check marks which names exist only in Play, the names check marks Play-only names; again 2026-11-03 (Task 61h step 4, a 649-line job script cost two builders their memory and a red flag): use the game's own signal, and size job files before the step to 306, sized job files, paste-line caps and named game signals | 2026-10-27 |
| A new part fails an existing test (first time) | A trial part must also pass the tests for its kind | 2026-10-27 |
| A fill makes its own stuck spots | A fill's top is a new floor | 2026-10-27 |
| Fix planned on an unconfirmed cause | Try 5 examples before choosing a fix, extended after Task 33, and the cause line in `agent-workflow.md`, "Decision table first" | 2026-10-27 |
| Over memory limit | 30-tool-call cap per builder step (`agent-workflow.md`, "Size steps by tool calls"), a Studio script returns a short summary, never a list, and after a third time a hook enforces the memory limit, not a guess, extended after a fourth (code_lead) to every agent; came back 2026-10-28 (Task 54 Play job, 1106 lines in one file): a big job is pasted by a builder with room to spare (extended: the joined check ignores join-only warnings) extended with a line budget per job file; again (Task 33b step 4, three files for one writer): one writer per job file | 2026-10-27 |
| A job stopped before judging anything | Baseline first, fresh counts, and after the third time (Task 54 call 10) a job script is checked in the shell before its first paste and `scripts/job-check.sh`; fourth (Task 33b step 2): every stop prints the check that fired and its own failure; fifth (Task 7 step 2, a search-rule pick never seen before the paste): a job never picks a part by a search; the handoff names it and `scripts/job-check.sh --handoff`; sixth (Task 8b slot 3, a stop on a cross-check count): a job stops only on a lost or broken input, never on a cross-check count and a `--handoff` check for count-match stops; seventh (Task 10 step 5, `SoundService.Volume`, a member that doesn't exist): `scripts/job-props.py` in job-check; eighth (Task 11 step 5, GiantState looked up inside Remotes): jobs use `Net.waitForClient`, and job-check fails a job that spells a `Net` object name; ninth (Task 12b step 2, a start floating 5.9 studs above a slope): every Play step starts with a dry start (extended: "proven" means it held in one, and only the main proof's starts stop it), and `job-check.sh --handoff` fails a Play step with no dry-start call; tenth (Task 12c last run, the Rare dropped 2.4 s after the grab, before any beard try): cause being measured | 2026-10-29; eleventh (Task 12c beard run, the nearSpot grab start slid in the dry start): the beard proof moves into product's build review |
| A guessed placement spot in a brief or list | A placement list gives measured spots, or says "measure first"; rule in `agent-workflow.md` | 2026-11-02 |

## Area files

| File | What it covers | Rows |
|---|---|---|
| `world-scenery.md` | Objects in the world and how they fit the giant: the Sock, the pillow, the beard, the forehead | 19 |
| `studio-and-scripts.md` | Rojo, Studio syncing, and scripts pasted into Studio | 13 |
| `teamwork.md` | Handing work between agents, agent memory, and task sizes | 22 |
