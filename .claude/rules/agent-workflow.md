# Agent workflow

How the project agents work together. Today: `game_creator`, `designer`, `product`, `code_lead` and `builder` (`qa` comes later). New agents get a row in each table below.

## Everyone uses the game

Nobody approves what they haven't seen in the running game. Reading code and passing tests is not enough.

- Whoever builds, reviews or checks anything the player sees or does plays it in Studio first:
  - start Play (mute the sound if a session rule says so);
  - walk the character through it with the Studio tools;
  - take `screen_capture` screenshots of the real play screen.
- Each check looks at:
  - **Computer and phone:** the computer screen, and a phone screen through Studio's device simulator;
  - **Every state it touches:** for example the base, a bridge, each ring, the giant asleep, stirring and awake, carrying an egg, and being caught.
- Screenshots are evidence: a report names what they show, and compares them with the spec and the approved mockups.
- Problems are judged on the whole screen, not only the part the task changed: something covering the giant, text cut off at an edge, or controls overlapping are problems even if no rule names them.
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

Adam's only jobs are the gates and the rare decisions that are his to make (see "Asking Adam" below). Never give him manual work, such as resizing windows, clicking in Studio, or setting things up. Agents and the main chat solve it themselves, or accept the limit and say so in one line.

**Stop when Studio isn't connected.** If a step needs Studio and `list_roblox_studios` comes back empty, the agent stops and reports it before doing anything that depends on it. It never picks a workaround on its own.

**When one agent works, the whole team works.** While a step is under way (any agent is working on it), the main chat starts or resumes any other agent that step needs, such as an owner to answer a question or check a change, without asking Adam. Relaying messages never needs permission.

**Starting a new step needs Adam's go-ahead.** When nothing is under way, for example at a gate or after a step is finished, the main chat doesn't start the next step on its own, even when the flow says it comes next. It says which step is next and waits for Adam. Once Adam says "let's start coding X", the main chat may start and resume `builder` and `qa` for X whenever `code_lead` hands work to them.

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
| `builder` | A fresh agent for every task |
| Every other agent | Keep resuming it while under 200k tokens. Above that, start a fresh one at the next natural break: after a review or an answer, never in the middle of a task. Every step rereads the whole memory, so a big memory makes even a short check costly |

A fresh agent gets the file paths it needs (idea, design, spec, plan, progress) and a short note of where the work stands. The files are the shared memory.

The main chat's own memory grows too. After every approved task, it updates the "Now" section of `docs/handoff.md` (untracked): the task in progress, open questions between agents, each agent's size, and what Adam checks at the next gate. A new session starts from that file and `docs/progress.md`.

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
   - It splits V1 into small specs, listed in `docs/specs/index.md`, with the core heist first.
   - It writes one spec at a time.
   - Its questions go to `game_creator` (gameplay, business) or `designer` (look), the same way as in step 3.
7. **Spec review.** `game_creator` checks idea and business fit, and `designer` checks the spec matches the mockups and the build limits.
   - Each replies with **approve** or **changes**, plus a numbered list.
   - Changes go back to `product`.
   - After 3 rounds without approval from both, stop and ask Adam.
8. **Gate 3: Adam approves the spec.** The main chat shows Adam the spec and both reviews.
9. **Plan.** After Gate 3, when Adam says so, the main chat starts `code_lead`. It keeps `docs/architecture.md` current and writes `docs/plans/<feature>.md`: small tasks in test-first order, each naming the spec rules it covers. Its questions go to the owners like everyone else's.
10. **Code.** Only after Adam says "let's start coding X" (sdd.md). `code_lead` hands one task at a time to `builder`. `builder` writes it test-first in `src/` and proves it works. `code_lead` reviews every task: **approve** or **changes** (max 3 rounds, then Adam). `code_lead` keeps `docs/progress.md` up to date.
11. **Test.** When a whole feature or a fix is approved, `code_lead` hands it to `qa`, which tests it. Bugs go back to `builder`.
12. **Build review.** `product` first plays the feature like a regular player: whole sessions, with the player's own controls only, on computer and phone. Anything that hurts the player is a fail, even if no rule names it. Then it checks the feature against its spec, the idea and the business goals, then writes `docs/reviews/<feature>.md` with an **accept** or **changes** verdict. `game_creator` also plays it and judges the first impression next to the top games, the fun and the business fit (its Job 6), and `designer` checks the look (its Job 4). Changes go back to `builder`.
13. **Gate 4: Adam approves the built feature.** The main chat shows Adam the review, then gives him the commit commands for the feature (git.md).

## No open questions at a gate

Nothing reaches Adam with open questions: not an idea, a design, a spec or a review. Every question is answered by its owner from the "Who owns what" table before the gate. A question that "can wait until after the playtest" still gets a decision now: a starting choice, plus the playtest result that would change it.

## Asking Adam

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
| `docs/design/<name>/` (look study, style guide, mockups) | `designer` | yes |
| `references/top-games/` (the shared reference library, see above) | any agent that needs it | **no**, because those images belong to other games |
| `docs/specs/index.md`, `docs/specs/<feature>.md` | `product` | yes |
| `docs/reviews/<feature>.md` | `product` | yes |
| `docs/architecture.md`, `docs/plans/<feature>.md`, `docs/progress.md` | `code_lead` | yes |
| `src/` (code and tests) | `builder` | yes |
