# Task 33 and Task 27: fix rules (2026-10-27)

Saved by the main chat so fresh agents have it. The builder's handoff (`work/handoff-p2-task33.md`) is untracked; this is the lasting copy of its decision table and product's ruling.

## Decision table (code_lead)
| Cause step 1 finds (on most of the 5 examples) | Fix | Where |
|---|---|---|
| A. An added part makes the pocket or its roof: a beard ladder rail, rung or climbing bar, `SlideGuard_BeardPocket_2` or `_3`, the nose-top rails, or V1's `ForeheadGuard` plate | Move, shorten, lower or remove **that part**, one number per try (Lessons 2, 19). A visible part goes to designer before step 2 | the section that builds it (Files table) |
| B. A slot under a roof with less than 6 studs of air, his own skin as the floor | If the roof is an added part: row A. If not: **one plain box** closing the slot's mouth, square to the slot, never stepped columns following his skin; at least 0.3 from the no-fill walking band (Ruling 30) | `S4SlideGuards.luau`, a new `PATCHES_33` list beside `PATCHES_32` |
| C. Only his own collision shape (a crease in his head's hull the drawn skin lacks) | Stop. No part is fitted to it (Lesson 19); code_lead and product decide | none |
| D. Only reachable by a jump or a fall, never by walking in | Stop. Product decides whether it joins `RARE_SPOTS` with its rescue (Rule 22) | none until product says yes |
| E. Mixed, or none of these | Stop, list it in `QUESTIONS:` | none |

## Product's ruling on the table

1. Accepts the table before step 2, with rulings for C and D:
   - C (a crease in his own hull): row B's single plain box closes the crease's mouth. A block-off, not a fit.
   - D (only reachable by a jump or a fall): a rare spot only if the rare-spot test proves all four of Rule 22's conditions. Next to the ladder and the walking band, condition 2 is unlikely to hold; then it's fixed as row B.
   - E still goes to product.
2. Designer is asked after step 1, not now. Neither spot is scenery (both on the core climb), the giant is never reshaped, so designer only owns visible parts row A might change. If row A names a visible part, designer rules before step 2.
Viral test: yes only if Play shows 7 of 7 with no hang (a kid wedged under the beard or cap is the "broken game" clip).

## Task 27 (product, 2026-10-27)
Task 27 uses the same table and rulings. A spot on his back or the cushion away from every route (scenery) gets the cheapest fix that keeps players safe: one plain box that blocks it off, or the rare-spot list if all four of Rule 22's conditions hold, never a second try.
