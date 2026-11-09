# 7. Quality checks before every handoff

Part of [the architecture](../architecture.md).


The builder runs these before saying "done", and `code_lead` runs them again in review. Both parts must pass.

**1. In the terminal, one command:**

```
./scripts/check.sh
```

It runs, in order, and stops at the first failure:

| Step | Tool | Checks |
|---|---|---|
| Size (from stuck safety Task 31) | a line count | No `.luau` or `.md` file in `src/`, `tools/` or `docs/` is over 1000 lines; it names any that are. A file of 901 to 1000 lines gets a note (no failure), so it is split by topic before more is added |
| Build | `rojo build` | The project builds into a place file |
| Format | `stylua --check src tools` | The code is formatted the house way (tabs, 120 columns) |
| Lint | `selene src tools` | Common mistakes |
| Types | `luau-lsp analyze` with Roblox's type list | Strict type checking of every file |

**2. In Studio:** the test command from section 6.

**Before trusting Studio:** `rojo serve default.project.json` must be running, and `script_read` of a changed file must show the new code. If Studio is stale and the Rojo plugin shows "Disconnected", no agent can click Connect: the agent stops and reports it.

**Tools** are pinned in `rokit.toml`: Rojo, StyLua, selene, luau-lsp, Wally (`UpliftGames/wally@0.4.0-alpha.0`, the only Wally build that runs on this Mac's Apple chip; tested 2026-10-12) and wally-package-types. After `wally install`, `wally-package-types --sourcemap sourcemap.json Packages/` is run so library types show up in type checking.
