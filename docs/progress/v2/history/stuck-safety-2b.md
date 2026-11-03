# Stuck safety Part 2b: history

What happened at each finished task in [2b-walk-pieces-and-head.md](../../../plans/v2/stuck-safety/2b-walk-pieces-and-head.md): its reviews, results and close notes, moved word for word out of the plan. The plan keeps each task's rules, steps and rulings, with a "History:" link to its section here.

**Contents:** [Task 24](#task-24), [Task 25](#task-25)

## Task 24

- **Approved at the first review (code_lead, 2026-10-20).** Diff, tests and world checked: section 2's four states (V1, first run, final without friction, final) end in the same world; `Belly_KneeFoot` and `Belly_BandTop` match Ruling 11. `check.sh` passes; the full run has 2460 passed and 1 failed (the accepted stuck scan, 297: no new spot, none near the ramps, the guards or the old `Belly_Walk` 8). code_lead's Play on the computer and the iPhone 14: the whole climb with no jump, 19 slant walks to Rare egg 1 (all reach it), and each knee guard stops a player with no slide. Rulings on the review points: designer's "gap ≤ 0.2, sink ≤ 0.3" is read where the egg meets his skin (0.00 at every egg centre); the larger off-centre numbers are the egg's round bottom, which designer judged from side shots. The 63° to 66° body-size slope within half a stud past the tip is accepted (Ruling 10's two tests both pass). game_creator checks the moved route points and eggs next (its condition 7), including Rare egg 4 in view after its 2.8 stud drop.

## Task 25

- **Ruling at the Task 25 review (code_lead, 2026-10-21): approved.**
  - **The rails' extra length is 2.75 studs** (`Size.X` 34.60), the value measured at the Task 26 ruling. The builder offered 2.85: it also fits the window, but sinks one rail's lowest corner 0.26 into his drawn skin (limit 0.3). 2.75 leaves room on both sides (0.16 over the skin on one rail, 0.02 into it on the other), so it stays.
  - **The test file a builder edited with a script** (`RealWorld.spec.luau`, step 2 of the resume) is whole: 6915 lines, 159 tests, the Task 24 and Task 26 tests present, and against the last commit only the 5 old tests this task replaces are gone. Rojo's copy in Studio matches the file byte for byte, and the full run is green apart from the accepted stuck scan.
  - **Findings and where they go:** quiet ladder drops (with the phone thud log) and the phone camera turning during climbs: plan 5, Task 26 "The ladder ways down are quiet" (added today). designer's climb mockup retake: designer's revision, before plan 3's boot ladder task compares its climb shot (`docs/progress/v2/stuck-safety.md`, notes). The right forehead band spot (8.0, 98.2, 0.0): Task 23 (Ruling 14).
