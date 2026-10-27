# Agent workflow

How the project agents work together. Today: `game_creator`, `designer`, `product`, `code_lead` and `builder` (`qa` comes later). New agents get a row in each table below.

## The goal comes first

The game's goal is to go viral. Every look, feel and gameplay decision, review and approval passes the viral test in `viral-goal.md`.

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

## Learning from experience

The team writes down what went wrong, so it is caught early next time and never happens a third time.

- **Lessons (`docs/lessons/`).** One index file, `docs/lessons/index.md`, lists every lesson by number, short name and topic file. Every agent reads the index before planning, writing a rule, placing an object or starting a task, opens only the topic files that match, and follows them. A task or ruling that follows a lesson names it, for example "Lesson 2 (Change the scenery, not the giant)". An agent that spots a new lesson ends its report with one line: `LESSON: <what happened> → <do instead>`. The main chat writes it into the topic file that fits and adds its line to the index.
- **Problems log (`docs/problems-log/`).** One index file, `docs/problems-log/index.md`, lists the open and fixed kinds of problem and the area files (one per area, feature or gameplay part, never by date). The main chat adds one line to the matching area file for every unplanned stop as soon as it happens: a crash, a stale Studio, an idle turn, an agent over its memory limit, a failed script, a task over its size, a second task on the same object. Before logging, it checks the index's open kinds. **The same kind twice means fix the cause:** the main chat stops, finds why, fixes it (a rule, a script or a hook), and adds a lesson. A workaround alone is never the fix the second time.
- **Health check (`python3 scripts/health.py`).** The main chat runs it at every task close and at the start of every session. It reads the session records and prints the hours worked and idle, each agent's size, Rojo crashes and commits, then the alarms. It checks these by hand too:

  | Alarm | What it means |
  |---|---|
  | Nothing running for more than 30 minutes, and nobody knew | an idle turn: log it, and start the next step now |
  | Two tasks in a row closed with nothing built | the team is stuck: "Stuck on one problem" above |
  | A task went past its planned size | stop and ask `code_lead` to split it or `product` whether it's worth it |
  | A second task on the same object | a product decision: "Stuck on one problem" above |
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
| Every other agent | Keep resuming it while under 200k tokens. Above that, start a fresh one at the next natural break: after a review or an answer, never in the middle of a task. Every step rereads the whole memory, so a big memory makes even a short check costly |

A fresh agent gets the file paths it needs (idea, design, spec, plan, progress) and a short note of where the work stands. The files are the shared memory.

`code_lead` sizes tasks so a builder can finish one well under 150k tokens. A task that keeps stopping or needs a new approach is split into smaller tasks.

**Size steps by tool calls.** A fresh agent starts at about 50k tokens (rules, tools and its definition) before it does anything, and every tool call adds about 2.4k (measured 2026-10-27). So every builder step has a cap of **at most 30 tool calls** (Studio, shell and file reads together), written in the handoff next to its Studio-call cap. A step that needs more is split. The builder stops and reports at the cap, even mid-step, as long as it isn't in the middle of a world change. Calls aren't all the same size, so a hook (`.claude/hooks/agent-memory-cap.py`) also reads each agent's real memory before every tool call: at 85% of its limit it tells the agent to wrap up, and a builder at its limit can only write its state note in `work/` (Lesson 25). Every script an agent writes goes in once: paste it straight into Studio, never into a file first and then again into Studio.

**Working files live in `work/`.** Handoffs, state notes, reports and trial scripts go in the project's `work/` folder, which git ignores (`.git/info/exclude`). Never in the system scratchpad: it is under `/tmp`, which the Mac empties when it restarts.

The main chat's own memory grows too, and it follows two rules:
- **Relay by file, not by pasting.** When an agent's report has to go to another agent, the main chat saves it once in the `work/` folder and sends the path with a short summary. It never pastes a long report into a message. Reports to Adam stay short.
- **Let the app compact it.** The chat can't compact itself, and Adam isn't asked to. The app compacts the chat automatically at about 200k tokens (`autoCompactWindow` in `.claude/settings.local.json`), which can happen at any moment. So the main chat updates the "Now" section of `docs/handoff.md` after every agent step, not only after every approved task, and a compacted chat picks up from that file with nothing lost.

## Fewer round trips

Most of an agent's cost is rereading its memory before every step, so every extra step, stop and question costs a full reread. The work stays the same; the trips get fewer.

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
| Specs, and reviewing what was built against them | `product` |
| Code architecture, plans, task breakdown, code review, progress table | `code_lead` |
| Writing the code and its tests | `builder` |
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
12. **Build review.** `product` first plays the feature like a regular player: whole sessions, with the player's own controls only, on computer and phone. Anything that hurts the player is a fail, even if no rule names it. Then it checks the feature against its spec, the idea and the business goals, then writes `docs/reviews/<feature>.md` with an **accept** or **changes** verdict. `game_creator` also plays it and judges the first impression next to the top games, the fun and the business fit (its Job 6), and `designer` checks the look (its Job 4). Changes go back to `builder`.
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
| `docs/reviews/<feature>.md` | `product` | yes |
| `docs/architecture.md`, `docs/plans/<version>/index.md`, `docs/plans/<version>/<feature>.md`, `docs/progress/index.md`, `docs/progress/<version>.md` or `docs/progress/<version>/<feature>.md` | `code_lead` | yes |
| `src/` (code and tests) | `builder` | yes |
| `docs/lessons/` (index plus topic files), `docs/problems-log/` (index plus area files) | main chat | yes |
