---
name: design-docs-layout
description: How docs/design/v2 is split - style guide index plus one file per spec, build check current vs history, open checks and to-dos in own files
metadata:
  type: project
---

V2 style guide is an index (`docs/design/v2/style-guide.md`) plus one file per spec in `docs/design/v2/style-guide/`. Build check: `build-check-current.md` (latest row per image) and `build-check.md` (full dated history). Play to-dos go in `open-checks.md`, old queued lists in `style-guide-history.md`.

**Why:** `.claude/rules/docs.md` says an agent reads only its feature files, and reference docs hold only what is true now (split done 2026-11-03).

**How to apply:** write new look values into the spec's own file and add the section name to the index's "Where each old section went" table. Add each new image score to both the history session and the current record. Files over 100 lines get a Contents list.
