---
name: writing-handoffs
description: How to size, write and check a task handoff, a plan's task blocks or a Play job for the builder or runner - memory and tool-call caps, steps in minutes and models, the world-names table, smoke runs, pass lists and Play jobs that act like a player. Use when writing, checking or rerunning a handoff, a job card, a Play job or a plan's tasks.
---

# Writing handoffs

Most of an agent's cost is rereading its memory before every step, so every extra step, stop and question costs a full reread. A handoff keeps the work the same and the trips few. How the job script itself is written is the `studio-jobs` skill.

## Size

| Agent | Limit |
|---|---|
| `builder` | A fresh agent per task. It stops and reports after each step (after a green test run, never in the middle of a world change), with a short state note in `work/`. The main chat resumes it for the next step; a fresh builder carries on from the note when it was compacted or cut off |
| `runner` | A fresh agent per job, never resumed |
| Others | Resume them; start a fresh one at the next natural break once they have been compacted |

- Each agent file sets `autoCompactWindow` (when its memory is compacted) and `maxTurns` (how many turns it gets before its report comes back marked partial). These are the [official subagent settings](https://code.claude.com/docs/en/sub-agents); no hook counts calls.
- A fresh agent starts at about 50k tokens; each tool call adds about 2.4k.
- **Every step lists its tool calls** (Studio, shell and reads together), numbered under the step heading: `list_roblox_studios`, session hold, phone set and reset, console read, one fetch per expected report page. The list plus one spare per Play session stays under the agent's `maxTurns`. Where one call fails without another, the handoff gives their order.
- **Every file the step pastes or reads gets its own numbered `Read <file>` line** (each snippet, the card, the spec, the earlier note), plus one fix-up read and one job-check retry. The cap is the count of that list. Task 6a3 went over its cap 5 times in one day, each time by reads the list left out.
- **Copy the phone calls into the handoff** from the `look-check` skill's [shots job](../look-check/shots-job.md), so no skill is fetched.
- **Every step gives planned minutes and its model** in its heading, for example `## Step 3: The full run (2 Studio calls, 4 min, Haiku)`. Steps add up to the task's hours. No task is planned over 1 hour (the CLAUDE.md time limit); a bigger one is split.
- **Reads:** a step names at most 5 files, with the exact functions or line numbers to read and edit, and quotes the rule, skill or memory lines it needs. The builder reads only those.
- **Pastes:** each script is pasted once, straight into Studio, from its file's own text (read and paste whole, or cut by line numbers). Only whole comment lines may be left out, and the report says so. A retyped, trimmed or edited paste voids that call's result; the handoff's stop rules say so. A step's caps give paste lines (file lines times pastes). Over about 2000 paste lines, split the step. No job file over 300 lines. Every snippet is in the handoff or one named job file.
- **Too big for one call:** the handoff splits the script. A split job is pasted joined in one Studio call. A client Play job with more than two shots is planned as two pastes (helpers, then the flow), both counted. Never load a script over HTTP or turn on HttpEnabled or another place setting to paste it. A prompt names only ways of working a tool really has.
- **Job file size:** StyLua splits long `table.insert(...)` and `string.format(...)` calls at column 120, so write short lines (`rows[#rows + 1] = ...`, short format helpers) and check `wc -l` right after the first save. A step that adds to a job file over about 200 lines says how it is split before the builder writes. Put the dry start and the read in their own file from the start.
- **Writing a job is its own step,** apart from the code and from running it, budgeted at about 4 tool calls per script (write, lint fix, dry run, spare) plus its reads.
- **One writer per job file.** Writing a job and pasting it are two builders: one writes and checks the file, a fresh one pastes it and writes up. Several job files get one writer each, in parallel.
- **Resume or fresh?** Before resuming an agent for a restart, add its size to every file it will paste. Over about two thirds of its limit (never above 100k for a step that writes a job), start a fresh agent from the state note. A fetch-only finish goes to the `runner`.
- **World scripts are never pasted.** Run one with a single `execute_luau`: `require(ServerStorage.Tools.world["<name>"]:Clone())`, after a short `script_read` sync check. Read a world script only to edit it, and only the lines you change. A `tools/` script is never split into `--joined` parts; move helpers into a module it loads as a fresh copy.
- **A repeated step becomes a job file.** When a step will be done again (look shots, device setup), the first builder writes its exact calls into a ready-made job file in `work/`. The next handoff says to run that file and budgets the calls it really took.
- A step with a red run, a green run and more than 5 files is two steps.
- A task that keeps stopping is split into smaller tasks.

## Models

Pick from the CLAUDE.md "Model per job" table. A resumed agent keeps its model, so a step on another model gets a fresh agent with the handoff and the last state note.

**Ready-made run scripts.** A full test run is always the `runner`:
1. paste `scripts/studio/full-run-start.luau`;
2. wait about 60 s with `python3 -c "import time; time.sleep(62)"` (how to wait: `studio-jobs` skill);
3. paste `scripts/studio/full-run-fetch.luau`, again while a page ends with "fetch again", until "end of report". Never start a run twice. Copy every page.

Never call `get_console_output` after a test run: it returns the log of earlier runs too (about 10k tokens). Read only the fetch's own return.

Caps for a full run: 1 start, plus 1 fetch for each page the last full run had, plus 1 spare. The runner's tool-call cap is 3 times the expected pages, plus 4. The prompt tells the runner to write each page to its note right after fetching it (a fetched page is gone), and puts the old list of failing names in the prompt so no extra read is needed.

A builder's red run uses the narrowest filter (the step's own spec names) so the report fits on one page. A red step's Studio cap: 1 start, plus 1 fetch for about every 5 failing tests it expects, plus 1 spare, plus 1 re-run in case a new test passes by accident. A step that inherits an unfetched page budgets one more fetch to clear it. A job that needs one test's details (positions, names, counts) runs only that test and keeps its whole message; the run report's short form is for pass and fail lines only. `code_lead` judges the result, never the `runner`. `scripts/job-check.sh --handoff` fails a step with no model, a full run on Sonnet or Opus, or a red step with 0 Studio calls.

## Before the builder starts

- **World table.** Every world name, position and part kind the handoff relies on is in one table. `code_lead` checks it against the running world in one read-only Studio call (a `runner` job) and marks each row "exists in Edit", "made at Play by <script>" (the Play job's Server paste picks it; an Edit dry run reports it "not found (made at Play)" and doesn't fail), or "built by <plan and task>; spec positions used" (the spec's numbers, never a search). For a part whose look a script copies, the check also prints its ClassName, Shape, Size and turn. A Cylinder's length is its X axis.
- **A re-run or a fix is a handoff too:** no paster starts until every name in every job file is checked and the state note says "names checked".
- **Names check** measures and prints. It stops only on a missing part or module, never on an expected value. It runs `nearSpot` on every start row, and the row says "open in Edit" or "held N in <task> dry start".
- **Made-up test worlds** are built once in a throwaway world in the names-check call, and what was measured is written down.
- **Measured spots.** Placement spots come from a read-only Studio call, or say "measure first". "About 6 studs back" is a guess. A walk test gets waypoints from a measured route (height map plus route search), every start spot comes from a measured floor hit, and the job loads the area first (parts stream in only near the player). A case that expects a drop casts rays down its path and writes the floor height from start to end: under 2 studs it is a walk, and the case ends "on the ground, off the start part".
- **Limits.** Check each limit against the value already measured, and write it as what the player needs. Mark each number "measured" or "worked back"; a tight limit uses only measured ones. On a slope, a stand limit covers the middle hit to the highest corner.
- **Walks a saved job does.** When the handoff names a walk or check a saved job must do, its author reads the job file and names the lines that do it.
- **Decision table.** For many cases of one kind, a table says which kind gets which fix, plus stop rules. Each row names its cause as measured. The builder applies it without asking per case and collects anything it doesn't cover into one `QUESTIONS:` list at the end of the step.
- **Parts beside a walk floor** give each part's inward reach from the wall, checked against half the measured walk width.
- **Stands on.** Every task and step has a "Stands on:" line (the `order-the-work` skill). Run `scripts/job-check.sh --handoff <file>`.

## Play jobs

- **Trace before fixing.** A stall or a wrong end with no measured cause gets a read-only trace step first (state, x, y, z, floor and touching parts every 0.1 s), and the fix is built from what the trace shows. Before changing any timing, check whether the character was ever in the air.
- **Smoke run first.** A builder runs the job's first case once, on one side, with the job's own scripts (about 6-8 calls), and takes one shot from the player's camera. Every script of the job runs at least once, including one that starts only in a later case. Every spot or line a script waits for is measured from a real run. The job starts only if the player moves as expected, no game rule interferes and no loop is left running.
- **One case per behaviour the player feels.** Each case says what a player would notice if it broke. A mirror side gets its own case only when measurements or code show it differs.
- **A pass list quotes its plan.** Each pass item quotes the plan line it proves, names the part by its real name from the world table, and names the game signal it reads (a console line, an attribute, an event, with its file). `code_lead` greps each signal and checks the whole list against the plan before the first run and before every rerun. Name every measured spot after the part its ray hit. Write each pass word as the value the game's own function returns, checked with a grep. Measure each limit only over the zone its pass line names, and log where it is first crossed.
- **Each pass line says what it judges:** what the player gets, or a safety margin, and what each result means, before the run.
- **A pass proves the new path.** A "nothing happened" check also prints how much the cause really happened; a try where it didn't happen is made again. Press where the new and old behaviour give different results, or name the check as not proven. A silent-meter check runs with and without the carried item.
- **A pass item is shown to pass first.** Before a check becomes a pass item for a new twin, run it once on the twin already built and proven in Play, and quote that result. Never make an accepted red a pass item without showing it can pass.
- **A red pass rule** quotes the exact error Roblox prints and the expected number of failures with the old passed total.
- **An analytics event** is proven in Play only by how many console lines appear and when; its name and values by unit tests.
- **A re-proof** covers only the rules that failed; the rest are accepted from the failed run's measured lines.
- **Play like a player.** Each case marks "between", moves the character to its start and waits for Grounded, then names the case. Before calling a climb slow or stuck, measure the gaps round the climb line. When the character stalls, the script turns toward the open face, steps back or jumps a few times; a turn that works is a pass. A stall is never reported as a cause until a shot from the player's camera shows what stops the character.
- **Phone checks** rerun only what the phone screen changes (shots, on-screen buttons and text), never walks.
- **A shot of an effect is checked against how long it lasts.** If the effect ends before the capture, prove it with the game's own signal and ask for no shot. The handoff says up front whether the task changes what the player sees; if not, it budgets no look shots.
- **A proof camera** is placed and aimed the `look-check` skill's way ("Shots"), set off the player's facing line.
- **A gap proof** aims the camera at a right angle to the line between the two edges (about 10 studs away, 3 up), with both edges and the gap in the frame. Zoom the shot before naming what blocks it.
- **Choose the shot and the pass rule together.** A "feet on the floor" proof is shot from behind the player along their path, at their own zoom distance, never from a high side camera where a wall can hide their legs.

## Plans

- **Count before sizing.** A task that works through a list (spots, parts, files) first counts it in one read-only call, and is sized from that count.
- **Every step and every size has a Studio-call count** from the start, even a shots-only step or a size in a ruling, including its test runs (red run, full run and fetch). Every call counts, whoever makes it; `code_lead`'s own calls are their own lines.
- **Stand-in numbers** name the recorded run that replaces them, in a named task step.
- **The task that builds a look checks it in Play**, with shots timed to catch it. An earlier task doesn't list it.
- **Check the spec's proof list first.** Plan a proof task only for what the list doesn't already give to another step (for example, the build review).
- **Every promise in a task header** matches a budgeted step, and every analytics event in the spec matches a named task.
- **At each task close**, `code_lead` checks the next task's block has a size and a call count.

## Reports

- At most about 20 lines: result, numbers, questions. Details go in the state note in `work/`.
- Never read a whole file over 1000 lines; never pull more than about 100 lines of output (write it to `work/` and read its summary); never reread a file.
- A learning other agents also need ends the report as a `LESSON:` line (`agent-workflow.md`, "Learn from the past").
