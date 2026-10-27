# Problems: How the team works

About handing work between agents, agent memory, and task sizes. The map is `docs/problems-log/index.md`. Newest rows at the bottom.

| Date | Kind | What happened | Time lost | Fixed by |
|---|---|---|---|---|
| 2026-10-26 to 10-27 | Over memory limit | Builders ended at 176k to 253k against the 150k limit in Tasks 29, 32, 35 and 36 | extra fresh builders | Lesson 6 (partly) |
| 2026-10-27 | Idle turn | After Task 38's step 38-2 report, the main chat said it would start the Play run but didn't | 4.7 h | Lesson 4 (2026-10-27) |
| 2026-10-27 | Idle turn | After Task 37's step 37-1 report, the same thing happened | 5.1 h | Lesson 4 |
| 2026-10-27 | Over memory limit | Builder ended Task 37 step 37-5 at 165k (46 tool calls); code_lead at 167k. Cause found: every agent starts at ~50k and each tool call adds ~2.4k, and no step had a tool-call cap | one fresh builder | 30-tool-call cap per builder step (`agent-workflow.md`, "Size steps by tool calls") |
| 2026-10-27 | Task over its size | Builder step 37-6 used 11 Studio calls (cap 8) and 36 tool calls in all (cap 30), and still missed the mouth-front hold, because the gap walk isn't repeatable | about 3 Studio calls | watching: a second step over its cap means the cap must be checked by a hook, not by the builder |
| 2026-10-27 | Over memory limit | Builder ended Task 41 step 1 at 222k within 29 tool calls: its scripts printed whole lists (301 points), about 7.7k per call | one fresh builder for step 2; 3 checks unseen | Lesson 23 (A Studio script returns a short summary, never a list) |
| 2026-10-27 | Task over its size (step over its call cap) | Task 41 step 2 hit its 30-tool-call cap after 2 Studio calls: the builder read many files before coding, and the handoff didn't name the exact files and lines to edit | one fresh builder | Lesson 24 (The handoff names the exact files and lines) |
| 2026-10-27 | Over memory limit | Builder ended Task 41 step 3 at 184k within 27 tool calls (third time): its Play scripts were ~18k characters each, written twice (file, then paste); the handoff alone was 33k characters | step 3 half done; phone half moved to Task 28 | Lesson 25 (A hook enforces the memory limit, not a guess): `.claude/hooks/agent-memory-cap.py` |
| 2026-10-27 | Task over its size (step over its call cap) | Task 42 step 2 used 4 Studio calls (cap 2): it fetched the background test run twice before it finished, and the results are still unread. The task's 6-call cap is spent without a fix | 2 Studio calls; one product decision | Lesson 29 (Fetch background work once, when it's done) |
| 2026-10-27 | Task over its size (step over its call cap) | Task 33 step 1 used 6 Studio calls (cap 5): its Play job never set done, and it wrote nothing until the end, so a second fetch was tried and the cause stayed unknown | 4 Studio calls and a whole Play start | Lesson 31 (A background job reports as it goes) |
