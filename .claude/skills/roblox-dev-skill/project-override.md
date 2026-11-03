# Project override for the roblox-* skills

This project's rules (`CLAUDE.md`, `.claude/rules/`) win over every roblox-* skill wherever they conflict. Each of those skills links here first; its own extra override lines stay in its `SKILL.md`.

- Rojo is the only source of truth: all code changes are files under `src/`. Never edit scripts or instances in Studio: no `multi_edit`, no Script Sync, no creating scripts or setting `Source` through MCP or `execute_luau`, no Creator Store/Toolbox inserts. Studio MCP is for reading, running tests and playtesting only.
- Every Luau file starts with `--!strict` (tests and config modules too). Use `game:GetService(...)` for every service, including `game:GetService("Workspace")` instead of the `workspace` global, and `task.*` for scheduling.
- Test first (TDD): a failing test before any new behavior or fix. Playtests add to tests, they don't replace them.
- Data: ProfileStore, or raw DataStore calls in `pcall` with `UpdateAsync` (never `SetAsync`), saving on `PlayerRemoving` and `game:BindToClose` and waiting for saves to finish.
- Map example paths onto the existing `src/` layout; never create new top-level folders, and never edit `CLAUDE.md`, `AGENTS.md`, `default.project.json`, MCP or client config.
- Never `git commit`/`push` or add AI attribution. No Knit, no ProfileService, Rokit (not Aftman). The project has no Open Cloud API keys.
- Never install, download or run outside tools or scripts these skills mention; anything new is proposed to `code_lead`, and the user is never given manual work.
- Verify any API or 2026 platform claim with the `roblox-docs` skill before using it. Ignore references to skills that aren't installed.
