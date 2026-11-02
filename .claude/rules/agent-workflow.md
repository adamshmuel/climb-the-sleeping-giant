# Agent workflow

How the project agents work together. Today: `game_creator`, `designer`, `product`, `product_reviewer`, `code_lead`, `builder` and `runner` (`qa` comes later). New agents get a row in each table below.

## The goal comes first

The game's goal is to go viral. Every look, feel and gameplay decision, review and approval passes the viral test in `viral-goal.md`.

## Think critically and creatively, in every job

Every agent, in every job (ideas, designs, specs, plans, reviews, fixes and rulings), thinks like this (Adam, 2026-11-02):

- **Start from the player's problem, not from the current design or a plan already written.** An existing design or a later spec's choice is one idea to test, never the default answer.
- **Look for a different kind of answer**, not only a better version of the same thing. For example: instead of placing ladders on a wall, give every player a ladder to place themselves, the way soldiers climb a castle wall.
- **Keep what's built, add the smallest piece.** Before any answer that moves, rebuilds or replaces work already built, ask: "What is the smallest new piece that connects what players already reach to what is already built?" (for example, a short plank from the arm to a ladder that's already there, instead of moving the ladder). Measure the shortest gap from the spot players reach to the thing that's already built, and price that answer first. Every red-flag meeting and red alert lists this answer, with its cost, before any other. Nobody on the team proposed the plank from the arm to the cap ties; the user had to (Adam, 2026-11-02).
- **Challenge every answer, your own and other agents'.** Ask what it breaks for the player. Agreement between agents is not a check: if everyone picked the same answer, ask what nobody tried.
- **Owners check their own area every time:** `game_creator` and `product` judge every idea for the players and the gameplay, including fairness (does a player on one side or in one spot get a head start?), even when another agent raised it only in passing.
- **Compare real costs.** "It's a new feature" is not a reason to drop an idea. Weigh it against the real total cost of the fixes it replaces (tasks done, tasks still planned, tests to rewrite). A string of fixes can cost as much as a feature.
- **Briefs don't steer.** A brief states the player's problem, the facts and the questions. It never hints at an answer, such as "a later spec already plans this". It always gives the big picture as facts: what the problem has cost so far, and what it blocks.
- **See the options before choosing.** When the choice is between looks or ways to play, `designer` makes a mockup of each option from the fixed cameras (computer and phone) and the views it changes, and `game_creator` and `product` judge them side by side before anyone picks. A choice made from words alone is not finished. A brief for such a choice never says "thinking only".
- **No "later".** Each option is in or out now (`sdd.md`). "Build X now and Y later" is two answers: decide Y too.

## Order work by what it stands on

Work done in the wrong order gets done twice. So every task is ordered by what it depends on, never by what is in front of us (Adam, 2026-11-02).

**The method is the `order-the-work` skill** (`.claude/skills/order-the-work/SKILL.md`). Every agent that orders work, writes a "Stands on:" line, rules on an order or checks one follows it step by step and shows its answers: decision first, the layer map, one goal per piece, the table, the reasons that never count, then the order. The skill holds the five generic layers. `product` writes this game's own layer map in `docs/layers.md`.

The short version:

- **Every task has a "Stands on:" line.** It lists each thing that must be final before the task can be done once and never redone. A task that depends on nothing says "Stands on: nothing".
- **Final means decided and built.** An open decision is never final, and neither is a part that any step will still add, move, reshape or remove.
- **A task starts only when everything it stands on is final.** Never "do it now and redo it if it changes". Distance from an open change, a guess about how an option not yet chosen will look, "a test that reruns will catch it" and "it closes a task already started" are that same thing, and never count as reasons to go early.
- **An order already written is an idea to test, not a fact,** even one the user approved before.
- **Who does what:**

  | Who | Job |
  |---|---|
  | `product` | Writes the "Stands on" list for every piece of work it specifies, rules on or changes |
  | `product_reviewer` | Writes the "Stands on" list for every fix in a **changes** verdict |
  | `code_lead` | Copies the list into each task and step, adds lists for the tasks it creates, and orders the work by them |
  | Main chat | Before starting any task or step, reads its "Stands on" line. If anything on it is still open, it doesn't start the task and takes the order back to `product` |

- **The check:** `scripts/job-check.sh --plan <file>` fails a plan or handoff where a task or step has no "Stands on:" line, stands on something marked open, or comes before a task or step it stands on. `--handoff` runs the same check.

## Everyone uses the game

Nobody approves what they haven't seen in the running game. Reading code and passing tests is not enough.

- Whoever builds, reviews or checks anything the player sees or does plays it in Studio first:
  - start Play (mute the sound if a session rule says so);
  - walk the character through it with the Studio tools;
  - take `screen_capture` screenshots of the real play screen.
- Each check looks at:
  - **Computer and phone:** the computer screen, and a phone screen through Studio's device simulator;
  - **Every state it touches:** for example each area of the map, each phase of an enemy or event, carrying an item, and being caught or defeated.
- Screenshots are evidence: a report names what they show, and compares them with the spec and the approved mockups.
- Problems are judged on the whole screen, not only the part the task changed: something covering the main character or enemy, text cut off at an edge, or controls overlapping are problems even if no rule names them.
- If a tool can't do something (for example, it can't capture a screen), test it in Play before believing it, and tell the main chat. Never quietly push a check to "later".
- **A Play script plays like a player, not a robot.** Whoever writes a scripted Play job (usually `code_lead`) makes it act the way a real player would. Each case starts the way a player arrives: standing on the ground, not left hanging from the case before. When the character stalls, the script reacts like a person: turns, steps back or jumps, a few times, before it calls a fail. A stall is never reported as a cause ("too slow", "can't climb") until a screenshot from the player's camera shows what really stops him. A turn or a retry that a player would make is a pass, not a fail. On 2026-11-02 a held stick wedged the character between a ladder and the giant's head and looked like a slow climb; the user saw it from one screenshot (Adam, 2026-11-02). `builder` and `runner` run a job exactly as written, so this check belongs to whoever writes the job and to the smoke run below.

## Before and after: a look never gets worse

Any task that changes something the player can see (a part, a model, a color, a light, a button) proves it didn't make the game look worse. This covers fixes too, such as a safety fix, a fit fix or a route fix, not only look tasks (Adam, 2026-11-02).

1. **Fixed cameras.** `designer` keeps one list of fixed cameras for the version in `docs/design/<version>/look-cameras.md`: the wide view a new player first sees, the main character's face, and each spawn view, each with its exact camera position and field of view, on computer and phone. It writes the list the first time a task needs it.
2. **Before shots.** Before the first world change, the task takes every fixed camera that shows the changed area, on computer and phone, and saves the shots in `work/<task>/look-before/`.
3. **After shots.** After the change, it takes the same shots from the same cameras and saves them in `work/<task>/look-after/`. Close-ups of the changed part may be added, but never replace the fixed shots.
4. **Designer judges side by side, before the commit.** For each pair: **same or better**, or **worse**, with the reason. One "worse" sends the change back, even if every test and every other rule passes. Saving time is never a reason to accept a worse look (`viral-goal.md`).
5. **The plan budgets it.** `code_lead` adds the before shots, the after shots and the designer check to the steps and caps of every task that changes what the player sees.

### Red alert: a main character or the first view got worse

A "worse" on a main character (the hero, the boss, the giant) or on the first view a new player sees is a **red alert**, not a normal "changes". Fixing it one patch at a time is how a fix makes the game worse. So all work on that change stops, nothing more is built on it, and the team steps back together (Adam, 2026-11-02).

1. **The same brief to everyone.** The main chat sends `game_creator`, `designer`, `product` and `code_lead` the same short brief: the problem the change was meant to solve (what the player suffered), and the before and after shots.
2. **Each thinks from the goal, not from the last design.** Each answers from its own area, in one reply:
   - **Do we need this thing at all?** Can the player's problem be solved another way, without it? (For example: let players climb a part directly instead of adding a ladder to it.)
   - **If we need it, where or how would it serve the game best?** Where does it help play, keep the main character looking good, and pass the viral test (`viral-goal.md`)?
   - **What does each idea cost** to build, and what work already done does it keep or throw away?
   There is no fixed number of options. One good idea that fits the goal beats several made only to have a choice.
   - **"Go back to the old design" is an idea like any other, never the safe default.** It answers the same questions. If the old design had known problems, it says how it solves them, or it is out (Lesson 196).
   - **Price every idea before choosing.** An undo is only cheap if a commit or a script can bring it back. A part built by hand in Studio costs a rebuild.
   - **No idea rebuilds a part that a later spec replaces** ("Don't build what a later plan replaces").
3. **One decision.** `product` weighs the answers with `game_creator` and picks one direction, with its reasons and the viral-test answer. The "Asking the user" checks apply as usual.
   - **The main chat checks the decision before acting on it:** does it answer both questions above, is it priced, is it fair to players on every side, does it avoid rebuilding what a later spec replaces, and did someone ask what nobody tried ("Think critically and creatively")? If not, it goes back to `product` with the missing part.
   - **If the cost jumps while building** (a new tool, a lost script, a rebuild by hand), the work stops and the decision goes back to the team. It is never pushed through.
4. **Then build.** Only the chosen direction goes into a plan and a task. It passes the before-and-after check like any other look change.

## Shared reference library: `references/top-games/`

Real gameplay screenshots and gameplay summaries of the top Roblox games, shared by every agent. It lives in the project and is ignored by git, because other games' pictures belong to those games. Any agent that needs it keeps it current with the steps below.

```
references/top-games/
  last-search.txt      date of the last full search (YYYY-MM-DD)
  <game-name>/
    shot-01.jpg ...    real gameplay screenshots
    summary.md         the game's gameplay, explained
```

- **Empty or missing:** do a full search.
- **`last-search.txt` older than 3 months:** do a full search and replace the old folders, because the charts change.
- **Otherwise:** use it, and add any game you need that isn't there.

**Full search** (tested 2026-10-11):
1. **Games:** the top 20 of `top-playing-now` (`roblox-trends` commands 1 and 2, skip sponsored games), plus any games the current work needs, such as an idea's competitors.
2. **Screenshots**, for each game:
   - In the built-in browser, open `https://www.bing.com/images/search?q=<game name> roblox gameplay screenshots`. Don't use Google: it shows a "prove you're not a robot" check, and agents never complete such checks.
   - Collect the full-size picture links with the browser's `javascript_tool`:
     ```js
     [...document.querySelectorAll('a.iusc')].map(a => JSON.parse(a.getAttribute('m')).murl)
     ```
   - Download them with `curl`, then look at every picture. Keep only real in-game screens that show the world and the buttons. Delete posters, title cards and broken files.
   - Keep at least 5 per game. If there are fewer, search again with other words, such as "<game name> roblox screenshot" or "<game name> roblox ui".
3. **Summary**, for each game: web search "<game name> roblox gameplay explained", read the best 2–3 results, and write `summary.md`: the core loop (the action players repeat), progression, what's sold, why players come back, and how it looks. Put the source links at the bottom.
4. Write today's date into `last-search.txt`.

**Loading tools.** Some tools must be loaded before use. If a browser or Studio tool isn't available, load it with `ToolSearch` (for example `select:mcp__Claude_Browser__navigate,mcp__Claude_Browser__javascript_tool`). If it still won't load, stop and tell the main chat which tool is missing.

## Adam only approves

Adam's only jobs are the gates and the rare decisions that are his to make (see "Asking the user" below). Never give him manual work, such as resizing windows, clicking in Studio, or setting things up. Agents and the main chat solve it themselves, or accept the limit and say so in one line.

**Stop when Studio isn't connected.** If a step needs Studio and `list_roblox_studios` comes back empty, the agent stops and reports it before doing anything that depends on it. It never picks a workaround on its own.

**When one agent works, the whole team works.** While a step is under way (any agent is working on it), the main chat starts or resumes any other agent that step needs, such as an owner to answer a question or check a change, without asking Adam. Relaying messages never needs permission.

**Starting a new step of the flow needs Adam's go-ahead.** A "step" here is one of the numbered steps in "The flow" below (idea, design, specs, plan, code), never a task. When one of those steps is finished, or the work is waiting at a gate, the main chat doesn't start the next flow step on its own. It says which step is next and waits for Adam.

**Inside coding, the main chat never waits between tasks.** Once Adam says "let's start coding X" (or has pre-approved it), the main chat runs X to its next gate on its own: after a task is committed it goes straight to the next task in the plan's order, starting `code_lead`, `builder`, `qa` and the owners as needed. It stops only at a gate (Gate 4 for each finished feature), for the "Asking the user" list, or when only Adam can do something (for example, Rojo Connect). It tells Adam what finished in one line and keeps going.

**Never end a turn on a promise.** When an agent's report arrives, that agent has stopped. In the same turn, the main chat starts the next step (resume an agent, start a fresh one, or relay a question). It never ends a turn saying "I'll start X" without starting X. Before telling Adam "X is running", `ListAgents` must show X running. A Stop hook (`.claude/hooks/no-idle-stop.py`) blocks the first try to end a turn that breaks this.

## Stuck on one problem: product decides

This covers **every task that costs too much time**, whatever it is: a feature, a rule, a tool or scenery. It starts at any of these: a task goes past its planned size, the team fails twice on the same problem, or a second task is added for the same thing.

The main chat also counts tasks per object or place. When a second task is added for the same thing, it takes that to `product` as a product decision (below), even if nothing has failed yet.

When the team fails twice on the same problem (two tries, steps or tasks that end "tried, nothing built", or a check that keeps failing), the main chat stops the work on it and takes it to `product` as a product decision. It is no longer `code_lead`'s technical problem.

1. **How much does it matter?** `product` first weighs the thing against the whole game, with `game_creator` for gameplay and business. What helps the game go viral (`viral-goal.md`) gets the most time:
   - the core loop and the gameplay: does the player play with it, or is it there for looks?
   - the final product: would a player notice or care if it changed?
   - the project goals: retention, the new-player experience, the release date and the cost so far.
   Something that is only for looks never gets more tries than something players play with.
2. **Pick one path**, with its reasons:
   - **Lower the bar:** change the rule or the limit so it asks only what the player needs.
   - **Change the design:** `designer` reshapes, moves or simplifies the thing so the problem goes away.
   - **Accept it for now:** a safety net covers the player; it is written into a named later spec.
   - **Cut it:** take it out of this version.
3. **Ask whether it can be done differently, before any more tries.** `product` explains the cost to the owner who could change it, and asks: "This is costly because of x, y and z. Can it be done differently so these problems can't happen? If you can, what does that cost?"
   - the look or shape of a thing: `designer`;
   - the gameplay or the business: `game_creator`;
   - the technical approach, the tests or the tools: `code_lead`.
   If the owner can, `product` weighs that cost against the fix still planned and picks the cheaper safe one. If nobody can, `product` takes it to `game_creator` to advise: keep it as it is, simplify it or cut it. The "What matters most" tier sets how much more time it may get: scenery gets the least, core gameplay the most.
4. If the path changes approved work, the "Asking the user" checks apply as usual.

## Red alert: a plan is eating too much time

"Stuck on one problem" catches one task. This catches a whole plan (one feature) that keeps growing a little at a time, until weeks go into something players may barely notice (Adam, 2026-11-02).

**When it starts.** The main chat checks these at every task close:
- the plan's time so far passes **1.5 times** its planned time;
- the plan has grown by **half** its first task count (tasks added or split during building);
- **every 10 tasks** committed on one plan, even when nothing looks wrong, because slow growth looks normal from inside;
- any owner, or the health check, says the plan is costing more than it gives.

**What happens.**
1. **Pause the plan.** No new task in that plan starts. A step under way finishes at a safe point (never in the middle of a world change).
2. **The same brief to everyone.** The main chat sends `game_creator`, `designer`, `product` and `code_lead` one short brief: the plan's goal (what the player gets), planned against real time and tasks, the tasks done and still to come, and what each one protects.
3. **Each advises from its own area,** in one reply:
   - Which of the work done or still to come does a player really need? What would a player never notice?
   - What can be cut, made simpler, left to the safety net, or moved to a later plan that changes that part anyway ("Don't polish what a later spec replaces")?
   - Is there a cheaper way to finish the rest?
   - Why did it grow, and what would have caught it sooner?
4. **One decision.** `product` weighs the answers with `game_creator` and decides: keep going as planned, trim, change the approach, or stop the plan here. It says what is cut, the time saved and the viral-test answer. Cutting a whole feature goes to Adam ("Asking the user").
5. **Rewrite, then carry on.** `code_lead` rewrites the plan's remaining tasks to match, and the work starts again from there. The main chat tells Adam in one line what changed and the time saved. The answer to "why did it grow" goes into the lessons.

## Learning from experience

The team writes down what went wrong, so it is caught early next time and never happens a third time.

- **Lessons (`docs/lessons/`).** One index file, `docs/lessons/index.md`, lists every lesson by number, short name and topic file. Every agent reads the index before planning, writing a rule, placing an object or starting a task, opens only the topic files that match, and follows them. A task or ruling that follows a lesson names it, for example "Lesson 2 (Change the scenery, not the giant)". An agent that spots a new lesson ends its report with one line: `LESSON: <what happened> → <do instead>`. The main chat writes it into the topic file that fits and adds its line to the index.
- **Problems log (`docs/problems-log/`).** One index file, `docs/problems-log/index.md`, lists the open and fixed kinds of problem and the area files (one per area, feature or gameplay part, never by date). The main chat adds one line to the matching area file for every unplanned stop as soon as it happens: a crash, a stale Studio, an idle turn, an agent over its memory limit, a failed script, a task over its size, a second task on the same object. Before logging, it checks the index's open kinds. **The same kind twice means fix the cause:** the main chat stops, finds why, fixes it (a rule, a script or a hook), and adds a lesson. A workaround alone is never the fix the second time.
- **Health check (`python3 scripts/health.py`).** The main chat runs it at every task close and at the start of every session. It reads the session records and prints the hours worked and idle, each agent's size, Rojo crashes and commits, then the alarms. It checks these by hand too:

  | Alarm | What it means |
  |---|---|
  | Nothing running for more than 30 minutes, and nobody knew | an idle turn: log it, and start the next step now |
  | Two tasks in a row closed with nothing built | the team is stuck: "Stuck on one problem" above |
  | A task went past 1 hour, or past its planned size | a **red flag** (`CLAUDE.md`, "Red flag: a task taking too long"). Stop the task: nothing more on it starts. In the same turn, without waiting for Adam, send the same brief to `game_creator`, `designer`, `product` and `code_lead`: why it grew, what would have caught it sooner, the best way to finish it, and what to change in how we work. Each one thinks, searches the web, and uses its skills and the Roblox docs before answering. `product` decides with `game_creator`; the changes go into the plan, rules and lessons. Only then does the task start again (Adam, 2026-11-02) |
  | A second task on the same object | a product decision: "Stuck on one problem" above |
  | A plan past 1.5 times its time, grown by half its tasks, or 10 more tasks committed on it | "Red alert: a plan is eating too much time" above |
  | Any Rojo crash, agent over its limit or other unplanned stop | a problems-log line; twice means fix the cause |

  An alarm means stop and step back before the next step, and take it to the owner (usually `product`). Never carry on as if nothing happened.
- **Look back at each task close.** Before the commit, the main chat asks in one line: what slowed this task down, and could a lesson have stopped it? Anything found goes into the log or the lessons.
- **Time in every update.** Each update to Adam about a task says the time so far against the plan, for example "Task 7: 6 h so far, planned 2 h". A big gap is an alarm.

## Main chat is the messenger

Agents never talk to each other directly. The main chat carries every message between them. There is **no chain of command**: any agent can ask any other agent a question, and the main chat takes it straight to the owner in the table below, never "up" through someone else.

- Start an agent with the Agent tool, and keep its agent ID.
- Send follow-ups with SendMessage to that ID, so the agent keeps its context.
- Forward questions and answers in full. Don't summarize them in a way that changes their meaning.
- Show Adam each relay in one line: `designer → game_creator: <what it asked>`.
- If an agent can't be resumed (for example, in a new session), start a new one and give it the file paths below. The files are the shared memory.

## Agent memory size

Every agent report ends with a token count (`subagent_tokens`): how much text the agent carries. A big memory makes an agent slower and costlier. Near the limit, older parts get squeezed into a summary, and details can be lost.

The main chat checks the count after every report:

| Agent | Rule |
|---|---|
| `builder` | A fresh agent for every task, and never over 150k tokens. An agent can't see its own token count, so the main chat enforces it with checkpoints: each handoff splits the task into steps, and the builder stops and reports after each step (after a green test run, never in the middle of a world change), with a short note of where it stands in the `work/` folder. The main chat reads the count from the report: under 150k it resumes the same builder for the next step; above that a fresh builder carries on from the note and the handoff |
| `runner` | A fresh agent for every job, and never over 100k tokens. Its jobs are short, so it is never resumed for a second job |
| Every other agent | Keep resuming it while under 200k tokens. Above that, start a fresh one at the next natural break: after a review or an answer, never in the middle of a task. Every step rereads the whole memory, so a big memory makes even a short check costly |

A fresh agent gets the file paths it needs (idea, design, spec, plan, progress) and a short note of where the work stands. The files are the shared memory.

`code_lead` sizes tasks so a builder can finish one well under 150k tokens. A task that keeps stopping or needs a new approach is split into smaller tasks.

**Size tasks in hours too.** Every task in a plan gives its planned hours next to its Studio calls, and no task is planned over 1 hour unless it says why. The main chat stops a task at 1 hour or its planned time, whichever comes first (`CLAUDE.md`, "Red flag"). Plans that counted only Studio calls let long tasks run 4 to 11 hours unseen (review of V2, 2026-11-02).

**Size steps by tool calls.** A fresh agent starts at about 50k tokens (rules, tools and its definition) before it does anything, and every tool call adds about 2.4k (measured 2026-10-27). So every builder step has a cap of **at most 30 tool calls** (Studio, shell and file reads together), written in the handoff next to its Studio-call cap. A step that needs more is split. The builder stops and reports at the cap, even mid-step, as long as it isn't in the middle of a world change. Calls aren't all the same size, so a hook (`.claude/hooks/agent-memory-cap.py`) also reads each agent's real memory before every tool call: at 85% of its limit it tells the agent to wrap up, and any project agent at its limit can only write its state note or answer in `work/` (Lesson 25). The same hook counts each agent's tool calls since its last prompt or resume, because agents miscount their own: from call 25 it shows the count, past 30 only a Studio call to finish a world change or fetch a job (up to 5) or a note still works (Lesson 73). The 30-tool-call cap applies to every agent's job, not only the builder's: the main chat writes the cap into every prompt, and a job that needs more is split. Every script an agent writes goes in once: paste it straight into Studio, never into a file first and then again into Studio. **Reading counts too:** a step's prompt names at most 5 files to read, and the handoff step quotes the lesson lines it needs, so the builder doesn't open the lessons index or rules for it. A Play step's cap counts its reads, the device set and reset, and a console read (Lesson 89).

**Working files live in `work/`.** Handoffs, state notes, reports and trial scripts go in the project's `work/` folder, which git ignores (`.git/info/exclude`). Never in the system scratchpad: it is under `/tmp`, which the Mac empties when it restarts.

The main chat's own memory grows too, and it follows two rules:
- **Relay by file, not by pasting.** When an agent's report has to go to another agent, the main chat saves it once in the `work/` folder and sends the path with a short summary. It never pastes a long report into a message. Reports to Adam stay short.
- **Let the app compact it.** The chat can't compact itself, and Adam isn't asked to. The app compacts the chat automatically at about 200k tokens (`autoCompactWindow` in `.claude/settings.local.json`), which can happen at any moment. So the main chat updates the "Now" section of `docs/handoff.md` after every agent step, not only after every approved task, and a compacted chat picks up from that file with nothing lost.

## Model per job

A cheaper model costs less for every word it reads, so each job uses the cheapest model that can do it well (decided 2026-10-29).

| Kind of job | Model |
|---|---|
| **Thinking:** ideas, looks, specs, plans, reviews, rulings, finding why something failed | Opus (the default of `game_creator`, `designer`, `product`, `product_reviewer` and `code_lead`) |
| **Building:** writing tests, code and Play jobs; running Play and judging it against a pass list | Sonnet (the default of `builder`) |
| **Running only:** a full test run and its fetch, fetching a job that's already running, a read-only names check, copying files, filling a table from given numbers, running `scripts/job-check.sh` | Haiku (the `runner` agent) |

- **Each handoff step names its model** in its heading, for example "## Step 3: The full run (2 Studio calls, Haiku)". `code_lead` picks it from the table. `scripts/job-check.sh --handoff` fails a step heading with no model.
- **The main chat starts each step with that model** (the Agent tool's `model`). A resumed agent keeps its model, so a step on a different model gets a fresh agent, given the handoff and the last state note.
- **`code_lead` hands on its simple jobs.** It keeps the thinking: plans, handoffs, reviews, rulings, finding why something failed, and reading every job before its first paste (Lesson 76). It hands on the rest:

  | `code_lead` job | Goes to |
  |---|---|
  | A small Play pre-check with a pass list it wrote | `builder` (Sonnet) |
  | The names check of a handoff's world table (one read-only Studio call it wrote), a full test run, progress-table rows from given results, `scripts/job-check.sh` on a job or handoff | `runner` (Haiku) |

  It writes such a job as a short prompt in `work/` (files to read, scripts to paste, pass rule, caps), and the main chat starts that agent.
- **Ready-made run scripts.** A full test run is always `scripts/studio/full-run-start.luau`, a wait of about 60 s (`python3 -c "import time; time.sleep(62)"`, because a hook blocks Bash `sleep`), then `scripts/studio/full-run-fetch.luau` (fetched again until it reports, never started twice: Lesson 51). The report comes in pages: the runner fetches again while a page ends with "fetch again", until a page ends with "end of report", and copies every page (Lesson 182). A builder's red run uses the narrowest filter (the step's own spec names), so the report fits on one page and keeps each failure message whole, and a step's Studio cap counts one fetch per report page it expects (Lesson 188).
- **Jobs outside a handoff** (a question, a check, a progress update) get their model from the same table, written by the main chat when it starts the job.
- **Every full test run goes to the `runner` (Haiku), never inside a Sonnet or Opus step** (Adam, 2026-11-01). A full run only pastes two ready-made scripts and copies the pass line, so a cheaper model gives the same result, and quality is kept because the thinking stays with the stronger models:
  - the `builder` writes the code and sees its red; the `runner` only runs and reports the exact pass or fail lines;
  - `code_lead` judges the result in its review, never the `runner`;
  - a red step still budgets its own run (start and one fetch), because tests run only in Studio.
  `scripts/job-check.sh --handoff` fails a step heading that puts a full run on Sonnet or Opus, and a red step with 0 Studio calls (Lesson 132).
- **If a cheaper model fails a step** (wrong calls, a misread result), the step goes back up one model, and that kind of job moves up in this table. It's logged in the problems log like any other unplanned stop.

## Fewer round trips

Most of an agent's cost is rereading its memory before every step, so every extra step, stop and question costs a full reread. The work stays the same; the trips get fewer.

- **World names checked before the builder starts.** Every world name, position and part kind a handoff relies on (seeds, sources, parts to measure) is listed in one table in the handoff. Before the builder starts, `code_lead` checks that table against the running world in one read-only Studio call (or the build scripts and progress rows, for parts not built yet), and marks each row "exists" or "built by <plan and task>". A row that doesn't exist goes to its owner before the builder starts (Lesson 61).
- **Placement spots are measured, never guessed.** Any brief, list or ruling that says where to put something gives measured spots (from a read-only Studio call), or says "measure first". "About 6 studs back" or "about y 104" is a guess, not a spot (Lessons 219 and 221).
- **Smoke run before every Play job.** Before a Play job runs, a builder runs its first case once, on one side, with the job's own scripts in order (about 6-8 tool calls). The job starts only if it passes: the player moves as the job expects, no game rule interferes, and no loop is left running. The smoke run also takes one screenshot from the player's camera, and the builder checks it plays like a player ("Everyone uses the game"). A job written from facts nobody ran in the game is a guess (Lesson 225).
- **Decision table first.** When a task has many cases of the same kind (spots to fix, items to place, values to tune), `code_lead` writes a short decision table in the handoff: which kind of case gets which fix, plus the stop rules. Each row names its cause as measured on real examples, never guessed (Lesson 26): a fix that moves, cuts or blocks a part names that part from the check. The owners it needs check the table once, before the builder starts. The builder applies it without asking about each case.
- **Batch the questions.** The builder stops only for cases the table doesn't cover, and collects all of them into one `QUESTIONS:` list at the end of the step, not one stop per case. The main chat takes each owner all their questions in one message.
- **One script per job.** Agents do a whole job (fit, scan, summary) in one Studio call or one script file that prints a short summary, not in many small calls.
- **Nothing big comes into memory.** Anything read once stays in an agent's memory and is reread on every later call. So: never read a whole file over 1000 lines (search it and read only the lines needed); never pull more than about 100 lines of console or script output (long output goes to a file in `work/`, and the agent reads its summary); never reread a file already read.
- **No big files.** No file in `src/`, `tools/`, `scripts/`, `docs/` or `.claude/` goes over 1000 lines (this includes the lessons and problems-log files; each folder has one index file, and a file near the limit is split into a new file listed in that index), so every file can be read whole within the rule above. A file near the limit is split by topic before more is added (for example, one test file per area instead of one huge one). Plans and specs follow the same limit (`CLAUDE.md`, "Docs layout"). The health check warns about any file over 900 lines.
- **Short reports.** A report to the main chat is at most about 20 lines: result, numbers, questions. Details go in the task's state note in `work/`, and the report gives its path. Every report line also lands in the main chat's memory.

After every approved task, it updates the "Now" section of `docs/handoff.md` (untracked): the task in progress, open questions between agents, each agent's size, and what Adam checks at the next gate. A new session starts from that file and `docs/progress/index.md`.

## Who owns what

| Topic | Owner |
|---|---|
| Game idea, gameplay, players, business and monetization | `game_creator` |
| Look and feel, style guide, mockup images | `designer` |
| Specs | `product` |
| Reviewing what was built, as a player and against its spec | `product_reviewer` |
| Code architecture, plans, task breakdown, code review, progress table | `code_lead` |
| Writing the code and its tests | `builder` |
| Running jobs others wrote and decided: test runs, fetches, names checks, progress rows | `runner` |
| Testing finished features and fixes (later) | `qa` |
| Tools, setup, agent configuration | main chat |

## The flow

1. **Idea.** `game_creator` proposes ideas. Adam picks one, and `game_creator` saves it to `docs/ideas/<name>.md`.
   **Gate 1: Adam approves the saved idea.**
2. **Design starts.** After Gate 1, when Adam says so, the main chat starts `designer` and gives it the idea file path.
3. **Questions instead of guesses.** When `designer` is unsure about the game, it asks. The main chat passes the question to `game_creator` and brings back the answer. `game_creator` owns gameplay and business decisions, so it decides them itself, with its reasons, even when the idea file doesn't cover them. Nobody guesses, and nobody passes a decision up that they own.
4. **game_creator review.** When `designer` finishes, the main chat sends `game_creator` the file paths. It checks, in this order (its Job 4):
   - **Can it win players?** Side by side with real screenshots of the top games: would a kid pick ours?
   - **Does it sell the twist** at a glance, in the icon and thumbnail?
   - **Business:** does the look support monetization and retention?
   - **Screen and phone:** layout and readability.
   - **Can it be built** from real store or generated models? "Simple to build" is never a reason to accept a plain look.

   It replies with either **approve** or **changes**, plus a numbered list. Changes go back to `designer`. After 3 rounds without approval, stop and ask Adam.
5. **Gate 2: Adam approves the images.** After `game_creator` approves, the main chat shows Adam the images and the review. Any changes Adam asks for go through steps 3–4 again.
6. **Specs.** After Gate 2, when Adam says so, the main chat starts `product`.
   - It splits the version into small specs, in a version folder with an `index.md` map (`CLAUDE.md`, "Docs layout"), with the core loop first.
   - It writes one spec at a time.
   - Its questions go to `game_creator` (gameplay, business) or `designer` (look), the same way as in step 3.
7. **Spec review.** `game_creator` checks idea and business fit, and `designer` checks the spec matches the mockups and the build limits.
   - Each replies with **approve** or **changes**, plus a numbered list.
   - Changes go back to `product`.
   - After 3 rounds without approval from both, stop and ask Adam.
8. **Gate 3: Adam approves the spec.** The main chat shows Adam the spec and both reviews.
9. **Plan.** After Gate 3, when Adam says so, the main chat starts `code_lead`. It keeps `docs/architecture.md` current and writes `docs/plans/<version>/index.md` and one `docs/plans/<version>/<feature>.md` per spec: small tasks in test-first order, each naming the spec rules it covers. Its questions go to the owners like everyone else's.
10. **Code.** Only after Adam says "let's start coding X" (sdd.md). The main chat makes the feature's branch (git.md). `code_lead` hands one task at a time to `builder`. `builder` writes it test-first in `src/` and proves it works. `code_lead` reviews every task: **approve** or **changes** (max 3 rounds, then Adam). The main chat commits each approved task on the branch. `code_lead` keeps `docs/progress.md` up to date.
11. **Test.** When a whole feature or a fix is approved, `code_lead` hands it to `qa`, which tests it. Bugs go back to `builder`.
12. **Build review.** `product_reviewer` (not the agent that wrote the spec, so the review is a fresh look) first plays the feature like a regular player: whole sessions, with the player's own controls only, on computer and phone. Anything that hurts the player is a fail, even if no rule names it. Then it checks the feature against its spec, the idea and the business goals, then writes `docs/reviews/<feature>.md` with an **accept** or **changes** verdict. `game_creator` also plays it and judges the first impression next to the top games, the fun and the business fit (its Job 6), and `designer` checks the look (its Job 4). Changes go back to `builder`.
13. **Gate 4: Adam approves the built feature.** The main chat shows Adam the review, merges the feature's branch into `main`, and tells Adam it's ready to push (git.md).

## No open questions at a gate

Nothing reaches Adam with open questions: not an idea, a design, a spec or a review. Every question is answered by its owner from the "Who owns what" table before the gate. A question that "can wait until after the playtest" still gets a decision now: a starting choice, plus the playtest result that would change it.

## Asking the user

Owners decide everything in their area, including changes to things Adam already approved at a gate (the idea, the mockups, a spec, a built feature), as long as the change fits the game idea. The owner makes the change, and the main chat tells Adam in one line afterwards: what changed and why.

Before changing approved work, the owner re-checks the change against all of these, and says in its reply that it did:
- **Game idea:** the core loop, the twist and who the game is for (`docs/ideas/<name>.md`).
- **Look and feel:** the style guide and the approved mockups.
- **Business goals:** monetization, retention and the new-player experience.
- **Standards:** the project rules, phone-first design, and what a beginner can build in Studio.

If the change touches another owner's area, that owner checks it too (through the main chat) before it is made. If any check fails, the change doesn't go in as it is: the owner reworks it, or it goes to Adam as a bigger change.

Adam is asked first only for a bigger change:
- a new feature, or removing a feature;
- anything about money: prices, Robux, game passes, what is sold;
- a change that doesn't fit the game idea.

When Adam is asked, it's right away, one question at a time, with a recommendation. A question for Adam is never parked as an "open question" in a file.

## Adam's questions

Adam talks only to the main chat. When he asks why an agent decided something, or asks about its work:

- Send the question to the owner from the table, or to both owners if it touches both.
- Reply with the agent's answer, and say which agent it came from.
- Never answer from a guess about an agent's reasons. Only questions about tools, setup and agent configuration are answered by the main chat directly.

## Shared files

| Path | Written by | In git |
|---|---|---|
| `docs/ideas/<name>.md` | `game_creator` | yes |
| `docs/design/<version>/` (look study, style guide, mockups) | `designer` | yes |
| `references/top-games/` (the shared reference library, see above) | any agent that needs it | **no**, because those images belong to other games |
| `docs/specs/index.md`, `docs/specs/<version>/index.md`, `docs/specs/<version>/<feature>.md` | `product` | yes |
| `docs/specs/<version>/research/` (owner input saved for fresh agents) | main chat | yes |
| `docs/reviews/<feature>.md` | `product_reviewer` | yes |
| `docs/layers.md` (the layer map: the world's layers and which sits on which) | `product`, checked by `game_creator` | yes |
| `docs/architecture.md`, `docs/plans/<version>/index.md`, `docs/plans/<version>/<feature>.md`, `docs/progress/index.md`, `docs/progress/<version>.md` or `docs/progress/<version>/<feature>.md` | `code_lead` | yes |
| `src/` (code and tests) | `builder` | yes |
| `docs/lessons/` (index plus topic files), `docs/problems-log/` (index plus area files) | main chat | yes |
