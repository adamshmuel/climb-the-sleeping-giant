# Problems log

One line for every unplanned stop: anything that halted or slowed the work and wasn't part of the plan. The main chat adds the line as soon as it happens, in the file for the area, feature or gameplay part it belongs to. **The same kind twice means fix the cause** (`closing-a-task` skill), and the learning goes to its home: a hook, a rule, a skill or the agent's own memory (`closing-a-task` skill).

Kinds: **Rojo crash**, **Studio out of date**, **Idle turn** (nothing ran and nobody knew), **Over memory limit** (an agent went past its limit), **Script error** (a pasted script failed), **Over budget** (a task went past its planned size), **Scenery overrun** (a second task on the same scenery object), **Fix planned on an unconfirmed cause** (a fix aimed at a part nobody measured).

**How to use it.** Read this map, then only the area files that match the work. Before logging a problem, check the "Open kinds" table: a kind already there means this is the second time, so the cause gets fixed now.

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

Each rule is written once, in its home. This table only names the home.

| Kind | Where the rule lives now | Fixed |
|---|---|---|
| A Play trace didn't retry like a player | `scripts/job-check.sh --handoff` (a Play step that can report STUCK needs a "step back" retry and a stall shot) | 2026-11-03 |
| A Play job's script never run before failed | `writing-handoffs` and `studio-jobs` skills (the smoke run runs every script once) | 2026-11-02 |
| A world script's guess about an existing part didn't match the world | `scripts/job-check.sh` (a new world script needs a `CHECK_ONLY` read-only run) | 2026-11-01 |
| A runner mistyped a file path | `.claude/agents/runner.md` (copy paths letter by letter) | 2026-11-01 |
| A pass rule worded differently from the real error | `scripts/job-check.sh --handoff` (a pass line names only what the fetch prints) | 2026-11-01 |
| Check started inside a mesh, or a start check that's wrong | `studio-jobs` and `writing-handoffs` skills, `scripts/job-check.sh` (starts come only from the walk map's open spots, `StartCheck.nearSpot`) | 2026-10-28 |
| Rojo crash | `.claude/rules/rojo.md` and `.claude/hooks/rojo-safe-delete.py` (removing a synced folder crashes Rojo) | 2026-10-27 |
| Studio out of date | `.claude/rules/rojo.md` (check the sync before the first runner call) | 2026-10-27 |
| Idle turn | `.claude/rules/agent-workflow.md` and `.claude/hooks/no-idle-stop.py` (never end a turn on a promise) | 2026-10-27 |
| Scenery overrun | `world-parts` skill (scenery gets the cheap fix) | 2026-10-27 |
| Studio busy ("not reachable") | `studio-jobs` skill and `.claude/agents/runner.md` (long work runs in the background; a full test run is fetched again, never started again) | 2026-10-27 |
| Script error | `.claude/hooks/luau-paren-line.py` (blocks a Luau line that starts with "(") | 2026-10-27 |
| Task over its size (step over its call cap) | `writing-handoffs` skill (every step lists its tool calls, reading included; one spare call per Play session; job files sized before the step; Play-only names marked) | 2026-11-03 |
| A new part fails an existing test | `world-parts` skill (a trial part also passes the tests for its kind) | 2026-10-27 |
| A fill makes its own stuck spots | `world-parts` skill (a fill's top is a new floor) | 2026-10-27 |
| Fix planned on an unconfirmed cause | `writing-handoffs` skill (trace before fixing: no fix without a measured cause) | 2026-10-27 |
| Over memory limit | `writing-handoffs` skill (memory and tool-call caps, one writer per job file) and `.claude/rules/agent-workflow.md` (a Studio script returns a short summary) | 2026-10-28 |
| A job stopped before judging anything | `scripts/job-check.sh` and `scripts/job-props.py` (no part picked by a search, no stop on a cross-check count, real members only, `Net.waitForClient`, a dry start first) and `studio-jobs` skill (fresh counts) | 2026-10-29 |
| A guessed placement spot in a brief or list | `writing-handoffs` skill (a placement list gives measured spots, or says "measure first") | 2026-11-02 |

## Area files

| File | What it covers | Rows |
|---|---|---|
| `world-scenery.md` | Objects in the world and how they fit the giant: the Sock, the pillow, the beard, the forehead | 48 |
| `studio-and-scripts.md` | Rojo, Studio syncing, and scripts pasted into Studio | 68 |
| `teamwork.md` | Handing work between agents, agent memory, and task sizes | 89 |
