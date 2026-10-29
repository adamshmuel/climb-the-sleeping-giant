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
- **Also (Task 33 step d):** when a script's output is cut short, keep its end, not its start. The world script's result lines come last, and a cut at the first 700 characters lost the line for the one part that was placed.
- **Also (Task 45 step 1):** never call `get_console_output` after a test run. It returns the whole log of earlier runs (about 10k tokens). Read only the run's own short return value.
- **Also (Task 54 call 5, 2026-10-28):** the crease check reported only "4 of 5" per side, so the failing call couldn't name the open point for the next owner. A check that can fail names each failing point (its label and which test missed), not only the count.
- **Also (Task 8 call 4, 2026-10-28):** Studio cuts a call's returned text at 1024 characters, and the legs job's summary came to about 1500, so the cut would have lost the cuff lines that mattered most. code_lead caught it in the read before the paste. The writer estimates the length, prints the most important lines first, and ends with `string.sub(text, 1, 1000)`.
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
- **Also:** a ruling that asks for a check ("no shortcut by a jump") writes down the rule to check by: how high, how far, and from which spots. Otherwise the check invents its own rule, and its result needs another round trip (Task 33's beard shortcut check). In the same call, the check follows every spot it finds: where it leads by walking, and whether players can already reach it today.
- **Also (Task 28, 2026-10-28):** Rule 82's jump check said "at least 12 studs above" but never said what it guards, so 12 of 15 guards failed on spots below them. Every reach limit names its purpose (for example, "a new way in from outside") and which spots count, above and below, before the job is written. `code_lead` checks an older ruling for this when it writes a handoff from it.
- **Also (Task 54, 2026-10-28):** the nest limit was written as a distance (4 studs) without checking where the slot's mouth sits. The mouth is 3 to 5 studs from the nest, so no fill could ever pass, and a Studio call was spent proving it. Write each limit as what the player needs (for example, "can see and grab the egg"), then check it against the measured shape before any trial.
- **Also (Task 54 second failure, 2026-10-28):** both failures on the brim came from stand-in limits (a gap size, a count of closed points), not from anything a player feels, and they nearly cut a fix for the worst stuck spot. Before a stop rule sends work back, the owner checks whether each failing limit is one a player can feel. If not, the owner lowers it, and the Play check decides.
- **Who checks:** `product`; `code_lead` when it turns a ruling into a handoff.

## Lesson 36: Stand-in numbers name what replaces them
- **What happened:** Task 33's band test had to use measured stand-in numbers for the walking band, because the Play walks that should record the band never ran. They moved to Task 28 (2026-10-27).
- **Do instead:** when a test runs on stand-in numbers, the plan names them and the recorded run that replaces them, and puts that replacement in a named task step.
- **Who checks:** `code_lead`.

## Lesson 39: Count the list before sizing the task
- **What happened:** Task 27 was planned at 4 Play batches and 20 Studio calls before anyone counted its spots. Step 2 found 681 steep spots (14 batches), so the work grew to 47 calls across three tasks (2026-10-27).
- **Do instead:** when a task works through a list (spots, parts, places), its first step counts the list in one read-only call, and `code_lead` sizes the task from that count. Product picks a sample rule before Play starts if the count is large.
- **Also (product):** before a check lists spots, split them by the idea's "What matters most" tiers: play every core spot (near places players need, or out of the rescue's reach) and sample the rest, for example the steepest spot per 4-stud square.
- **Who checks:** `code_lead` (in the plan and the handoff), main chat.

## Lesson 59: A handoff that names a job's walk points to the lines that do it
- **What happened:** Task 48's handoff said the Play job walks onto the boot ramp, but the saved job file had no ramp leg, so the builder wrote about 70 lines of it mid-step (2026-10-28).
- **Do instead:** when a handoff names a walk or check a saved job must do, its author reads that job file first and names the lines that do it.
- **Also (Task 28, 2026-10-28):** Task 28 step 1's seed list was never checked against the world: 14 seeds had no floor, because the job went 3 studs along each part's own "up" and the forehead plates are turned -80°. Seeds come from positions really measured (where characters settled, a part's top found from its real turn), never from a part's own axes unread, and the handoff names where each one came from.
- **Also (Task 28 step 5, 2026-10-28):** a guard's "own top" found by a down ray can hit a near-upright side face and still look like a top: 4 of 5 open Sock guards failed this way. Before a hit becomes a start, check its normal points up and that the guard is the first floor under the start (ON GUARD).
- **Who checks:** `code_lead` (in the handoff).

## Lesson 60: A plan counts Studio calls for every step
- **What happened:** Task 28's plan counted only shots (up to 15). Once checks from earlier tasks moved in and its Studio calls were counted, it came to 58 calls plus 4 spares, about 4 times the size, and product cut it to 36 plus 3 (2026-10-28).
- **Do instead:** every plan step writes its Studio-call count from the start, even a step that only takes shots. A phone check re-runs only what the phone screen changes (shots and the on-screen buttons and text), never walks, which drive the character the same way on both screens.
- **Also (Task 28 close, 2026-10-28):** Task 28 ended at 42 builder Studio calls against 36 + 3, and nobody saw the overrun until the close. After every step, the main chat reports the task's running Studio-call total against its plan, and a step that would pass the plan goes to product first.
- **Also (Task 33b, 2026-10-28):** code_lead's names-check, confirm and cleanup calls were left out of the totals, so Tasks 54 and 33b looked smaller than they were. Every Studio call counts toward the task's cap, whoever makes it (builder, code_lead, designer). A plan lists code_lead's calls as their own lines (product ruling).
- **Also (Task 7 step 4, 2026-10-28):** a paster's 10-call slot list had no slot for `list_roblox_studios` or the device-simulator skill fetch, so it used 10 calls for 8 slots and the task went over its budget. A call list gives every Studio call a slot, the studio list included, and the handoff copies the device API it needs (`StudioDeviceSimulatorService`, the device by name, `StopSimulationAsync` to turn it off, run in the Client datamodel) so no skill is fetched.
- **Also (Task 8 handoff, 2026-10-28):** Task 8's plan block, written before this lesson, had no size and no Studio-call count, and it was found only when its handoff was due. When a plan task closes, `code_lead` checks that the next task's block has a size and a call count, and sizes it before the handoff is due.
- **Who checks:** `code_lead` (in the plan); `product` when it sizes a task.

## Lesson 61: A handoff's world names are checked before the builder starts
- **What happened:** three handoffs in a row relied on world things that weren't there: Task 48's job had no ramp leg; Task 28 step 1's seeds had no floor; step 1b's gateway sources (lap planks, side pads, the lap landing) are not built yet, so the builder stopped with 0 Studio calls (2026-10-28). Lessons 59 and its extension didn't stop the third one.
- **Do instead:** the handoff lists every world name, position and part kind it relies on in one table. `code_lead` checks the table in one read-only Studio call (or against the build scripts and progress rows for parts not built yet) and marks each row "exists" or "built by <plan and task>" before the builder starts. Now a rule in `agent-workflow.md` ("World names checked before the builder starts").
- **Also (Task 28 step 1b, 2026-10-28):** the table was checked, but the job looked up "Sock_2" where the part is "SlideGuard_Sock_2", so 5 seeds were never tested. Every job that finds parts by name prints "found N of M" for each lookup, and a lookup that finds fewer than it expects stops the job before the long part.
- **Also (Task 28 step 4c-2, 2026-10-28):** the main chat started a re-run's writer and paster without the world-name check, because the re-run looked like a small fix. The walks job looked up "SlideGuards.Sock_1" where the part is "SlideGuard_Sock_1", the same bug as step 1b, and stopped after 4 Studio calls. A re-run or a fix is a handoff too: no paster starts until code_lead has checked every name in every job file against the running world (one read-only call) and written "names checked" in the state note.
- **Also (Task 52, 2026-10-28):** a Studio lookup that splits a path at its dots can't find a test module such as "CaughtCard.spec". Look up names that contain a dot with `FindFirstChild("X.spec")` on their parent, never through a dotted path.
- **Also (Task 53, 2026-10-28):** the plan's made-up test worlds were written without measuring, and two would have tested the wrong thing: a turned plain block's outer box is its own turned box, and a thin plate's flat top edge is a real walk-map spot. Before a handoff names a made-up test world, `code_lead` builds it once in a throwaway world in the names-check call and writes down what it measured.
- **Also (Task 54, 2026-10-28):** a search for `head_with_beard` across Workspace found 2 of 1, because a mockup folder held a copy. Every job finds the giant's parts by their full path (for example `Workspace.Giant.head_with_beard`), never by a name search, and prints "found N of 1".
- **Also (Task 54 spare call, 2026-10-28):** a names check expected 1 `ForeheadGuard.SideRail`, copied from an earlier table that looked up only the first match, but the world has 4. The job stopped before it measured anything, and the task's last spare call was lost. Expected counts come from one fresh count of every child with that name. A surplus of a part that is only "left alone" is reported, never a stop; only a missing part, or a surplus of a part the job changes or measures, stops the job.
- **Also (Task 33b names check, 2026-10-28):** a stored start line was parsed with a pattern that expected commas, but it was stored with spaces, so the re-check printed nothing. A names check prints the raw stored line first, and parses it only after seeing its format.
- **Also (Task 12c names check, 2026-10-29):** the names check looked for the Legendary nests in the world, but they aren't built yet, and their positions are only in the spec. A names check looks up anything not yet built in the spec and progress files, and gives it a "built by <plan and task>; spec positions used" row with the spec's numbers, never a search.
- **Who checks:** `code_lead`; the main chat does not start a builder on a handoff without the checked table.

## Lesson 89: A step's reading fits inside its cap
- **What happened:** Task 10 step 5 (the Play check) stopped at its 30-tool-call cap with no shots taken: the fresh builder spent about 25 calls reading the handoff, the lessons index, the lesson files and the workflow rules, and the step's 12 Studio calls left out the device-simulator skill read and a console read (2026-10-28).
- **Do instead:** the main chat's prompt names at most 5 files to read. code_lead's handoff step quotes the lesson lines it needs, so the builder opens no lessons index or rules for it. A Play step's cap counts its reads, setting and resetting the device, and one console read.
- **Who checks:** the main chat (prompt), `code_lead` (handoff step).

## Lesson 97: The task that builds a look checks it in Play
- **What happened:** Task 11's Play check marked Rule 33's lavender puffs "not checked", because no puff exists until Task 14 builds it (code_lead's review, 2026-10-29).
- **Do instead:** the plan names the task that builds a look as the one that checks it in Play, with shots timed to catch it. An earlier task doesn't list that look among its checks.
- **Who checks:** `code_lead` (plan).

## Lesson 98: Each shared place word is defined once
- **What happened:** in Task 11, "on the giant" meant more in one rule than in the rules next to it, so the code had to stop and ask product which meaning was right (whether the pillow counts).
- **Do instead:** a spec defines each shared place word once, under "Words used here", and every rule points to that definition.
- **Who checks:** `product` (spec), `designer` and `game_creator` (spec review).

## Lesson 99: Writing a Play job is a step of its own
- **What happened:** Task 11 step 4 held three jobs (the client button, the full test run and writing the Play job), and the builder used 37 tool calls against a cap of 30, ending without a hand-back.
- **Do instead:** writing a Play job is its own step in the handoff, with its own cap, separate from the code and from running the job.
- **Who checks:** `code_lead` (handoff steps), the main chat (prompt cap).

## Lesson 100: Set a proof's tries by how much the spot matters
- **What happened:** Task 12's Play proof copied "3 of 3 tries" onto every spot, low-value ones too, and grew to about 80 tries that couldn't fit 6 steps (code_lead and product, 2026-10-29).
- **Do instead:** the plan sets how many tries each spot needs by how much it matters: one try where players can't normally go, 3 of 3 where they can. A proof too big for one task is split into its own tasks when the plan is written, not at handoff.
- **Who checks:** `code_lead` (plan), `product` (approves the proof).

## Lesson 103: The memory hook always lets the report through
- **What happened:** Once an agent was over its memory cap, the hook blocked every tool, the hand-back too, so two builders ended with no report (Task 11 and 12, step 4).
- **Do instead:** the hook lets the report through every time. A blocked report is a tool problem to fix, not the agent's fault.
- **Who checks:** the main chat (hooks).

## Lesson 105: Measure the place, or quote the newest ruling
- **What happened:** Task 12's plan called the pillow Meadow ground from the spec's old wording, and a later ruling had already called it Belly ground (Task 41). Both came from old text, not a check.
- **Do instead:** a handoff names a spot's zone only from a `Zones.zoneAt` reading in the names-check call. Before quoting an owner's decision, search `work/` and `docs/` for later rulings on the same thing and quote the newest.
- **Who checks:** `code_lead` (handoff), `product` (rulings).

## Lesson 107: Every whole-session proof grabs after a real respawn
- **What happened:** Only a real-key Reset before a grab showed that a player may get no egg after a respawn. No earlier Play log covered it (Task 12 step 5).
- **Do instead:** every whole-session Play proof includes at least one grab after a real respawn.
- **Who checks:** `code_lead` (plan), `product` (build review).

## Lesson 112: Decide from the numbers when the timing makes the result certain
- **What happened:** A Play test already showed a rescue loop that the timing made certain (0.3 s to walk back, 3 s to be rescued again), yet the first ruling waited for another Play run to show it.
- **Do instead:** when the timing makes the result certain, the owner decides the fix from the numbers now and doesn't spend a Play run on it.
- **Who checks:** `product`, `game_creator`.

## Lesson 113: Every size counts the Studio calls of its test runs
- **What happened:** A ruling counted Task 12e's test runs as 0 Studio calls, but the red run, the full run and its fetch need 3, which left the task no spare call.
- **Do instead:** every size in a ruling or plan counts the Studio calls of its test runs.
- **Who checks:** `product` (rulings), `code_lead` (plan).

## Lesson 115: Don't start a test name with "picks the"
- **What happened:** In the Task 12e handoff, a test named "picks the safe spot" failed `scripts/job-check.sh --handoff`. The check reads "picks the" as a job picking a world part by name, and wants that part in the world-names table.
- **Do instead:** name tests by where the player ends up, for example "lands on the safe spot" or "ends at the safe spot", never "picks the ...".
- **Who checks:** `code_lead` (handoff), `builder` (test names).
