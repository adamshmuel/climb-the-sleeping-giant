# MyRobloxGame

**The goal: a game that can go viral.** Every look, feel and gameplay decision answers "Could it go viral looking and feeling like this?" and "Would a kid pick ours over the top game next to it?" (`.claude/rules/viral-goal.md`). This comes before every other rule.

Roblox game built with Rojo. The code's source of truth is `src/` in git; Roblox Studio is driven through the Roblox Studio MCP.

## Check before you claim
For the main chat and every agent that loads this file. Based on the prompting guide's [investigate before answering](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) sample.
- Never state a number, time limit, interval, setting, URL, API name, file content or "it works" as a fact unless it was checked in this session: run it, fetch it, read the file or the guide.
- When something isn't checked, check it first, or say "not checked" in the same sentence. A guess is never the reason given for a recommendation.

## Follow Anthropic's guides
The agent setup (this file, `.claude/rules`, `agents`, `skills`, `hooks`, settings and the workflow) follows Anthropic's official guides: [best practices](https://code.claude.com/docs/en/best-practices), [memory](https://code.claude.com/docs/en/memory), [subagents](https://code.claude.com/docs/en/sub-agents), [skills](https://code.claude.com/docs/en/skills), [hooks](https://code.claude.com/docs/en/hooks).
- Before any setup change or suggestion, the user's included, check the guide and say in one line: it fits, or the better way the guide gives, with the link.
- `.claude/hooks/setup-guides.py` enforces it: a reminder on setup prompts and edits, a block on CLAUDE.md or a rule file past 200 lines (SKILL.md past 500), and a block on shell writes to setup files.
- `.claude/hooks/guides-check.py` compares the guide pages, model pages included, with their last reviewed copies at every session start. Changed lines are reviewed at the next task close (`guides-check` skill).
- A learning goes to its home, never into this file: a hook if it must always happen, a rule or path rule if every agent needs it, a skill if it is a procedure, or the agent's own memory (`memory: project`) if only that agent needs it (`closing-a-task` skill).

## Layout (default.project.json)
- `src/shared` → `ReplicatedStorage.Shared` (ModuleScripts used by both sides)
- `src/server` → `ServerScriptService.Server` (`init.server.luau` = Script)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (`init.client.luau` = LocalScript)
- `tools` → `ServerStorage.Tools` (world scripts; run by requiring a copy)

Logic goes in ModuleScripts; `init.*.luau` files only require and wire things up. Path-scoped rules load with the files they cover: `luau.md` (code and tests), `rojo.md` (sync), `docs.md` (writing docs), `generic-agents.md` (agent files).

## Agents
Project agents live in `.claude/agents/`. Their definitions are generic, for reuse in other Roblox games; facts about this game go in `docs/`, rules and skills.

| Topic | Owner |
|---|---|
| Game idea, gameplay, players, business and monetization | `game_creator` |
| Look and feel, style guide, mockups | `designer` |
| Specs and the order of work | `product` |
| Reviewing what was built, as a player and against its spec | `product_reviewer` |
| Code architecture, plans, task breakdown, code review, progress | `code_lead` |
| Code and its tests | `builder` |
| Running jobs others wrote: test runs, fetches, names checks | `runner` |
| Tools, setup, agent configuration, commits | main chat |

The main chat is the messenger between the agents and the user. How they work together is in `.claude/rules/agent-workflow.md`; the steps and gates are the `the-flow` skill.

## Model per job
Each job uses the cheapest model that does it well.

| Kind of job | Model |
|---|---|
| **Thinking:** ideas, looks, specs, plans, reviews, rulings, finding why something failed | Opus |
| **Building:** tests, code and Play jobs; running Play and judging it against a pass list | Sonnet (`builder`) |
| **Running only:** a full test run and its fetch, a read-only names check, copying files, filling a table from given numbers, `scripts/job-check.sh` | Haiku (`runner`) |

- Every full test run goes to the `runner`, never inside a Sonnet or Opus step. The `builder` writes code and sees its red; `code_lead` judges the result.
- `code_lead` keeps the thinking and hands its simple jobs to `builder` or `runner` as a short prompt in `work/`.
- **`code_lead` on Sonnet for simple jobs.** Plans, rulings and reviews stay on Opus. A job with nothing new to decide (a task card copied from a finished plan, a re-check against a written list) starts `code_lead` with the Agent tool's `model: "sonnet"`, which overrides its file ([sub-agents](https://code.claude.com/docs/en/sub-agents#choose-a-model)). A resumed agent keeps its model, so this is a fresh start with the file paths.
- If a cheaper model fails a step, the step goes up one model, that kind of job moves up in this table, and it is logged in the problems log.

## Speed rules
| Rule | What it means |
|---|---|
| **Hard time limits** | A small fix (a moved part, a missing part, a failing test): **10 minutes**. A new part or a task: **1 hour**, or its planned time if shorter. At the limit, work stops and the `stop-and-step-back` skill starts. Over the limit means the approach is wrong, not that it needs more time. |
| **Small jobs, few agents** | A small fix is done by one agent (the main chat or one `builder`), checked by one `runner` test run, then committed. No meeting, no handoff, no review round. The full flow is only for new parts and features. |
| **Backup before every world change** | A step that changes, moves or removes world parts clones them into `ServerStorage.WorldBackups.<task>` in the same call. Before a task's first world change, the main chat copies the saved place file to `work/place-backups/<task>-<date>.rbxl`. Backups are cleaned out only at Gate 4. |

When a task starts, the main chat starts its task clock (`stop-and-step-back` skill, "Triggers"). Every stop trigger (time, loop, same object, plan, look) and what to do is in the `stop-and-step-back` skill. Each task close uses the `closing-a-task` skill.

## Roblox Studio MCP
- Call `list_roblox_studios` first to get the `studio_id`. If it is empty, stop and report.
- Use the MCP for runtime and world work: `execute_luau` to build and inspect non-synced instances (Workspace parts, maps, lighting), plus playtesting, console output and screenshots. Code changes go in `src/`.
- Deleting or replacing instances needs no confirmation from the user when the change matches the spec and its owner (`product`, `game_creator` or `designer`) approved it. Bigger changes follow "Asking the user" in `agent-workflow.md`.
- Built-in MCP skills via the `skill` tool: `rbx-unit-test`, `rbx-debug`, `rbx-perf-profiling`, `rbx-scene-analysis`, `rbx-device-simulator-lua`.
- Use the `roblox-docs` skill before relying on memory for any Roblox API. Never guess API names or signatures.

## Dev loop
0. **Keep the Mac awake.** Before Studio work, check `pgrep -x caffeinate`; if nothing runs, start `caffeinate -d -i -u` in the background (one copy). Stop it when the session's Studio work is done.
1. Edit `src/`. A PostToolUse hook runs StyLua and selene on `.luau` files; fix what it reports.
2. Make sure this project's `rojo serve` runs on **port 34873** (not 34872, which another game on this Mac uses) and the Studio plugin is connected. Details and the check before Connect: `.claude/rules/rojo.md`.
3. `start_stop_play` → `get_console_output` → fix → stop play.

Tools are pinned in the Rokit manifest; run `rokit install` after cloning.
