# Owner decisions for spec 1, new-player safety

## designer: job 5 (item 13, the 85% warning) done, 2026-10-19
Made: `view-warning85-g1` to `-g8`, `view-phone-warning85-g1` to `-g8`, `warning85-hud.html`, `warning85-desktop.png` and `warning85-phone.png` (garden 1). All 4/4/4/4 (plus Buttons 4). Tested values are in `docs/design/v2/style-guide.md`, "The 85% warning: tested values (2026-10-19)".

**Tests:**
- **Fixed-size phone bubble, 120 × 40 px, font size 14: passes from all 8 gardens.** Its offset height moved from 2 to −3 (5 studs down), because the taller bubble touched the meter from gardens 3 and 4. The closest gaps are 7 px below the meter and 18 px to his eyes (garden 4).
- **Snort: both suggested fixes failed** (20 puffs: still one 18 px puff; 2 studs out: no change). The old emitter floats about 12 studs in front of his face, at the Z Z Z spot.
- **Snort fix, tested:** a new emitter at his nose tip (0, 89, −14). Two bursts of 20 puffs, 0.5 s apart. Result: a white cloud about 25–30 px wide on the phone from all 8 gardens, not hiding his eyes.

**For product (spec 1, `new-player-safety.md`):**
1. Section 5, "The 85% snort" row: the starting value becomes "two bursts of 20 puffs from a snort emitter at his nose tip (style guide, tested values)". Remove the trigger "puffs start 2 studs out": it was tested and does nothing.
2. Section 5, bubble row: 120 × 40 px and 14 px words are tested and pass from all 8 gardens. Add the offset height −3 (the "move down 1 stud" fix is already used). Say "words 12 px" means font size; the letters themselves are 8–11 px.
3. Section 6: the paragraph "Today… about 9 px… condition 4 fails" is out of date. In "A new player passes 85%" and "The free save", item 13 is Made; point to the files above.
4. Product decides: on a computer, the studs-sized bubble wraps onto two lines. designer suggests a fixed 170 × 52 px bubble with 20 px words, to match the phone (not built).

**Not tested (no Play):** the bubble's pop, the bubble switching sides as the camera turns, the snort's timing in the real warning, the belly-path view.
**In Studio (`Mockup_Warning85`), kept:** `SnortNose` with `SnortPuff`, the old unused `SnortEmitter`, the bubble with offset (14, −3, 2), and the helper `Shoot85`.
