# Specs

- Define each shared place word ("on the giant") once, under "Words used here", and point every rule to it.
- Before flagging a spec as over 15 rules, count only real rules: not "not used" lines, not changes to other specs' rules.
- When a Rule 103 trim would break a mirrored walk width (Rule 36's 9) on one side only, accept that one hidden face by name up to 0.3, never narrow one side (5b1).
- A task with no "Stands on:" line can pass job-check (p4 Task 2 did); read each task block, not only the check's output (p5t12, 2026-11-10).
- Before ordering a task, trace its "Stands on" through other plans' unbuilt code (p5 T19 → p4 T7 → p3 T11/T12a costsFrom → p3 T2 ladder multiplier); and test a "whole session" card against plans that rewrite its real modules (p5 T21's wake leg vs plan 6's director) (2026-11-10).
- `scripts/job-check.sh --plan` reads any "## Step N" heading as a task; name the skill's parts "(skill part N)" in a ruling file.
