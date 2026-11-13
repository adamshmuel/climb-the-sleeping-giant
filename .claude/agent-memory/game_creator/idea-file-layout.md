---
name: idea-file-layout
description: How the idea docs are split (idea now / research / history) and where new text goes
metadata:
  type: project
---

Since 2026-11-03 the idea is three files: `docs/ideas/climb-the-sleeping-giant.md` (the idea as it is now, with a contents list), `-research.md` (dated trend and competitor study) and `-history.md` (what changed, decisions after Gate 1 with their playtest triggers, price reasons). Old section names stay in the idea file as one-line stubs that link to the moved text.

**Why:** agents read the idea file whole at every design, spec and plan; research and history were ~165 of 547 lines. Other docs point at sections by name.

**How to apply:** a new decision's reason and "what would change it" go in the history file; the rule itself goes in the idea section. New research goes in the research file with its date. Never rename a section heading others cite (grep `docs/` and `.claude/` first).

Worktree note (2026-11-04): when running in `.claude/worktrees/<name>/`, write `docs/ideas/` there, not in the base checkout; `work/` is a symlink to the main `work/`.
