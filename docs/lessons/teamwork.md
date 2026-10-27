# Lessons: How the team works

About handing work between agents and asking owners. The map of all lessons is `docs/lessons/index.md`.

## Lesson 4: Never end a turn on a promise
- **What happened:** twice, an agent's report arrived and the main chat wrote "I'll start the next step" without starting it. Nothing ran for 9.8 hours, until the user asked "are you stuck?" (2026-10-27).
- **Do instead:** start the next step in the same turn. A Stop hook checks this (`agent-workflow.md`, "Never end a turn on a promise").
- **Who checks:** the main chat.

## Lesson 5: Don't ask owners about numbers players can't see
- **What happened:** `product` and `designer` were asked to approve limits such as 0.05 or 0.1 studs, which no player can see. Each one cost a full round of approvals.
- **Do instead:** `code_lead` sets tolerances and measuring methods inside the spec's rules. Owners are asked only about what a player could see or feel.
- **Who checks:** `code_lead`.

## Lesson 20: Cap each builder step by tool calls
- **What happened:** builders kept ending at 160k to 250k against the 150k limit (Tasks 29 to 37). Measured on 2026-10-27: an agent starts at about 50k before doing anything, and each tool call adds about 2.4k, so a 46-call step ends near 165k.
- **Do instead:** every builder step gets a cap of at most 30 tool calls in its handoff, and the builder stops at the cap. A step that needs more is split.
- **Who checks:** `code_lead`, the main chat.

## Lesson 23: A Studio script returns a short summary, never a list
- **What happened:** in Task 41 step 1 the builder stayed under its 30-call cap but ended at 222k tokens: about 7.7k per call instead of 2.4k, because its scripts printed whole lists (one line printed 301 points) (2026-10-27). The call cap only works when each call's output is short.
- **Do instead:** every script an agent runs returns at most about 20 lines, and any list at most 5 items plus a count. Long results go to a file in `work/`, and the agent reads only its summary. The handoff says this next to the call caps.
- **Who checks:** `code_lead` (in the handoff), `builder`.
