# Problems log

One line for every unplanned stop: anything that halted or slowed the work and wasn't part of the plan. The main chat adds the line as soon as it happens, in the file for the area, feature or gameplay part it belongs to. **The same kind twice means fix the cause** (`agent-workflow.md`, "Learning from experience"), and the fix becomes a lesson (`docs/lessons/index.md`).

Kinds: **Rojo crash**, **Studio out of date**, **Idle turn** (nothing ran and nobody knew), **Over memory limit** (an agent went past its limit), **Script error** (a pasted script failed), **Over budget** (a task went past its planned size), **Scenery overrun** (a second task on the same scenery object), **Fix planned on an unconfirmed cause** (a fix aimed at a part nobody measured).

**How to use it.** Agents read this map and only the area files that match their work. Before logging a problem, check the "Open kinds" table: a kind already there means this is the second time, so the cause gets fixed now.

**Files by area, never by date.** One file per area of the project, feature or gameplay part, for example `world-scenery.md`, or a feature from the spec index such as `stuck-safety.md`. A problem that fits no file starts a new one, with a line in the "Area files" table. No file here goes over 1000 lines: when one nears the limit, split it into narrower areas (for example `world-scenery.md` into `the-sock.md` and `the-pillow.md`) and update this map.

## Open kinds

A kind stays here until its cause is fixed. Then its row moves to "Fixed kinds".

| Kind | Times | Last seen | Area file |
|---|---|---|---|
| A rerun rebuilt from memory | 2 | 2026-10-27 | `teamwork.md` |
| A new test hidden by the red break | 1 | 2026-11-01 | `teamwork.md` |
| A job given to an agent without its tools | 1 | 2026-11-01 | `teamwork.md` |
| A second task on the same object (ladder width) | 4 | 2026-11-01 | `world-scenery.md` |
| A full-run report hid failed names (fix queued: the fetch lists every failed name first) | 3 | 2026-11-02 | `studio-and-scripts.md` |

## Fixed kinds

| Kind | Fixed by | Date |
|---|---|---|
| A world script's guess about an existing part didn't match the world (2 times, Task 58b Step 2) | Lesson 166 (CHECK_ONLY switch, read-only run in Edit first; job-check fails a new world script without it) | 2026-11-01 |
| A runner mistyped a file path | 2 times (Task 58b cause job, Task 58b names check): `runner.md` step 1 (copy paths letter by letter; on "File does not exist" compare with the working directory and retry once) and Lesson 163 | 2026-11-01 |
| A pass rule worded differently from the real error | 3 times (Task 15 Step 2 red error; Task 57 Step 2 full run; Task 58 Step 2 part names): Lesson 151 and a `job-check.sh --handoff` rule that fails a full-run pass line naming output the fetch doesn't print, or a CamelCase name that isn't a spec | 2026-11-01 |
| Check started inside a mesh, or a start check that's wrong | 13 times (thirteenth: Task 12c beard run, a grab start `StartCheck.nearSpot` picked slid 2.45 in the dry start: cause with code_lead; tenth: Task 12c step 1, a handoff's own box check; eleventh: Task 12c step 3, StartCheck-open stand spots slid off in the dry start; twelfth: the step 3 rerun, the Rare 1 grab start slid as a still stand); product ruled it "stuck on one problem": Task 53 (`StartCheck.nearSpot`, starts only from the walk map's open spots) and Lesson 21 extended | 2026-10-28 |
| Rojo crash | Lesson 3 (Removing a synced folder crashes Rojo) | 2026-10-27 |
| Studio out of date | Lesson 3, and after it came back Lesson 44 (Check the sync with a free search before the first runner call) | 2026-10-27 |
| Idle turn | Lesson 4 (Never end a turn on a promise) | 2026-10-27 |
| Scenery overrun | Lesson 1 (Scenery gets the cheap fix), and after a planned fix broke Lesson 19, Lesson 30 (A new lesson rechecks the open tasks) | 2026-10-27 |
| Studio busy ("not reachable") | Lesson 22, extended to test runs; came back 2026-10-28 (Task 46): Lesson 51 and a runner task that pauses between spec files | 2026-10-27 |
| Script error | Lesson 7 (A Luau line can't start with "("), Lesson 22 (Long Play work runs in the background); came back 2026-10-28 (Task 47): a hook blocks the "(" line | 2026-10-27 |
| Task over its size (step over its call cap) | Lesson 24 (The handoff names the exact files and lines), and after it came back Lesson 29 (Fetch background work once, when it's done) and Lesson 31 (A background job reports as it goes); came back 2026-10-28 (Task 54 place step 3, 51 of 30 calls): Lesson 73, the hook counts each agent's tool calls; again 2026-10-28 (Task 10 step 5, 25 of 30 calls spent reading): Lesson 89, a step's reading fits inside its cap; again 2026-11-01 (Task 58b step 1, a job file grew past 300 lines at the end): Lesson 154, the handoff plans the split; again 2026-11-02 (Task 60 step 5, 20 of 20 Studio calls planned, one failed): Lesson 212, one spare call per Play session | 2026-10-27 |
| A new part fails an existing test (first time) | Lesson 37 (A trial part must also pass the tests for its kind) | 2026-10-27 |
| A fill makes its own stuck spots | Lesson 35 (A fill's top is a new floor) | 2026-10-27 |
| Fix planned on an unconfirmed cause | Lesson 26 (Try 5 examples before choosing a fix), extended after Task 33, and the cause line in `agent-workflow.md`, "Decision table first" | 2026-10-27 |
| Over memory limit | 30-tool-call cap per builder step (`agent-workflow.md`, "Size steps by tool calls"), Lesson 23 (A Studio script returns a short summary, never a list), and after a third time Lesson 25 (A hook enforces the memory limit, not a guess), extended after a fourth (code_lead) to every agent; came back 2026-10-28 (Task 54 Play job, 1106 lines in one file): Lesson 63 extended with a line budget per job file; again (Task 33b step 4, three files for one writer): one writer per job file | 2026-10-27 |
| A job stopped before judging anything | Lesson 71 (baseline first), Lesson 61 (fresh counts), and after the third time (Task 54 call 10) Lesson 76 and `scripts/job-check.sh`; fourth (Task 33b step 2): Lesson 79; fifth (Task 7 step 2, a search-rule pick never seen before the paste): Lesson 80 and `scripts/job-check.sh --handoff`; sixth (Task 8b slot 3, a stop on a cross-check count): Lesson 84 and a `--handoff` check for count-match stops; seventh (Task 10 step 5, `SoundService.Volume`, a member that doesn't exist): `scripts/job-props.py` in job-check; eighth (Task 11 step 5, GiantState looked up inside Remotes): jobs use `Net.waitForClient`, and job-check fails a job that spells a `Net` object name; ninth (Task 12b step 2, a start floating 5.9 studs above a slope): Lesson 120, and `job-check.sh --handoff` fails a Play step with no dry-start call; tenth (Task 12c last run, the Rare dropped 2.4 s after the grab, before any beard try): cause being measured | 2026-10-29; eleventh (Task 12c beard run, the nearSpot grab start slid in the dry start): the beard proof moves into product's build review |
| A guessed placement spot in a brief or list | Lesson 221 (A placement list gives measured spots, or says "measure first"); rule in `agent-workflow.md` | 2026-11-02 |

## Area files

| File | What it covers | Rows |
|---|---|---|
| `world-scenery.md` | Objects in the world and how they fit the giant: the Sock, the pillow, the beard, the forehead | 19 |
| `studio-and-scripts.md` | Rojo, Studio syncing, and scripts pasted into Studio | 12 |
| `teamwork.md` | Handing work between agents, agent memory, and task sizes | 22 |
