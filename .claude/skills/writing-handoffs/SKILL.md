---
name: writing-handoffs
description: How to size, write and check a task handoff or Play job for the builder or runner - memory and tool-call caps, steps in minutes and models, the world-names table, smoke runs, pass lists and Play scripts that act like a player. Use when writing, checking or rerunning a handoff, a job card or a Play job.
---

# Writing handoffs

Most of an agent's cost is rereading its memory before every step, so every extra step, stop and question costs a full reread. A handoff keeps the work the same and the trips few.

## Size

| Agent | Limit |
|---|---|
| `builder` | A fresh agent per task, never over 150k tokens. It stops and reports after each step (after a green test run, never in the middle of a world change), with a short state note in `work/`. Under 150k the main chat resumes it; above, a fresh builder carries on from the note |
| `runner` | A fresh agent per job, never over 100k tokens, never resumed |
| Others | Resume while under 200k. Above that, a fresh one at the next natural break |

- A fresh agent starts at about 50k tokens; each tool call adds about 2.4k.
- **Every step: at most 30 tool calls** (Studio, shell and reads together), numbered under the step heading: session hold, phone set and reset, camera bind and reset, console read, one fetch per expected report page. The cap is that count plus one spare. `.claude/hooks/agent-memory-cap.py` enforces it.
- **Every step gives planned minutes and its model** in its heading, for example `## Step 3: The full run (2 Studio calls, 4 min, Haiku)`. Steps add up to the task's hours. No task is planned over 1 hour unless it says why.
- **Reads:** a step names at most 5 files and quotes the lesson lines it needs.
- **Pastes:** each script is pasted once, straight into Studio. A step's caps give paste lines (file lines times pastes). Over about 2000 paste lines, split the step. No job file over 300 lines. Every snippet is in the handoff or one named job file.
- A task that keeps stopping is split into smaller tasks.

## Models

Pick from the CLAUDE.md "Model per job" table. A resumed agent keeps its model, so a step on another model gets a fresh agent with the handoff and the last state note.

**Ready-made run scripts.** A full test run is always the `runner`:
1. paste `scripts/studio/full-run-start.luau`;
2. wait about 60 s with `python3 -c "import time; time.sleep(62)"` (a hook blocks Bash `sleep`);
3. paste `scripts/studio/full-run-fetch.luau`, again while a page ends with "fetch again", until "end of report". Never start a run twice. Copy every page.

A builder's red run uses the narrowest filter (the step's own spec names) so the report fits on one page. `code_lead` judges the result, never the `runner`. `scripts/job-check.sh --handoff` fails a step with no model, a full run on Sonnet or Opus, or a red step with 0 Studio calls.

## Before the builder starts

- **World table.** Every world name, position and part kind the handoff relies on is in one table. `code_lead` checks it against the running world in one read-only Studio call (a `runner` job) and marks each row "exists" or "built by <plan and task>".
- **Measured spots.** Placement spots come from a read-only Studio call, or say "measure first". "About 6 studs back" is a guess.
- **Decision table.** For many cases of one kind, a table says which kind gets which fix, plus stop rules. Each row names its cause as measured. The builder applies it without asking per case and collects anything it doesn't cover into one `QUESTIONS:` list at the end of the step.
- **Parts beside a walk floor** give each part's inward reach from the wall, checked against half the measured walk width.
- **Stands on.** Every task and step has a "Stands on:" line (the `order-the-work` skill). Run `scripts/job-check.sh --handoff <file>`.

## Play jobs

- **Measure the world before fixing a Play job.** When a case ends in the wrong spot, the fix starts with one read-only raycast along the path the job pushes, and names what it found.
- **Smoke run first.** A builder runs the job's first case once, on one side, with the job's own scripts (about 6-8 calls), and takes one shot from the player's camera. The job starts only if the player moves as expected, no game rule interferes and no loop is left running.
- **One case per behaviour the player feels.** Each case says what a player would notice if it broke. A mirror side gets its own case only when measurements or code show it differs.
- **A pass list quotes its plan.** Each pass item quotes the plan line it proves, names the part by its real name from the world table, and names the game signal it reads (a console line, an attribute, an event, with its file). `code_lead` greps each signal and checks the whole list against the plan before the first run and before every rerun.
- **Play like a player.** Each case starts standing on the ground. When the character stalls, the script turns, steps back or jumps a few times before calling a fail. A stall is never reported as a cause until a shot from the player's camera shows what stops the character.
- **A shot of an effect is checked against how long it lasts.** If the effect ends before the capture, prove it with the game's own signal and ask for no shot. The handoff says up front whether the task changes what the player sees; if not, it budgets no look shots.
- **A proof camera** uses the ready-made Client `BindToRenderStep` camera from the look-shots job, set off the player's facing line.

## Reports

- At most about 20 lines: result, numbers, questions. Details go in the state note in `work/`.
- Never read a whole file over 1000 lines; never pull more than about 100 lines of output (write it to `work/` and read its summary); never reread a file.
- An agent that spots a lesson ends with `LESSON: <what happened> → <do instead>`.