# Specs 1, 3 and 5 after the big rewrite: review (2026-10-18)

**Contents**

- [designer: changes (16), review only, no Studio](#designer-changes-16-review-only-no-studio)
- [Confirmed list of mockups still to make (designer, Studio)](#confirmed-list-of-mockups-still-to-make-designer-studio)
- [game_creator: changes (3), plus a confirmation](#game_creator-changes-3-plus-a-confirmation)
- [game_creator: which nests spec 3's fairness checks use (answer to designer item 10)](#game_creator-which-nests-spec-3s-fairness-checks-use-answer-to-designer-item-10)

## designer: changes (16), review only, no Studio
**Spec 5 (egg-nests-and-climbing.md)**
1. **Words "Seam", Rule 80, section 5 "Seam match", section 6 (art):** the seam isn't "painted" on his texture. It is made of small flat parts (cream stitch dashes plus a hem-blue band, with no collision) laid on his pyjama. Re-texturing the generated mesh isn't a beginner build. Fix: "a stitched seam made of small flat parts laid on his pyjama (style guide, 'How the seam looks'); his texture doesn't change."
2. **Rule 79:** change "No more than 1 stud above his visible skin" to "no more than 1 stud above the visible surface under it (his skin, a strap or a pocket ledge)".
3. **Section 6, "Looking at the giant from a garden":**
   - From a garden, eggs on him show their rank by colour and glow only; the words appear within 75 studs. "Each with its V1 rank label" is wrong.
   - The mockups marked "Made" only show the cuff egg, with the old planks.
   - Add the nest-map shots (list item 10) as "To make".
4. **Section 6:** add a row "A Legendary nest on the nightcap" (To make: item 11). Add a line saying spec 4's `epic-egg-*`, `legendary-egg-*` and `ranks-*` still hold for colour, glow, label and carry pill, but NOT for where the eggs sit.
5. **Section 6, "He's awake, right cuff egg raised":** name the files (item 2).
6. **Section 6, "The slide tip":**
   - the tip sits "bottom centre, between the thumbstick and the Jump button";
   - add `view-slide.png`, `view-phone-slide.png` and `slide-tip-carry-desktop.png`.
7. **Section 6, "Carrying, sliding, grabbing, home":** remove "sliding".
8. **Rule 77 and section 6, "A new egg appears":** designer writes "The refill pop" under "Nests" (item B), and Rule 77 points to it.
9. **Section 8, "The red slam circle under a sliding player":** "first walkable surface straight below, following that surface's shape" (as spec 6, line 103).

**Spec 3 (gardens-and-ways-up.md)**
10. **Section 1 "Rare egg 1", Check A1, Rule 41 and section 4's bot-walk line:** "Rare eggs 2 to 4 don't move" contradicts spec 5 Rule 70, which removes every V1 spot except Rare egg 1. V1's Rare egg 2 spot (−11.2, 50.1, −34.8) has no V2 nest and fails the eye limit. Fix (product with game_creator): replace the "Rare egg 2" checks with a spec 5 nest (for example the beard–belly fold), or point them to Rule 73. Drop "Rare eggs 3 and 4".
11. **Section 1 (boot ladders), Rule 37, section 2:** "4 studs from Uncommon egg 1/3" becomes "4 studs from the outer boot toe nest (spec 5)" (measured about 3.6).
12. **Section 6 (slam row), section 8 (circle), section 11 (Rule 13 rewording):**
    - use "first walkable surface straight below, following its shape";
    - the section 5 "Ladder slam warning" row adds that the red glow never shows through his body (depth mode "Occluded").
13. **Section 6, the rows for the gardens 4/5 spawn, the ladder top and crossing a lap plank:** `wayup-plank-*`, `ladder-top-*` and `plank-*` were shot before the planks moved. Mark them "To retake" (item 12). The fork row has world shots but no screen-layer shots.
14. **Rule 45:** "a 35–45° rise over his lap fold" becomes "over the crease of his lap" (the "Lap fold" nest is on his boot).

**Spec 1 (new-player-safety.md)**
15. **Section 6, "A new player passes 85%" and "The free save":**
    - `core-*-warning.png` and `view-*warning.png` hold only for the meter, the tip and the Tiptoe glow; the bubble and snort follow the style guide and `view-phone-warning85-g8.png`.
    - Add the bubble limits as pass conditions: shows from every garden, below the meter, clear of his eyes and cap, words at least 12 px on a phone.
    - Say the words measure about 9 px today and fail; a fixed-size phone bubble is being tested.
    - Replace "Still to make" with item 13.
16. **Section 6, "The real wake-up":** point to `wake-face-desktop.png` and `wake-face-phone.png` (spec 6).

**Not a look item:** the lap fold reading ("not on the plank's deck") still needs game_creator's yes.

## Confirmed list of mockups still to make (designer, Studio)
All go in `docs/design/v2/mockups/`, on computer (1280×720) and phone (844×390).

**Before shooting:**
- **A. Make the art:**
  - the straw nest (one model, about 4 wide and 1.5 tall);
  - the lace bow;
  - 8 sewn pockets (cream for the knee and belly pockets, pyjama blue for the cuffs);
  - a smooth strap edge;
  - the seam stitch dashes and hem band.
  - Then write `docs/design/v2/art-list.md`, which doesn't exist yet.
- **B. Write the refill sparkle pop values** in the style guide.

**Spec 5:**
1. `view-epic-pocket` (and phone).
2. The wake with the right cuff egg raised: `view-phone-wake-cuff-g1` to `-g8`, plus `view-wake-cuff-g7` and `-g8`.
3. `view-meadow-nests`.
4. `view-nest-empty`.
5. `view-nest-refill` (needs B).
6. `view-belly-top`.
7. `view-seam`.
8. `view-slide` (and phone).
9. `slide-tip-desktop/phone` and `slide-tip-carry-desktop/phone`, from a new `nests-hud.html`.
10. `view-nest-map-g4` and `-g2` (and phone): all 38 nests.
11. `view-cap-nests` (and phone).

**Spec 3:**
12. Retake `wayup-plank-*`, `ladder-top-*` and `plank-*` on the moved build: 4° planks, the 11.2-wide landing with its apron, the forked trail, and no egg at the old Rare egg 2 spot. The `ladder-top` shot also shows the boot toe nests and the lace bow.

**Spec 1:**
13. The 85% warning:
    - First finish two tests: a fixed on-screen bubble size on phones (about 120×40 px, 14 px words), and a bigger snort (20 puffs per burst, or the emitter 2 studs out).
    - Then shoot `view-warning85-g1` to `-g8` on computer and phone.
    - Then make `warning85-desktop/phone` from garden 1.

**Already made and correct:** `view-lapfold*`, `view-lapfork-*`, `view-rare6-g4*`, `test-cuff-strap.png`, `test-rare6-close.png`.

## game_creator: changes (3), plus a confirmation
**Lap fold reading: CONFIRMED.** "Not in the middle of the plank" meant not on the deck. designer's spot beside the plank's middle stretch fits. The squeezed groove is out. Spec 5's wording needs no change.

1. **Two Rare pairs score over the Rare limit, with no fix that works.** Rare egg 1 is about 78, and each extra stud costs about 1.3 points. That puts the belly pocket (6.1 studs away) at about 85–91 and the beard–belly fold (7.4) at about 88–94. Sliding is limited to 6 studs (about 2 points).
   - **Decision:** START V2 with the solo drain at 1.5 per second. This is the existing over-77% fix, pulled forward, because every estimate is already over 77%. With 2 or more players, the drain stays 1 per player.
   - **Estimates with the change:** Rare egg 1 about 71% (the feel Adam played in V1, 66–72%), belly pocket about 78, fold about 80 (about 78 after its small slide).
   - **New triggers, in spec 3 section 5:**
     - Rare egg 1 peaks under 60%: Rare carry goes from ×2.5 to ×3;
     - it peaks over 77% even with this change: the solo drain becomes 1.75.
   - **Also update:**
     - spec 4 Rule 47 (1.5 is the STARTING drain, not "if spec 3's over-80% fix is used");
     - spec 1's worked example in section 2 (re-check it);
     - any nightcap nest that falls under 130 moves up the cap (Rule 54's normal fix).
   - This is a tuning number only, re-checked. Adam is told afterwards.
2. **Spec 5, section 5 "Rank targets when placing", against the sliding rule:** Rare nests are placed to score 60–80, but slide only at 83 or more. Fix: a Rare nest slides when it scores **over 80**.
3. **Spec 1, Rule 17 and section 6 "A new player passes 85%":** the bubble words (about 9 px) and the snort (about 20 px) can't reach the gate as "still to test".
   - Build these starting values: a fixed-size phone bubble about 120 × 40 px with 14 px words, and 20 puffs per snort.
   - Add a Play check on all 8 gardens.
   - Trigger: words still under 12 px means a bigger bubble.

game_creator will fix "his arm twitches" in its idea file (lines 215 and 424) after Gate 3.

## game_creator: which nests spec 3's fairness checks use (answer to designer item 10)
Spec 3 drops "Rare egg 2" and "Rare eggs 3 and 4" and points to Rule 73 (Every rank is fair from every way up). It keeps two hard rules:
- **Rare egg 1:** a solo walking heist peaks at 60–80% through every way up.
- **Every Rare nest:** no solo walking heist wakes him through any way up.

Epic and Legendary are compared per rank, on the meter replayed without its 100 cap. In Check A1 and the bot walk, "Rare egg 2" becomes the beard–belly fold (the highest-scoring Rare nest), and "Rare 3 and 4" becomes the Epic cuff front pocket.
