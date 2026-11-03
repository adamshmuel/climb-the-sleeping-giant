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
- **Also (Task 12c beard run, 2026-10-29):** an Edit names check found no grab prompt on `EggSpot_Rare_1`, because the game makes the prompt only in Play. A world thing the game makes at runtime is marked "made in Play" in the table, and the start that needs it is picked in the Play job's Server paste and held in that run's dry start (Lesson 124).
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

## Lesson 132: A red step needs Studio, and a full run goes to the runner
- **What happened:** Task 13b's handoff gave its red step 0 Studio calls, but tests run only in Studio, so the builder couldn't see red (the same mistake as Task 13 step 6b). Then three full runs ran inside the builder's Sonnet step, re-reading about 75k words each call at Sonnet's price, though the runner (Haiku) was built for them.
- **Do instead:** every red step budgets a full run (start and one fetch, cap 3). Every full run is its own step on Haiku (the `runner`); the builder and `code_lead` keep the code and the judging.
- **Who checks:** `code_lead` when writing a handoff; `scripts/job-check.sh --handoff` fails both.

## Lesson 142: A review's first-minute play and its must-shows get separate budgets
- **What happened:** Part 1 of the stuck-safety build review (the computer whole session, played blind) spent most of its 22 Studio calls turning the camera with the keyboard. It never reached the giant, so the Reset puff live, the landing within 1 s, the rescue and the loop home all moved to Part 3 (2026-11-01).
- **Do instead:** a review plan gives the first-minute play (what a new player sees and does first) its own small budget. The climb and the must-shows on the giant get their own part and budget, starting from a placed spot, never from a blind walk.
- **Who checks:** `product` when writing a review plan; the main chat when it reads the plan.

## Lesson 145: A phone review part holds at most 3 checks
- **What happened:** Build review Part 2 packed a whole phone session, 4 pill checks and a computer redo into one 30-tool-call job. The shots, and the copies to save them, used up the calls, and the job stopped at 18 of 24 Studio calls with most checks not reached (2026-11-01).
- **Do instead:** a phone part of a review holds at most about 3 checks, and saves all its shots with one copy command at the end.
- **Who checks:** `product` when writing a review plan; the main chat when it reads the plan.

## Lesson 163: A runner copies file paths from its prompt, never from memory
- **What happened:** twice on 2026-11-01 a Haiku runner typed the user folder wrong (`adamshmuth` instead of the name in its prompt). Each Read or Write failed and was retried the same way, and the names check spent all 6 of its tool calls.
- **Do instead:** a runner copies every path from its prompt letter by letter. On "File does not exist" it compares the path with the working directory the error names, fixes the first difference, and tries once more (`runner.md`, step 1). Prompts for a runner give full paths, written out once each.
- **Who checks:** `runner`, main chat (when writing a runner prompt).

## Lesson 167: A Play restart that pastes a big file gets a fresh agent

In Task 58b Step 2, the main chat resumed the same builder for two restarts. Each restart pasted the 584-line world script again, so the builder carried it three times and stopped at 148k of 150k before its last fetch, with Play still running.

- Before resuming an agent for a restart, add its size to the size of every file it will paste. If that goes over about two thirds of its limit, start a fresh agent with the state note instead.
- A fetch-only finish goes to the `runner`, never back to the builder.

## Lesson 173: A ruling on how a job measures reads the job's own lines first

In Task 58c, `product` ruled that the beard slip's 56.5 was counted from the wrong starting point and changed the spec's proof line. `code_lead` then read the job: it already took its starting value at the let-go, just before the jump. The ruling rested on a guess about the job.

- Before an owner rules on how a job measured something, `code_lead` sends the job's own lines that take the measure (the start, the peak, the bar).
- The main chat attaches those lines when it relays the question.
- **Who checks:** main chat (when relaying), `product`, `code_lead`.

## Lesson 175: Count the files a step edits before sizing it

Task 58b Step 3 asked one builder to rewrite about 10 test files that read the old leaning ladder. It hit its 30-call cap with 4 files and the lint runs left. Step 1 of the same task had stopped over its size too.

- Before sizing a step, search for every file that reads the thing being changed, and count them.
- A code step edits at most 5 files. More are split into steps of 5 or fewer (`docs/plans/handoff-template.md`).
- **Who checks:** `code_lead` (when writing a handoff), main chat (before starting a step).

## Lesson 192: Write "checked in Task N" for a later task's proof

In Task 58e code_lead wrote "proven in Task 58d" in a handoff. The handoff check reads "proven" as a claim about a Play step's starts (Lesson 120), so it failed the handoff.

- In a handoff, a proof that comes in a later task is written "checked in Task N", never "proven in".
- **Who checks:** `code_lead` (writing handoffs).

## Lesson 193: Name the later spec that reshapes each part, and give the plan a time budget
- **What happened:** stuck safety aimed at zero stuck spots on the whole giant, with no check for parts a later spec reshapes. Every scan hit became a task, even on the belly and nest areas that specs 3 and 5 rebuild, and each world change broke older tests, which were patched in place. The plan grew to 76 tasks in 12 days; the ladder task alone took about 12.7 h against 2 h. The red alert review on 2026-11-02 cut or moved what was left and saved about 12 to 15 h.
- **Do instead:** every plan task names the later spec that reshapes its area, if any, and does only the cheapest safe fix there ("Don't build what a later plan replaces"). Every plan has a time budget, and the main chat checks the "Red alert: a plan is eating too much time" triggers at each task close.
- **Who checks:** `code_lead` (writing and splitting tasks), `product` (rulings that add tasks), the main chat (the triggers).

## Lesson 196: "Go back" is an idea to test, not a safe default
- **What happened:** the face ladders' red alert (2026-11-02) asked "Do we need a ladder at all?" and "Where would it serve the game best?". The decision was to go back to the old leaning ladders instead. Nobody priced it: the old ladders were built by hand in Studio, and the script that removed them was never committed, so going back needed a rebuild and a new tool (Lune). The old ladders had known stuck problems, and spec 5 removes them anyway. The main chat passed the decision on and kept going when the cost jumped. Adam caught it.
- **Do instead:** in a red alert, "go back" answers the same questions as every other idea, says how it fixes the old design's problems, and is priced (a commit or script brings it back, or it's a rebuild). No idea rebuilds a part a later spec replaces; when a later spec has already chosen the end shape, prefer building that now. The main chat checks the decision against the brief's questions before acting, and stops when the cost jumps.
- **Who checks:** `product` and `game_creator` (the decision), every owner (their answers), the main chat (the check before acting).

## Lesson 198: Start a placement ruling with what sits at the top and who needs it
- **What happened:** two red alert rounds on the giant's face picked where the way up goes before listing what the player needs up there. The answer turned out to be only the cap's Legendary nests (round 3, 2026-11-02).
- **Do instead:** start every ruling on where a way up goes with a short table: what sits at the top, and which players need it. Then pick the route.
- **Who checks:** `product` and `game_creator` (rulings), `designer` (placing ways up).

## Lesson 199: When a part on a main character is questioned, question what pulls players there too
- **What happened:** round 1 of the face red alert kept the nose and forehead stops (the Dream Egg on his nose) without asking whether the gameplay needed them on the face. Moving the Dream Egg to his cap removed the whole face route (round 3, 2026-11-02).
- **Do instead:** when a part on a main character is questioned, also question the gameplay spots that pull players there. Moving one spot can remove the whole path.
- **Who checks:** `game_creator` (gameplay spots), `product` (rulings).

## Lesson 200: Four agents agreeing is not a check; ask what nobody tried
- **What happened:** in round 3 of the face red alert, all four owners picked one ladder by his left ear. The brief had hinted "a later spec already plans this", and everyone took that plan. designer noted that one left-side ladder favours the gardens on that side, but game_creator and product never judged that fairness. Nobody tried moving the top eggs down to the beard, or giving every player their own ladder to place. Adam came up with the ladder idea himself (2026-11-02).
- **Do instead:** follow "Think critically and creatively, in every job" (`agent-workflow.md`). Briefs never hint at an answer. Owners judge fairness for players on every side. When everyone agrees, ask what nobody tried. A new feature is weighed against the real cost of the fixes it replaces.
- **Who checks:** every owner (their answers), `product` and `game_creator` (the decision), the main chat (briefs and the check before acting).

## Lesson 201: A fairness check names where the ways up join
- **What happened:** Rule 73 (Every rank is fair from every way up) compared ways up that all meet at the lap landing, before the belly. So it could never see that one ladder above the belly favours one side (code_lead, red alert round 4, 2026-11-02).
- **Do instead:** every fairness check says where the routes join, and anything past that point gets its own left-against-right check.

## Lesson 202: Judge a one-sided route on the trip there and the trip home
- **What happened:** round 3 read "the brim pair at x −14" as all four cap nests being on his left, and nobody checked the way home. With one left ladder, the gardens on that side jump off and are home fast; the far gardens walk round his boots (game_creator, red alert round 4, 2026-11-02).
- **Do instead:** when judging a one-sided route, check both the trip there and the trip home. Read "pair" in a nest table as a mirror twin (Rule 72), and when a table lists one side of a mirrored giant, count both sides before judging fairness (product, same round).

## Lesson 204: Show both options as mockups before choosing between them
- **What happened:** in red alert round 4 the team weighed "two fixed ear ladders" against "raise your own ladder" from words only. The brief said "thinking only, no Studio", so designer made no mockups and game_creator and product never saw the options. product and the main chat also answered "the second one later", which is not in or out (Adam, 2026-11-02).
- **Do instead:** for a choice between looks or ways to play, designer mocks up each option from the fixed cameras, and the owners judge them side by side. Every option is decided in or out now.

## Lesson 207: Putting back is placing
- **What happened:** in the ordering test 6, a fresh product agent put Rare eggs 3 and 4 back before the ear ladders were chosen, because "it restores git's own spots; it chooses nothing new" (2026-11-02). Whether an old spot still works depends on the open change around it.
- **Do instead:** putting back, restoring or undoing to an earlier spot is placing, even when the spot is saved in git. It waits for every open change to the layer it sits on (`order-the-work` skill, "Placing").

## Lesson 208: Split a world-script step by layer before ordering it
- **What happened:** Task 60's handoff put scripts 04 (eggs) and 08 (route points) in the same step as the face-ladder removal, so the egg put-back rode along early with it (ordering test 7, 2026-11-02).
- **Do instead:** split every world-script step by the layer each script changes before ordering it. Putting eggs or route points back is its own piece, after every change to the ways up.

## Lesson 209: A task ends at its own goal
- **What happened:** Task 60's handoff put its own checks (walk test, after shots, full run) after the mockups, though they check parts of the world the ear-ladder build would change (ordering test 6, 2026-11-02).
- **Do instead:** a task ends when its own goal is done. A check of an area that is still changing moves into the task that finishes that area.

## Lesson 210: Agents ordered work by excuses until one checklist banned them
- **What happened:** ordering tests 4 and 5 put work before an open decision with "it's far from the change", "under every option it will look like this" and "the test reruns, so it will catch it". Rules spread over several agent files didn't stop it (2026-11-02).
- **Do instead:** every agent that orders work follows the `order-the-work` skill step by step and shows its answers, including the table of reasons that never count. A new excuse found in a test becomes a new row in that table.

## Lesson 211: A "Stands on:" line can't name a decision that is still open
- **What happened:** the plan check fails any "Stands on:" line that contains the word "open", so code_lead could not write "Adam's open pick between A and B" on Task 61 (2026-11-02).
- **Do instead:** the "Stands on:" line names the decision ("Adam's pick between option A and option B"), and a "Status: can't start" line right under it says it is still open. The main chat reads that line before starting the task.

## Lesson 212: A Studio step with no spare call can't absorb one failed call
- **What happened:** Task 60 Step 5 planned exactly 20 Studio calls against a cap of 20. One device call failed (orientation set before the device) and one did nothing, so the last phone shot was left for a resume (2026-11-02).
- **Do instead:** a Studio step plans at least one spare call per Play session under its cap. The handoff spells out the setup order where one call fails without the other (set the device, then the orientation).

## Lesson 214: Job-script checks don't fit spec files
- **What happened:** Task 60 Step 7's handoff told the builder to run `scripts/job-check.sh` on three spec files. Its job-script rules (300 lines, no line starting with "(") failed on code already in those files, and the step stopped for a ruling (2026-11-02).
- **Do instead:** a handoff names `job-check.sh` only for job and world scripts. Spec files pass on StyLua, selene and `luau-lsp analyze`, then their narrow run.

## Lesson 215: A red world test can come from an old drift, not the newest change
- **What happened:** after Task 60 took the face ladders off, a Zones test missed 12 standing spots. The ladders weren't the cause: the zone box `Beard_Head` had moved away from where `tools/world/02-zones.luau` puts it, some time after Task 58e (2026-11-02).
- **Do instead:** when a world test turns red, first compare the live parts it reads with their build script's values, before blaming the newest change.

## Lesson 220: Measure a disputed fact before weighing two rulings
- **What happened:** game_creator and product split over whether players could reach the pillow from the meadow. That is a fact, not a design choice. One read-only Studio call settled it: every pillow edge is 9+ studs above what's next to it, and a jump reaches 7.2 (2026-11-02).
- **Do instead:** when judges disagree about something the world can answer, measure it in one read-only call first, then weigh the rulings.

## Lesson 260: A second Play round on the same task starts "Stuck on one problem"

Task 61a's hours were counted only at task close, so it ran through five Play rounds before any alarm went off.

**Do instead:** the second Play round on the same task that ends without a pass starts "Stuck on one problem", even if the task's hours still look fine.

## Lesson 263: A spec limit names what the player feels, not a stand-in

In Task 61a the spec said every edge where the tie meets the cap is within 0.5 studs, as a stand-in for "never thuds". Nobody checked it against the game's thud setting: a free fall of about 0.25 studs already lands fast enough to thud. The fold was refit twice for a number the player never feels.

**Do instead:** before a spec sets a limit, ask whether it is what the player feels or only a stand-in for it. Write the bar the player feels (here: no thud), and measure the stand-in against it before building to it.

## Lesson 265: Prove a player can walk to a way up before building the way up

Every check of the cap ties started with the bot already at a tie's foot. Nobody walked from the belly crest, where players really come from, to that foot until Task 63, the last task before Gate 4. Adam caught it after about 2 h on Task 61a. If the foot can't be reached, the fix may be moving the tie, which throws away every task built on it.

**Do instead:** when a way up is placed or moved, the first check is a no-jump walk from where players really come from to its foot. It is decision work, ordered before any task that fits, sweeps or mirrors the way up.

## Lesson 266: Every red flag lists the smallest keep-what's-built piece first

In two red-flag rounds on Task 61a, four agents framed the problem as "where should the ladder go" (move it, rebuild it, a new route). Nobody asked what small piece connects the arm players already reach to the cap tie already built. Adam had to propose the wooden walkway.

**Do instead:** in every red flag or red alert, list first the smallest new piece that connects what players reach to what is built, measured and priced, then any bigger idea (agent-workflow.md, "Keep what's built, add the smallest piece").

## Lesson 268: Check the docs before naming an engine limit to the user

The main chat told Adam "Roblox climbing does not let a character turn" as a possible cause without checking. The docs say nothing like it. It later turned out to be true, but only because the builder measured it.

**Do instead:** before naming an engine limit to the user, even as one option among several, check the docs (roblox-docs skill) or say plainly that it is untested.

## Lesson 272: Run `date` before writing any time in a log

Night-log times written from guesses ran about 35 minutes ahead of the clock, so the 1-hour red-flag line was measured wrong.

**Do instead:** run `date` before writing any time in a log or a report.

## Lesson 278: Price a task from the plan and the progress file, and use the larger

A way up was priced from the plan file while the progress file had a bigger size (Task 63: 2.5 h against 3.5 h).

**Do instead:** every price check reads both files and uses the larger number.

## Lesson 290: List each result and the pick it leads to before a trial

A trial measured angle limits, but every result led to the same pick, so the time bought nothing.

**Do instead:** before a trial, list each possible result and the pick it leads to. Cut any case that can't change the pick.

## Lesson 291: Price the safety net before chasing "every try works"

Trials chased "every climb works", while the stuck rescue already made every failed climb harmless.

**Do instead:** before a trial, name what the player needs when the thing fails, and price that safety net first.

## Lesson 292: Check a case's last safe spot matches a real player's

A rescue result used as decision evidence ("the rescue lands him on top") came from a safe spot left by an earlier test case. A real kid is rescued at the tie's foot.

**Do instead:** before deciding on where the rescue puts a player, read the safe-spot rule in the code and check the case's last safe spot is where a real player's would be.

## Lesson 293: Count only real rules before flagging a spec split

A spec was reported as over the 15-rule limit. The count included retired numbers ("Rule 81: not used") and changes to rules that belong to other specs. It really had 14.

**Do instead:** count only real rules, not "not used" lines or changes to older rules, before flagging a split.

## Lesson 298: A task review checks git for the files it depends on

The CapTies test and world script 20, which Task 61a depended on, had never been committed. code_lead found it only at the 61a review.

**Do instead:** every task review runs `git status` and checks that each file the task depends on is already in git, or is part of this task's commit.

## Lesson 299: When a design pick replaces what a plan fixes, re-plan it

Plan 7 was meant to fix one way up. The thing it fixed was replaced three times mid-plan (face ladders, ear ladders, cap ties, then the walkways). Each new design came in as more tasks with no fresh budget, so the plan grew from its first size to about 25 hours.

**Do instead:** when a design pick replaces what a plan is fixing, stop and re-plan and re-price it as a new plan at that moment, before any task of the new design starts.

## Lesson 300: Check the spec's proof list before planning a proof task

Plan 7 planned a whole real-controls play (Task 63b, computer and phone) that the spec's proof list (Rule 101) had already given to the build review. product found it at the 10-task check.

**Do instead:** before planning a proof task, check whether the spec's proof list already gives that proof to another step. If it does, plan only what that step doesn't cover.

## Lesson 301: A fixed camera moves to another task, never out

code_lead's plan 7 rewrite dropped the `tie-top-side` shot. It is on designer's fixed camera list, so only designer can remove it. product caught it.

**Do instead:** before cutting any shot or check, grep `look-cameras.md` and the spec's proof lists. A fixed camera or a listed proof moves to another task, never out.

## Lesson 303: Every promise in a task header has a budgeted step

Task 61h's header promised a quiet fall from the cap onto the cap and the "CapToCapFall" analytics event, but its steps never budgeted either. code_lead found the gap only while writing the handoff, so a new task (61n) was added.

**Do instead:** when a plan is written or rewritten, match each promise in a task header to a budgeted step, and match each analytics event in the spec to a named task.

## Lesson 305: One Play case per behaviour the player feels

Task 61h's Play job listed one case per spot: both mirror sides of the same fold, which run the same code. It also asked for two shots of a 1-second puff, taken after a script that runs over 2 seconds, so the shots could never catch it. Both added time to a task already near its line, and the red-flag meeting cut them (product, game_creator, designer and code_lead, 2026-11-03).

**Do instead:** each Play case names the behaviour the player feels that it proves. A mirror side or a second spot gets a case only when the measured spots or the code differ. Before asking for a shot of an effect, check how long the effect lasts. If it ends before the capture, prove it with the game's own signal.

## Lesson 308: Rule on a Play result from its own lines
In the 61h loop meeting, one answer said "never in the air" from the brief's summary. The run's own line "try 1: ended" showed a real fall at the cap's front (2026-11-03).
→ Before ruling on a Play result, read the run's printed result lines in the state note, not only the brief's summary of them. A brief that sums up a run also quotes its result lines.

## Lesson 312: A Play case on a spot a later task builds over belongs to that task
Task 61h ran its let-go case on the belly at the tie's foot, where Task 61w builds its chute deck (2026-11-03). Its result was always going to be redone, and three runs went into it.
→ Before any Play case, check whether a later task builds or reshapes the spot it lands on. If so, the case moves into that task ("Don't build what a later plan replaces").
