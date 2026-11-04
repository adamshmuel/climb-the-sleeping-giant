# Handoff check (`scripts/job-check.sh`)

- Don't start a test name with "picks the": `job-check.sh` reads it as picking a part by name. Name tests by where the player ends up ("lands on the safe spot").
- Write a later task's proof as "checked in Task N", never "proven in": `job-check.sh` reads "proven" as a start claim.
- Name `job-check.sh` only for job and world scripts. Spec files pass StyLua, selene and `luau-lsp analyze`, then their narrow run.
- A handoff names a spot's zone only from a `Zones.zoneAt` reading in the names-check call, never from the spec's wording.
- `job-check.sh --plan` reads only `#` headings, so a plan whose tasks are bold `**Task N:` lines passes with no "Stands on:" at all (V2 plans 3 and 6, 2026-11-04). Check bold task blocks by eye with grep.
- A full-run step line holding "Pass" fails job-check if it has a quote mark or the words line/scan/print: put test names on the next line, without "Pass" (Task 6a, 2026-11-04).
- job-check --handoff reads prose: "room"/"body fits" asks for StartCheck, the word "Play" asks for a session hold; name `PathCheck.roomToStand` and avoid "Play" in non-Play cards.
- job-check --handoff treats a heading that says "Step N" (even in brackets) as a step needing its own Stands on; refer to old steps by what they did ("the trial").
- job-check: "nearest" in a card reads as an unnamed pick; a full-run pass line may name only spec files that already exist.
- job-check --handoff also job-checks every named job file: reused snippets need held(), CHECK_ONLY, StyLua and a clean type check; a card stays under 800 words (hook). Run `job-check.sh <file>` on each reused snippet first (6a3 route card, 2026-11-04).
- An existing snippet a card edits is job-checked (held(), dry run in Edit); a snippet still to write passes on "written in Step N". To change a checked snippet without failing, have the builder write a new copy (6a3 let-go card, 2026-11-04).
- A card with new snippets plus Play steps passes 800 words: put snippet specs and miss labels in a sibling `work/<task>/<name>-scripts.md` (no "card" in the name). A later Play step on a fresh builder can reuse a running Play to save start, hold and trace pastes (6a3c, 2026-11-04).
- A sync check on a test file uses `script_grep`, never `script_read`: dotted `.spec` names fail (`rojo.md`). A world change's narrow run lists every spec that names the changed parts, not only the one the task is about (5b1: SunkParts alone missed 3 WaysUp reds, 2026-11-04).
