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

## Lesson 24: The handoff names the exact files and lines
- **What happened:** two builder steps in a row ran over their caps (37-6 on Studio calls, 41-2 on tool calls). In 41-2 the builder spent its 30 calls reading code to find where to edit, and ran only 2 of its 8 Studio calls (2026-10-27).
- **Do instead:** every handoff step lists the exact files (and functions or line numbers) to read and edit, and the builder reads only those. A builder that carries on from another starts from the state note, not from the code.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 25: A hook enforces the memory limit, not a guess
- **What happened:** the builder went over its 150k limit a third time (Task 41 step 3: 184k in 27 tool calls). The call cap and Lesson 23 both held, but its Play scripts were about 18k characters each, and it wrote each one twice (once to a file, then pasted into Studio). Every proxy cap missed a new way to grow (2026-10-27).
- **Do instead:** `.claude/hooks/agent-memory-cap.py` reads each project agent's real memory size before every tool call. At 85% it warns the agent to wrap up. A builder at its limit is blocked from everything except writing its state note in `work/`. Agents also write a long script once: paste it straight into Studio, never into a file and then again into Studio.
- **What happened again:** a fresh code_lead ended one Task 33 job at 208k of 200k in 31 tool calls. The hook only blocked builders, and no other agent's prompt had a call cap (2026-10-27).
- **Do instead (added):** the hook blocks every project agent at its limit, not only the builder. Every agent prompt carries a cap of at most 30 tool calls, and a job that needs more is split.
- **Who checks:** the hook; `code_lead` keeps handoff scripts short.

## Lesson 27: Every task close compares the scan with the planned reds
- **What happened:** two stuck spots at the cushion's front edge were found only at Task 41's review, though Task 41 didn't touch the cushion. Earlier task closes hadn't compared the scan's unlisted spots with the planned reds (2026-10-27).
- **Do instead:** at every task close, `code_lead` lists the stuck scan's unlisted spots and checks each one against the planned reds in `docs/progress/index.md`. Any spot that isn't planned is named at once and gets an owner.
- **Who checks:** `code_lead`.

## Lesson 30: A new lesson rechecks the open tasks
- **What happened:** Task 33's plan still fixed the beard pocket with a guard fitted to his skin, a kind of fix Lesson 19 had forbidden since. Nobody had checked the open tasks against the new lesson, so it was only caught when the handoff was written (2026-10-27).
- **Do instead:** when the main chat adds a lesson, it asks `code_lead` to check every open task's planned fix against it, and to change any that break it, before the next handoff.
- **Who checks:** the main chat (asks), `code_lead`.

## Lesson 33: A ruling names what each fix must leave alone
- **What happened:** in Task 33 product's ruling chose the forehead fix by what the roof was made of ("an added part → move or shorten it"). It missed that the plate is also a wall of the walking band, the only way to the Legendary eggs. So the measurement needed another ruling before anything could be built (2026-10-27).
- **Do instead:** a ruling that offers fix paths also says what each fix must leave untouched (the core path, a route, a ladder end). Then a measurement can pick the path without another round trip.
- **Who checks:** `product`; `code_lead` when it turns a ruling into a handoff.
