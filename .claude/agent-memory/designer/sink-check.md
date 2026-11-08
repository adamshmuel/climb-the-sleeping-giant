---
name: sink-check
description: look checks must measure how deep a main character's skin covers nearby parts (rays), not judge shots only; Rule 103 limits
metadata:
  type: feedback
---
Every look check measures sink depth with rays for parts on or against the giant (rays from above for decks, from outside for walls). Past Rule 103's limits (0.3 studs on a part's two end faces, 0.1 on any other face), or along a walk edge, counts as worse.
**Why:** 2026-11-04: Adam marked wood swallowed by the giant (lap landing up to 2.19, belly ramp planks up to 6.75) that my shot-only checks missed.
**How to apply:** In every look check on climbs, decks or ladders on the giant. Fix by cutting the visible wood to his skin line and keeping the solid walk piece invisible. See [[mockups]].
- 6a2 (2026-11-04): boards cut to his skin line, chained 0.05 drops at bends, passed: overlap wedges read as plank joints, a 0.15 lip and a bare half next to skin were not visible as faults.
- 5b (2026-11-04): before picking a fix for a sunk ladder, measure the sink profile along it; the boot bulge sat near the top, so a swing about the hooks needed 10° and floated the foot. A straight slide out (truss + look together) kept the climb.
- 5b1 (2026-11-04): phone look shots come out 402x186 and blurred, too small to judge sub-stud fits; judge phone on layout only and rely on ray depths for fit.
- p5t13 (2026-11-08): my cuff strap top hung 2.2 outboard of the rim; a straight band beside a rounded arm cannot reach the rim without sinking into it. Before handing over a strap or ramp, ray its top end and its middle line against the cloth, and give it a level tab where it joins the limb.
- p5t13b (2026-11-08): a flat tab can't sit in a 0.03-0.2 band over a rounded cuff rim (cloth fell 0.45-1.06 across 1.5 studs). Ray the whole tab footprint before pricing a tab; walk parts are CanQuery false, so turn it on for ray checks and restore.
- p5t13b flap (2026-11-08): rays on the giant hit its collision shape (left_arm is PreciseConvexDecomposition), which can sit under the drawn mesh; always add a top-down shot with the part tinted to see how far it goes under the drawn surface.
- p5t13b edges (2026-11-08): before handing over any walk piece, ray 0.3 past every open edge of every walk part on the path (both sides). My flap table's "air" cells were a 26-stud drop I didn't flag; the edges grew into a 4th fix.
- p5t13b curbs (2026-11-08): a curb length set in a decision is a guess; ray every 0.1 near its open end after building. The flap curb at "0.8 short" left 2.5-25 drops; it needed 0.25-0.3. Exclude old live copies (World.CuffWalk) from edge rays.
- p5t13b fill (2026-11-08): a visible fill under a cuff ledge stuck out of the drawn arm (pink test, seen from gates 7-8); for a stuck slot over a drop beside a limb, use an invisible solid fill and check it: no sink (GetPartsInPart), top covered (no new floor), stuck dump clean.
- p5t15 (2026-11-08): before calling a strip or ridge a wall, ray across it with an exclude loop (ladders, rungs); the belly's centre strip was gentle at z -26..-24 and the real splitter was the beard ladder's foot 2.4-4 over the cloth.
