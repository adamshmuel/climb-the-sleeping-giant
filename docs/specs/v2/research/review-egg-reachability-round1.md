# Spec 4 (egg reachability), review round 1 (2026-10-14)

Both reviewers asked for changes. They are saved here in full so a fresh product agent can apply them.

## game_creator: changes (2)
Idea fit and business fit are good.
1. **Section 5 "Sink limit" (0.3 studs) and Rule 59 (Eggs sit on something you can see).** The check would fail Rare egg 1 on its first run.
   - designer's style guide lets a leaning egg dip about 1 stud into the slope at its low edge, and Rare egg 1 measures 0.9.
   - Business need: every egg designer approved as "seated" passes, and a buried-looking egg still fails.
   - designer picked how to measure it (see designer's item 2).
2. **Section 6, row "An empty Epic or Legendary nest", and section 9, risk row "Legendary gold blends into the gold footprints and the gold meadow egg rings".** Both describe V1 things that spec 5 removes.
   - Change the section 6 row to: "Until spec 5 is built: V1's empty-spot look. After spec 5: an empty straw nest with no timer (spec 5, Rule 77: Empty nests show no timer)".
   - In the risk row, add that the meadow rings go with spec 5, and that Legendary nests never sit in the meadow anyway.

## designer: changes (4)
On product's three points:
- **Tint:** product was right. `SurfaceAppearance.Color` can be set by a script. The style guide is fixed, and Rule 51 needs no change.
- **ranks-desktop.png:** the purple eggs are fine, on his moustache.
- **The phone view:** not acceptable (see item 3).

1. **Rule 50 (The score sets the rank), the eye limit.** "Near his eyes" can't be checked as written, so use the style guide's definition:
   - From any garden's spawn spot and from the belly path, a purple egg must not touch his face skin on screen (eyes, eyelids, cheeks, nose, forehead).
   - It must keep at least one egg height of space below his closed eyes. His beard, moustache, belly and boots are fine.
   - If a nest that scores Epic breaks this, the nest moves (Rule 54's fix). It is never given a different rank.
   - designer checks this in the built game from all 8 spawn spots. It is not part of the automatic test run.
   - Add an edge case: "`EggSpot_Rare_4` scores Epic and shows under his left eye from garden 4: move the spot." (In the mockup, the gold egg there sits about 0.4 egg heights under his left eye.)
2. **Rule 59 and section 5 "Sink limit": designer picked game_creator's option (b).** It is the only option measured and checked by eye.
   - The sink is measured at the egg's lowest point.
   - The limit is 0.3 studs for an upright egg, and 1 stud for an egg leaning with a slope. A leaning egg is tilted to follow the slope under it, like V1's Rare eggs (18–30°).
   - Rare egg 1 measures 0.9 and passes. The Epic and Legendary mockup eggs measure 0.5 or less.
   - Playtest trigger: keep "looks half-buried but passed", and set it to lower the leaning limit to 0.6.
   - The "Sits on" column in the egg-ranks report also says "upright" or "leaning".
   - Option (a), measuring from the egg's centre, was never measured, and on a slope it could pass an egg whose uphill side is buried.
3. **Rule 52 (The rank shows everywhere), section 6 row "Looking at the giant from a garden", and the section 9 risk row "Rare egg 1 is hard to spot".**
   - On a phone, the green and blue eggs don't read from the spawn spot. Phone scored 3 against the top games' 4, which also fails Rule 52.
   - The pale green Uncommons blend into the trees. The blue Rare is blue on blue pyjamas, and mostly behind the avatar's head.
   - Keep the rule. Add to section 6 that waiting Uncommon and Rare eggs get a stronger visibility effect in their rank colour, with values from designer's retake (style guide "Egg ranks").
   - Change the risk row: the fix is now in this spec, and the playtest trigger stays for strengthening it further.
4. **Rule 52, the words on carried eggs and home eggs.** The rule puts the rank word on "the egg on a carrier's back" and "the eggs shown at home", but V1's style guide gives both no label, to keep the screen and the garden calm.
   - The egg always shows its rank colour.
   - The word shows on the waiting egg's label, the carry pill and the "Safe!" card.
   - Carried eggs and home eggs keep V1's no-label look.

## Retakes for a designer with Studio (queued)
- `view-ranks.png`, `view-phone-ranks.png`, `ranks-desktop.png` and `ranks-phone.png`: add the visibility fix for Uncommon and Rare, so the phone score reaches 4.
  - Try first: a soft glow halo in the rank colour behind the egg, about twice the egg's size.
  - Try second: a short colour beam, shorter for Uncommon than for Rare.
  - Nothing may cover his eyes. Beams from belly eggs can cross his face.
  - Re-measure the eye gap with `EggSpot_Rare_4` lowered 2.4 studs.
  - Write the tested values into the style guide and `build-check.md`.
- If the fix changes how waiting Uncommon eggs look up close, also retake `wayup-boot`, `ladder-top`, `climb` and `plank`, or record in `build-check.md` why it isn't needed.
- Not yet checked: how the other 7 gardens' spawn views place the belly eggs against his face.
