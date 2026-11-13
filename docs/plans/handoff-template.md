# Builder handoff template

code_lead copies this shape into `work/<task>/handoff-<name>.md` for every task. Each step stops at a safe point (a green run, never in the middle of a world change), and each heading names its Studio-call cap and its model (`.claude/rules/agent-workflow.md`, "Model per job").

```
# HANDOFF builder: Task N: <name>
- Spec rules: Rule <n> (<short name>), ...
- What it's for: core gameplay it protects, or scenery. How big: steps and Studio calls.
- Files: ...
- Lessons (quoted): the lesson lines the steps need, so the builder doesn't open the index.
- Done when: ...

## Step 1: Red test, then the code (<n> Studio calls, Sonnet)
## Step 2: Full test run (2 Studio calls, Haiku)
## Step 3: Check-only run of the world script (1 Studio call, Haiku)
## Step 4: Play check (<n> Studio calls, Sonnet)
```

- **Check-only step.** Any task with a world script that edits existing parts gets a check-only step before its first Play paste. The runner (Haiku) pastes a copy of the script with `CHECK_ONLY = true`, in Edit, in 1 Studio call. Pass: it prints "CHECK ONLY ... passed" and changes nothing. A task with no world script leaves this step out.
- **Full runs** are always their own Haiku step.
- **Play steps** begin with a dry start, or name the dry start their starts already held in.
- Run `scripts/job-check.sh --handoff <file>` before the handoff goes out.
- **Files per step.** Before sizing a step, count the files it edits (search for every file that reads the thing being changed). A code step edits at most 5 files; more are split into steps of 5 or fewer.
