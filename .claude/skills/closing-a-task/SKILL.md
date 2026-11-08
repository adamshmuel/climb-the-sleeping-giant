---
name: closing-a-task
description: The main chat's checklist at every task close and at Gate 4 - health check and its alarms, the look back, learnings and problems-log lines, the commit, the handoff update, and merging a finished feature. Use when a task is approved, a small fix passes its test run, a session starts, or a feature reaches Gate 4.
---

# Closing a task

## 1. Health check

Run `python3 scripts/health.py` (also at the start of every session). It prints hours worked and idle, each agent's size, Rojo crashes and commits, then the alarms. Check these by hand too:

| Alarm | Do |
|---|---|
| Nothing running for more than 30 minutes, and nobody knew | log an idle turn, start the next step now |
| Two tasks in a row closed with nothing built | `stop-and-step-back` (loop) |
| A task past 1 hour or its planned size | `stop-and-step-back` (task) |
| A second task on the same object | `stop-and-step-back` (same object) |
| The plan trigger in `stop-and-step-back`, "Triggers" | `stop-and-step-back` (plan) |
| A Rojo crash, an agent over its limit, or another unplanned stop | a problems-log line |

An alarm means stop before the next step. Never carry on as if nothing happened.

If the session start said an Anthropic guide page changed (files in `work/guides/diffs/`), run the `guides-check` skill now.

## 2. Look back

Ask in one line: what slowed this task down, and could a hook, a rule, a skill or an agent's memory have stopped it?

- **Learnings.** Agents save their own learnings to their memory (`.claude/agent-memory/<agent>/`) at the end of each job. Each `LESSON:` line from a report goes to its one home: a hook if it must always happen, a rule (or path rule) if every agent needs it, a skill if it is a procedure, or one agent's memory if only that agent needs it. First look for a line that already covers it, and update that one instead of adding another.
- **A new lesson rechecks the open tasks.** Ask `code_lead` to check every open task's planned fix against it, and change any that break it, before the next handoff.
- **Problems log (`docs/problems-log/`).** One line per unplanned stop in the matching area file, as soon as it happens. Check the index's open kinds first. **The same kind twice means fix the cause** (a rule, a script or a hook) and write the learning in its home. A workaround alone is never the second fix.

## 3. Commit (`git.md`)

- **When:** `git.md`, "Commits".
- What goes in: the task's tests, code, world scripts and docs together. Never a failing test, except reds the plan names as accepted.
- A task that changed the world runs the full suite before it closes. Its accepted reds are listed from that full run, each with the later task that turns it green. The planned list includes reds that a planned removal causes (for example route points left when a ramp goes).
- **Archive the sessions this task started** once their work is committed or merged (`mcp__ccd_session_mgmt__archive_session`). Check each one's worktree with `git status` first: archiving can drop uncommitted work (https://code.claude.com/docs/en/desktop#archive-a-session).
- Then go straight to the next task in the plan's order.

## 4. Tell the user and update the handoff

- One line to the user: what finished, and the time against the plan, for example "Task 7: 1.2 h, planned 1 h".
- Update the "Now" section of `docs/handoff.md` (untracked) after every agent step, not only every task: the task in progress, open questions, each agent's size, and what the user checks at the next gate. The app compacts the chat at any moment, so this file is the memory.

## Gate 4: a finished feature

1. `product_reviewer` writes `docs/reviews/<feature>.md`; `game_creator` and `designer` play it too.
2. The user approves the built feature.
3. If the world changed, the user saves the place over `climb-the-sleeping-giant.rbxl`, and the main chat commits it on the branch.
4. Clean out the task backups in `ServerStorage.WorldBackups`.
5. The main chat merges the branch into `main` with `git merge --no-ff <branch>`.
6. The main chat tells the user it's ready to push. The user pushes.
