---
paths:
  - "src/**"
  - "tools/**"
  - "default.project.json"
---

# Rojo and Studio sync

- **Port 34873**, not Rojo's default 34872: another game on this Mac serves on 34872, and connecting to it once copied that game's code into this place. `servePort` in `default.project.json` sets it.
- **Check before asking for Connect:** `curl -s localhost:34873/api/rojo | strings | grep -A1 projectName` must print `MyRobloxGame`. After connecting, Studio must not have `ServerScriptService.GameServer`, `ServerScriptService.GrabItModules` or `ReplicatedStorage.GrabIt`. If it does, disconnect, close the place without saving, and reopen the file.
- Rojo only syncs in edit mode, and the plugin can disconnect after playtests (`[Rojo-Warn] Disconnected`). Before trusting Studio, `script_read` a file you changed. If it's stale, the user clicks Connect.
- `script_read` can't find a script whose name has a dot (every `.spec` file). Check its sync with `script_grep` for a line you just changed.
- **Never use MCP `multi_edit` on synced scripts.** Rojo overwrites Studio edits on the next sync. Edit `src/` instead.
- **Trial and harness scripts never go in `src/` or `tools/`.** Deleting a synced file can crash `rojo serve`. Keep them in `work/` and paste them with `execute_luau`; build any temporary ModuleScripts there and destroy them in the same call.
- **Delete synced folders only with `scripts/rojo-safe-rm.sh <path>`.** `rojo serve` 7.7.1 crashes when a synced folder is removed or moved while it still has files. Deleting a single file is safe. A hook blocks `rm -r`, `rmdir` and `mv` on folders under `src/` and `tools/`.
- Anything built in Studio that must persist lives in the place file (the user saves it) or gets exported into the Rojo tree. Say which one.
