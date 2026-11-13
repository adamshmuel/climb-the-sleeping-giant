# Stuck safety Parts 3 and 4: history

What happened at each finished task in [3-4-bot-and-rescue.md](../../../plans/v2/stuck-safety/3-4-bot-and-rescue.md): its reviews, results and close notes, moved word for word out of the plan. The plan keeps each task's rules, steps and rulings, with a "History:" link to its section here.

**Contents:** [Task 8](#task-8), [Task 12e](#task-12e), [Task 12f](#task-12f), [Task 12b](#task-12b), [Task 12g](#task-12g), [Task 12h](#task-12h)

## Task 8

- **Review round 1 (code_lead, 2026-10-28): changes.** The step-off thinning compares flat distance only, so an edge on a lower ledge within 10 studs (flat) of a higher edge loses all its step-offs. Rule 24 (A bot walks every way, `docs/specs/v2/stuck-safety.md` line 118) asks for every edge, and section 5 (line 155) for one step-off every 10 studs along each edge. Fix, test first: a new test "keeps a step-off on a lower ledge beside a higher edge" (a 3-stud ledge with its top at y 4 beside the 30-stud top); then a kept start crowds a new one only when it is also within 2 studs in height. 3 more Studio calls (red, green, legs run again), past the 6 planned, so product rules on them first. No full run: nothing else requires `BotLegs`.

- **Review round 2 (code_lead, 2026-10-28): approve.** The new test "keeps a step-off on a lower ledge beside a higher edge" failed first for the right reason (call 7: 3 passed, 1 failed on `onLedge > 0`). Now two starts crowd each other only when they are also within 2 studs in height (`SAME_HEIGHT`), and the filtered run passes (call 8: 4 of 4). Task 8's full run (call 6: 2701 passed, 0 failed, scan 117 of 7482) still stands, because only the BotLegs tests use the module.

## Task 12e

- **Status: done** (2026-10-29): approved by code_lead, full run 2840 passed, 0 failed. 30 of 31 Studio calls. Every computer try passed. On the phone, one try failed only on "the meter never rises" (0.8 before the move); product closed the task there and moved that part of Rule 31 (Being stuck is silent) to Task 12f (`work/t28/product-ruling.md` lines 453 to 460).

## Task 12f

- **Status: done** (2026-10-29): approved by code_lead, full run 2844 passed, 0 failed. 12 of 13 Studio calls (the spare went on a wrong service name in the device call). On the iPhone 14 the stuck carrier shook (biggest step 0.898) and stayed silent: meter 0.000 before the move and 0.000 in the held second, moved at 3.866 s, the Rare kept, `Held` true then cleared. Rule 31 (Being stuck is silent) is now proven on the phone; Task 12b checks it again in the real wedges.

## Task 12b

- **12b-1 rerun result (2026-10-29, `work/t12b/code-lead-ruling-12b1r.md`):** all 3 notch rescues held the player still and landed them 8 to 10 studs clear, but the meter rose after every move (+6.7, +6.9 and one whole thud, +35). That is a real fault against Rule 31 (Being stuck is silent), so the notch gets no more Play runs and the fix is **Task 12g**. **12b-2 waits for Task 12g.** Its Silent check on every beard rescue is 12g's Play proof.

- **12b-2 result (2026-10-29, `work/t12b/play-2.md`, product's ruling "Task 12b-2 beard results" in `work/t12b/product-ruling.md`):** the beard wedge still exists, 5 studs further east than the old point, at (-5.9, 86.1, -10.1). All 5 walks stalled there standing (never in the Climbing pose), and the server rescued all 5 silently. But 2 of 5 came after the 4 s proof time (4.35 s and 5.27 s), because the stuck time starts over on every falling flicker of a body on the 44-degree slope. The job's old reach point stopped it before Moved, Held, Egg and landing were judged (a Play job always judges a rescue that happens). 10 Studio calls, cap 12.

- **Status: closed** (2026-10-29), 44 Studio calls in all. The notch is proven (12b-1 rerun). The beard proof is **not passed**: the fix is Task 12h, and the 3-walk beard proof moves into Task 12c's Play run. Gate 4 stays blocked until it passes.

## Task 12g

- **Status: done** (2026-10-29): approved by code_lead, full run 2849 passed, 0 failed. 5 of 4 planned Studio calls (one extra to read why the reds failed). Play proof: Task 12b-2's Silent check.

## Task 12h

- **Status: done** (2026-10-29): approved by code_lead, full run 2853 passed, 0 failed. 4 of 4 planned Studio calls. Test A failed in the red run, so the cause stands. Play proof: Task 12c's 3 beard walks.
