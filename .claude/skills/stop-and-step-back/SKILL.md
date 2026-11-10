---
name: stop-and-step-back
description: The one stop process for work that is taking too long, looping or making the game look worse. Use the moment a time limit passes (10 min for a small fix, 1 h for a task or new part), two steps in a row bring nothing new, a check fails because of its own measuring tool, a second task is added for the same object, a plan passes 1.5 times its time, or a main character or the first view looks worse after a change.
---

# Stop and step back

Over the limit means the approach is wrong, not that it needs more time. Fixing it one patch at a time is how a fix makes the game worse.

## Triggers

The main chat checks these at every agent report and every task close. It never waits for the user to point one out. It writes each task's start time to `work/task-clock.txt` (`Task 5 | small | 2026-11-03 12:00`; small, task or done), and `.claude/hooks/task-clock.py` warns on every prompt and agent start once the limit passes.

| Trigger | Kind |
|---|---|
| A small fix (a moved part, a missing part, a failing test) passes **10 minutes** | small fix |
| A task or a new part (a ladder, a bridge) passes **1 hour**, or its planned time, or is clearly heading there | task |
| Two steps in a row bring nothing new: the same failure, the same kind of fix, no new fact, nothing built or passed | loop |
| A second Play round on the same task ends without a pass, even if the hours look fine | loop |
| A check fails because of how it measures (the trace, judge or job script), not the game. The first such fail stops the work: the owners ask whether the measure is needed at all before anyone fixes it | measure |
| A second task is added for the same object or place, even if nothing failed | same object |
| A plan passes **1.5 times** its planned time, grows by half its first task count, or reaches every 10th committed task | plan |
| A design pick replaces what the plan is fixing: re-plan and re-price it as a new plan before any task of the new design starts | plan |
| A "worse" verdict on a main character (the hero, the boss) or on the first view a new player sees | look |

## Step 1: Stop and tell the user

- No more work on it, and no next step of it starts. A step under way stops at a safe point, never in the middle of a world change.
- Tell the user in one line: what is done, what isn't, the time against the plan.
- Write a problems-log line, and for a loop, why it looped.
- **A small fix stops here.** One agent tries the next idea, or it goes to `product` as "stuck" (Step 4). No meeting.

## Step 2: Check the basics first

If a cheap check could make the whole problem pointless, run it first and give its result to the owners. For example: can a player even reach the thing at all? For a Play job that ends in the wrong spot, the first check is one read-only raycast along the path the job pushes.

## Step 3: The same brief to the owners

For a task, a loop, a measure, a plan or a look trigger, the main chat sends `game_creator`, `designer`, `product` and `code_lead` the same short brief:

- the player's problem the work was meant to solve;
- planned against real time and tasks, what is done and what is still to come;
- the facts (for a loop, its steps; for a look, the before and after shots). A brief that sums up a run quotes its result lines.

The brief never hints at an answer. Each owner answers from its own area, in one reply, after searching the web, its skills and the Roblox docs:

1. **The smallest piece first.** What is the smallest new piece that connects what players already reach to what is already built? Measure the gap and price it.
2. **Do we need this at all?** Can the player's problem be solved another way?
3. **Other ideas**, each priced: what it costs to build, and what built work it keeps or throws away. "Go back to the old design" is an idea like any other: it says how it solves the old design's problems, or it is out. An undo is cheap only if a commit or a script can bring it back.
   Undoing a task's code also undoes its world changes (from `ServerStorage.WorldBackups.<task>`), or the progress row lists what stayed. Before the next full run, a read-only names check confirms the edit world matches the last commit.
   Price a task from both the plan and the progress file, and use the larger number.
4. **For a plan:** which work does a player really need, and what would a player never notice? What can be cut, simplified, left to the safety net, or moved to a later plan that changes that part anyway?
5. **Why did it grow, and what would have caught it sooner?**

No idea rebuilds a part that a later spec replaces (`making-a-ruling` skill).

## Step 4: product decides

`product` weighs the answers with `game_creator` and picks one direction, with its reasons and the viral-test answer. For "stuck" or "same object", it first weighs how much the thing matters: something only for looks never gets more tries than something players play with. It picks one path:

| Path | Means |
|---|---|
| Lower the bar | change the rule or limit so it asks only what the player needs |
| Change the design | `designer` reshapes, moves or simplifies the thing |
| Accept it for now | a safety net covers the player; it goes into a named later spec |
| Cut it | out of this version (cutting a whole feature goes to the user) |
| Change the approach | `code_lead` gives a cheaper way to finish |

Before acting, the main chat checks the decision: does it answer the questions above, is it priced, is it fair to players on every side, does it avoid rebuilding what a later spec replaces, and did someone ask what nobody tried? If not, it goes back to `product`. If the cost jumps while building, the work stops and goes back to the team.

**The main chat's veto** (`CLAUDE.md`, "The main chat's veto"). When going back to `product` would cost more time than the choice is worth, or the owners' pick keeps spending time on something a player won't miss, the main chat decides itself:
- Read the docs the choice needs first (spec, plan, progress, rulings, idea file). Apply YAGNI: build only what a player needs now.
- Keep the viral test: a veto never cuts what makes a kid pick our game.
- Pick one path from the table above. A whole-feature cut or anything about money still goes to the user.
- Log one line in `docs/problems-log/teamwork.md` (what was vetoed, why, time saved), tell the owners and the user in one line each, then go to Step 5.

## Step 5: Restart

- `code_lead` rewrites the plan's remaining tasks to match.
- The learning ("why it grew") goes to its home (`closing-a-task` skill, "Learnings").
- **The task's clock restarts at zero**, and the main chat writes the new start time. The time before stays in the log.
- The main chat tells the user in one line what changed and the time saved, and keeps checking the triggers.
