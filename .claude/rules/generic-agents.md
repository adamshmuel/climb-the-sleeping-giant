# Generic agents

The agents in `.claude/agents/` will be reused to build other Roblox games. So an agent definition describes a role and how to do it well, for any game.

- **Nothing about this game goes in an agent file:** no game name, mechanics, characters, numbers, file names of this game's docs, or decisions.
- **Game facts live elsewhere:**

| Kind of fact | Where it goes |
|---|---|
| The idea, the look, the specs, plans and progress | `docs/` |
| Project rules (workflow, gates, tests, git) | `.claude/rules/` |
| Reusable know-how, tools and data sources | `.claude/skills/` |
| Project overview, layout and Studio setup | `CLAUDE.md` |

- **Agents point, they don't copy.** When an agent needs game facts, its definition says where to read them, for example "read the version's spec index and your feature file", never the facts themselves.
- **Examples in agent files are neutral**, for example "Task 3: Coins are saved when the player leaves", never a mechanic of this game.
- **Before editing any agent file,** check the change against this rule. If it would add a game fact, put that fact in the right place from the table instead and point to it.
