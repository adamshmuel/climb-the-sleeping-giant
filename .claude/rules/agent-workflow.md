# Agent workflow

How the project agents work together. Today: `game_creator` and `designer`. New agents get a row in each table below.

## Adam only approves

Adam's only jobs are the two gates and the decisions that are his to make (the "ASK ADAM" questions). Never give him manual work, such as resizing windows, clicking in Studio, or setting things up. Agents and the main chat solve it themselves, or accept the limit and say so in one line.

## Main chat is the messenger

Agents never talk to each other directly. The main chat carries every message between them:

- Start an agent with the Agent tool, and keep its agent ID.
- Send follow-ups with SendMessage to that ID, so the agent keeps its context.
- Forward questions and answers in full. Don't summarize them in a way that changes their meaning.
- Show Adam each relay in one line: `designer → game_creator: <what it asked>`.
- If an agent can't be resumed (for example, in a new session), start a new one and give it the file paths below. The files are the shared memory.

## Who owns what

| Topic | Owner |
|---|---|
| Game idea, gameplay, players, business and monetization | `game_creator` |
| Look and feel, style guide, mockup images | `designer` |
| Tools, setup, agent configuration | main chat |

## The flow

1. **Idea.** `game_creator` proposes ideas. Adam picks one, and `game_creator` saves it to `docs/ideas/<name>.md`.
   **Gate 1: Adam approves the saved idea.**
2. **Design starts.** After Gate 1, the main chat starts `designer` and gives it the idea file path.
3. **Questions instead of guesses.** When `designer` is unsure about the game, it asks. The main chat passes the question to `game_creator` and brings back the answer. If `game_creator` doesn't know either, the question goes to Adam. Nobody guesses.
4. **game_creator review.** When `designer` finishes, the main chat sends `game_creator` the image paths. It checks four things:
   - **Look and feel:** do the images match the idea?
   - **UI/UX:** layout, readability and phone-first design. Use the `design:design-critique` and `design:accessibility-review` skills.
   - **Business:** does the design support the idea's monetization and retention plan? Examples: are purchases easy to find without being pushy, and does the thumbnail sell the twist?

   - **Buildable:** can a beginner build it in Roblox Studio, and will the real game look like the mockups? Uses the designer's `build-check.md`. This check comes first: if the game can't be built, the others don't matter.

   It replies with either **approve** or **changes**, plus a numbered list. Changes go back to `designer`. After 3 rounds without approval, stop and ask Adam.
5. **Gate 2: Adam approves the images.** After `game_creator` approves, the main chat shows Adam the images and the review. Any changes Adam asks for go through steps 3–4 again.

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
| `docs/design/<name>/references/` (other games' images) | `designer` | **no**, because those images belong to other games |
