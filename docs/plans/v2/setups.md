# V2 setups from 7 on

Setups are small extra tasks added between plan tasks: fixes to the tools the team uses, not to the game. Setups 1 to 6 are in `docs/plans/v2/index.md`. Progress: `docs/progress/v2/setups.md`.

## V2 setup 7: The full-run report says why each test failed

Added by code_lead on 2026-10-29, at the Task 12g review. Built right after stuck safety Task 12b-2, before Task 12c.

- **Why.** A full test run is fetched as a short report (`src/tests/BackgroundRun.luau`). For each failed test it lists only the name (`failedNames`, cut to 100 characters by `NAME_LIMIT`). So every red step pays one more Studio call just to read why each test failed. It happened in Task 12g step 1, and the main chat logged it in `docs/problems-log/studio-and-scripts.md`. Tasks 12c and 13 to 16 still have red runs, so this pays for itself after about two of them.
- **What it's for:** a tool, not the game. Players see nothing.
- **What changes:** each `FAILED:` line also says why: `FAILED: <name> | <why>`. "Why" is the test's first failure message with Jest's colour codes removed, its non-empty lines joined with " / ", cut to 150 characters (a number players can't see). The report stays under 900 characters (`REPORT_LIMIT` 880 is unchanged), so fewer lines fit and the rest still end in "and N more". Three reds always fit.
- **No copies:** the colour remover `stripColors` now lives in `src/tests/TestRunner.luau` only. It moves to a small new module, `src/tests/PlainText.luau`, used by both files.
- **Files:** `src/tests/BackgroundRun.luau`, `src/tests/TestRunner.luau`, new `src/tests/PlainText.luau`, `src/tests/server/Tools/BackgroundRun.spec.luau`.
- **Failing tests first** (one red full run):
  - "a failed test's line carries its first failure message, cut short";
  - "a message with many lines is joined on one line, with blank lines and colours removed".
  - The two existing tests that spell out the old line ("names each failed test cut to 100 characters ...", "lists every failed test by name ...") get the new line in their expected text in the same step, because the report's format is what changes. So the red run has exactly 4 reds.
- **Size:** 1 step, 4 Studio calls (cap 5), Sonnet: two full runs, red then green, each a start and a fetch. Handoff: `work/handoff-setup7.md`.
- **Done when:** the full run passes with 2851 tests (2849 plus the 2 new ones), and `scripts/check.sh` passes. No Play check: nothing in the game changes.
- Lessons: 51 (A full test run is fetched again, never started again), 52 (`expect` takes one value), 101 (Tests run red before any code is written).
- **Status: not started.**

## V2 setup 7b: The full-run report really shows why

- **Why:** in its first real use (Task 12h's red run) the report still listed only names. The start script loads the report code with a plain `require`, and Studio keeps a module's first loaded copy for the whole session, even after Rojo syncs new code. So the report came from the old code. Setup 7's own tests passed, because the test runner loads each module fresh.
- **Files:** `scripts/studio/full-run-start.luau` and `scripts/studio/full-run-fetch.luau` load `BackgroundRun` from a clone, as the start script already does for `TestRunner`. No change in `src/`.
- **Proof:** no unit test can see Studio's cache. A read-only probe (`work/setup7b/confirm.luau`) builds one report from a real-shaped failed result, with the cached copy and with a fresh clone. Pass: the cached copy shows no reason, and the fresh one does.
- **Size:** 1 step, 1 Studio call (cap 2), Sonnet. Handoff: `work/handoff-setup7b.md`.
