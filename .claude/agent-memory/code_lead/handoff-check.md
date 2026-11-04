# Handoff check (`scripts/job-check.sh`)

- Don't start a test name with "picks the": `job-check.sh` reads it as picking a part by name. Name tests by where the player ends up ("lands on the safe spot").
- Write a later task's proof as "checked in Task N", never "proven in": `job-check.sh` reads "proven" as a start claim.
- Name `job-check.sh` only for job and world scripts. Spec files pass StyLua, selene and `luau-lsp analyze`, then their narrow run.
- A handoff names a spot's zone only from a `Zones.zoneAt` reading in the names-check call, never from the spec's wording.
- `job-check.sh --plan` reads only `#` headings, so a plan whose tasks are bold `**Task N:` lines passes with no "Stands on:" at all (V2 plans 3 and 6, 2026-11-04). Check bold task blocks by eye with grep.
- A full-run step line holding "Pass" fails job-check if it has a quote mark or the words line/scan/print: put test names on the next line, without "Pass" (Task 6a, 2026-11-04).
- job-check --handoff reads prose: "room"/"body fits" asks for StartCheck, the word "Play" asks for a session hold; name `PathCheck.roomToStand` and avoid "Play" in non-Play cards.
- job-check --handoff treats a heading that says "Step N" (even in brackets) as a step needing its own Stands on; refer to old steps by what they did ("the trial").
