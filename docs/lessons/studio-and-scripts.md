# Lessons: Studio, Rojo and scripts

About deleting files, reading output, and writing scripts for Studio. The map of all lessons is `docs/lessons/index.md`.

## Lesson 3: Removing a synced folder crashes Rojo
- **What happened:** `rojo serve` 7.7.1 crashed about 6 times when builders deleted trial folders in `src/`. Each crash cut Studio off, and the user waited about 3.5 hours in all to click Connect.
- **Do instead:** trial scripts live in `work/` and go into Studio through `execute_luau`. Delete a synced folder only with `scripts/rojo-safe-rm.sh`. A hook blocks unsafe deletes (`CLAUDE.md`, "Dev loop").
- **Who checks:** `builder`, the main chat.

## Lesson 6: Never pull the whole console into an agent's memory
- **What happened:** builders often went over their memory limit. One filled up from a single unfiltered `get_console_output` that held the whole earlier test log (Task 37, step 37-3).
- **Do instead:** send long output to a file in `work/`, filter it, and read only the summary (at most about 100 lines).
- **Who checks:** `builder`, `code_lead`.

## Lesson 7: A Luau line can't start with "("
- **What happened:** pasted trial scripts failed to parse because a statement started with `(`, which Luau reads as part of the line before (Tasks 32 and 37). Each failure wasted a Studio call.
- **Do instead:** put the value in a local first, for example `local parts = (...)`.
- **Who checks:** `builder`.

## Lesson 22: Long Play work runs in the background
- **What happened:** in Task 37's last Play check, code_lead's two client calls each waited inside the call and came back "Request timeout", so nothing was measured (2026-10-27). The builder's earlier scripts also depended on a helper module it removed before the next check.
- **Do instead:** a client call starts long work with `task.spawn`, stores the results in `shared`, and returns at once; a second call fetches them. A helper module a later check needs stays in Studio until that task closes. A full test run keeps Studio busy the same way: start it, wait in Bash, then fetch the result. A call that comes back "Studio not reachable" means Studio is busy; wait in Bash before the next call, never retry at once.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 28: Each object's recorded places live in one module
- **What happened:** Task 41's flat pillow had its size, place and turn check written twice, in two world-script sections, because the second section copied the first one's numbers (2026-10-27). Changing one would silently break the other.
- **Do instead:** an object's recorded sizes and places go in one shared module that every section and test reads, never copied into a second file.
- **Who checks:** `code_lead` (in the review), `builder`.

## Lesson 29: Fetch background work once, when it's done
- **What happened:** in Task 42 step 2 the builder started the world script and the full tests in the background (Lesson 22), then fetched twice before they finished. Both fetches found nothing new, the step went 2 calls over its cap, and the results were never read (2026-10-27). Lesson 24 had fixed this kind once already, for a different cause.
- **Do instead:** the background job sets a `done` flag and its finish time in `shared`. Before fetching, wait in Bash for the job's usual time (the handoff gives it, for example a full test run). The fetch call itself waits inside for the `done` flag for up to 30 seconds (under Studio's ~45-second limit), then returns what it has. One fetch per job.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 31: A background job reports as it goes
- **What happened:** Task 33 step 1's Play job (22 walks, about 105 s) wrote its results only at the end. It never finished, two fetches came back empty, and nobody could tell where it hung (2026-10-27).
- **Do instead:** a background job writes one short line into `shared` after every try, plus a heartbeat count, so a fetch always shows how far it got. Keep each job small (one spot or one kind of walk). A fetch that shows no progress means stop and report the last line, never fetch again.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 34: Placing numbers are fixed, and each part gets its own try
- **What happened:** Task 33's handoff left the forehead box's bottom to be worked out from rays inside the placing call. One ray started inside V1's plate, the start check failed, and the whole call stopped, so the beard box wasn't placed either. One Studio call was spent with nothing built (2026-10-27).
- **Do instead:** the measuring call prints every ray start's open check on its own line, and turns the results into fixed numbers (CFrame and size) in the handoff. The placing call only places those numbers, with each part in its own `pcall` and its own pass or fail, so one part's problem never stops the others.
- **Who checks:** `code_lead` (in the handoff), `builder`.
