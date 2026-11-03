# Agent workflow

How the project agents work together. The rare processes are skills, loaded when used:

| Skill | Use it for |
|---|---|
| `the-flow` | the steps from idea to shipped feature, and the user's four gates |
| `stop-and-step-back` | anything over its time limit, a loop, a second task on one object, a plan over budget, a look made worse |
| `writing-handoffs` | sizing and writing a task handoff or Play job |
| `look-check` | before and after shots for any change the player can see |
| `closing-a-task` | the health check, lessons, commit and handoff update at each task close, and Gate 4 |
| `top-games-library` | real screenshots of the top games, and refreshing them |
| `order-the-work` | ordering work by what it stands on |

## Think critically and creatively

Every agent, in every job:
- **Start from the player's problem**, not the current design or a plan already written. An existing design is one idea to test, never the default.
- **Look for a different kind of answer**, not only a better version of the same thing. For example: instead of placing ladders on a wall, give every player a ladder to place themselves.
- **Keep what's built, add the smallest piece.** Before moving, rebuilding or replacing built work, ask: what is the smallest new piece that connects what players already reach to what is already built? Measure the gap and price that answer first.
- **Challenge every answer**, your own and other agents'. Ask what it breaks for the player. Agreement between agents is not a check: if everyone picked the same answer, ask what nobody tried.
- **Owners check their own area every time.** `game_creator` and `product` judge every idea for the players, including fairness: does a player on one side or in one spot get a head start?
- **Compare real costs.** "It's a new feature" is not a reason to drop an idea. Weigh it against the total cost of the fixes it replaces.
- **Briefs don't steer.** A brief gives the player's problem, the facts, the cost so far and what it blocks, and the questions. It never hints at an answer.
- **See the options before choosing** between looks or ways to play (`look-check` skill).
- **No "later".** Each option is in or out now (`docs.md`).
## Order work by what it stands on

Work done in the wrong order gets done twice. The method is the `order-the-work` skill; this game's layer map is `docs/layers.md`.
- Every task and step has a "Stands on:" line: each thing that must be final first. "Final" means decided and built.
- A task starts only when everything it stands on is final. Never "do it now and redo it if it changes".
- An order already written is an idea to test, not a fact.
- `product` writes the list for what it specifies; `product_reviewer` for each fix in a changes verdict; `code_lead` copies it into tasks and orders by it. Before starting a task, the main chat reads its line; anything still open goes back to `product`.
- `scripts/job-check.sh --plan <file>` (or `--handoff`) fails a missing, open or out-of-order "Stands on".

## Everyone uses the game

Nobody approves what they haven't seen in the running game. Reading code and passing tests is not enough.
- Whoever builds, reviews or checks anything the player sees or does plays it in Studio first: start Play, walk the character through it, and take `screen_capture` shots of the real play screen.
- Check computer and phone (Studio's device simulator), and every state it touches: each area, each enemy phase, carrying an item, being caught.
- Shots are evidence: a report names what they show and compares them with the spec and the mockups.
- If a tool can't do something, test it in Play before believing it, and tell the main chat. Never quietly push a check to "later".

## The user only approves

The user's only jobs are the gates and the decisions in "Asking the user". Never give them manual work (resizing windows, clicking in Studio, setup). Solve it, or accept the limit and say so in one line.
- **Stop when Studio isn't connected.** If `list_roblox_studios` comes back empty, stop and report before anything that depends on it. Never pick a workaround alone.
- **When one agent works, the whole team works.** The main chat starts or resumes any agent a step needs, without asking.
- **A new flow step needs the user's go-ahead** (`the-flow` skill). A task is not a flow step.
- **Inside coding, the main chat never waits between tasks.** Once the user says "let's start coding X", it runs X to its next gate: after each commit it goes straight to the next task. It stops only at a gate, for "Asking the user", or when only the user can act (for example, Rojo Connect), and tells them what finished in one line.
- **Never end a turn on a promise.** When a report arrives, start the next step in the same turn. Before saying "X is running", `ListAgents` must show it. `.claude/hooks/no-idle-stop.py` enforces this.

## Main chat is the messenger

Agents never talk to each other directly. There is no chain of command: any agent can ask any other, and the main chat takes it straight to the owner.
- Start an agent with the Agent tool, keep its ID, and follow up with SendMessage so it keeps its context.
- Forward questions and answers in full, without changing their meaning. Show the user each relay in one line: `designer → game_creator: <what it asked>`.
- Relay long reports by file: save once in `work/` and send the path with a short summary.
- If an agent can't be resumed, start a fresh one with the file paths. The files are the shared memory.

## Asking the user

Owners decide everything in their area, including changes to approved work that fit the game idea. The owner re-checks the change against the idea, the style guide and mockups, the business goals and the project rules, says so, and the main chat tells the user in one line afterwards. If the change touches another owner's area, that owner checks it too.

The user is asked first only for:
- a new feature, or removing one;
- anything about money: prices, Robux, game passes, what is sold;
- a change that doesn't fit the game idea.

Then ask right away, one question at a time, with a recommendation. Never park a question for the user in a file.

When the user asks why an agent decided something, send the question to that owner and reply with its answer, naming the agent. Only questions about tools, setup and agent configuration are answered by the main chat.

## Files

- **No big files.** No file in `src/`, `tools/`, `scripts/`, `docs/` or `.claude/` goes over 1000 lines. Split a file near the limit by topic, listed in its folder's index. The health check warns at 900.
- **Working files live in `work/`** (git-ignored): handoffs, state notes, reports, trial scripts. Never in `/tmp`, which the Mac empties.

| Path | Written by | In git |
|---|---|---|
| `docs/ideas/<name>.md` | `game_creator` | yes |
| `docs/design/<version>/` | `designer` | yes |
| `docs/specs/...`, `docs/layers.md` | `product` | yes |
| `docs/specs/<version>/research/` | main chat | yes |
| `docs/reviews/<feature>.md` | `product_reviewer` | yes |
| `docs/architecture.md`, `docs/plans/...`, `docs/progress/...` | `code_lead` | yes |
| `src/` (code and tests) | `builder` | yes |
| `docs/lessons/`, `docs/problems-log/` | main chat | yes |
| `references/top-games/` | any agent | no (other games' pictures) |
