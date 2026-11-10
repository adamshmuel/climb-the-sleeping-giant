# Style guide: V2 additions

V2 adds only what is written here. Everything else in `docs/design/v1/style-guide.md` still applies.

This file is the index. The guide is split into one file per spec, in `docs/design/v2/style-guide/`. An agent working on one spec reads this index and that spec's files only.

## Files by spec

| Spec | File | What it holds |
|---|---|---|
| 1: New-player safety | [`style-guide/warning-85.md`](style-guide/warning-85.md) | The 85% warning without the arm twitch: the snort, the moved bubble, their tested values, the eyelids |
| 1: New-player safety | [`style-guide/egg-ranks.md`](style-guide/egg-ranks.md), "Your own carried egg never hides you" | The carried egg fading for its carrier |
| 2: Stuck safety | [`style-guide/rescue-puff.md`](style-guide/rescue-puff.md) | The rescue puff |
| 3: Gardens and ways up | [`style-guide/ways-up.md`](style-guide/ways-up.md) | Ladders, planks, the lap landing, ramps, footprints on a ladder, the fork |
| 4: Egg reachability | [`style-guide/egg-ranks.md`](style-guide/egg-ranks.md) | Rank colours and placement, the rank glow, beams |
| 5: Egg nests and the seam | [`style-guide/nests-map.md`](style-guide/nests-map.md) | How to read the map, the seam, the 38 nests |
| 5: Egg nests and the seam | [`style-guide/nests-pockets.md`](style-guide/nests-pockets.md) | The Epic cuff pockets, the Rare belly pockets, the lap fold and knee pocket |
| 5: Egg nests and the seam | [`style-guide/nests-art.md`](style-guide/nests-art.md) | The nest art, the refill pop, the slide tip, the eye limit, the belly top |
| 6: Wake-up | [`style-guide/wake-up.md`](style-guide/wake-up.md) | His face, the hunt screen, the bonk, the flower shake |
| 7: Audio | [`style-guide/audio.md`](style-guide/audio.md) | The music button, sound and sight together |
| 1: Core heist, Rule 1 (plan 3 Task 8f) | [`style-guide/meter-zs.md`](style-guide/meter-zs.md) | The Z Z Z on the sleep meter: the "he's asleep" sign from the gardens |

Not reference (kept in their own files):
- [`open-checks.md`](open-checks.md): Play checks still to do.
- [`style-guide-history.md`](style-guide-history.md): the old "Queued for the next Studio session" list, word for word.

Build check (scores next to the top games):
- [`build-check-current.md`](build-check-current.md): the current record, one line per image, latest only, grouped by spec.
- [`build-check.md`](build-check.md): the full dated session log, word for word (history).

## Where each old section went

Other documents point to sections by name, for example `style-guide.md`, "The wake-up". Every old section and named part is listed here, so each name still leads to its text in one step.

| Section or named part | File |
|---|---|
| The rescue puff | `style-guide/rescue-puff.md` |
| Ways up; Footprints on a ladder; The plank and the fork; Spawn view; Landing spots | `style-guide/ways-up.md` |
| Egg ranks; Egg ranks: values checked in the mockups (2026-10-14); The rank glow; Beams from eggs on his body; Beams on his body hide up close; Your own carried egg never hides you; Tried second and dropped (the stronger beam) | `style-guide/egg-ranks.md` |
| The wake-up; His face wakes; The screen while he hunts; Red edges; "RUN HOME!"; Egg words near "RUN HOME!"; Wake banner; The bonk; The fist on your own screen; The world reacts to a slam; Flower shake | `style-guide/wake-up.md` |
| The 85% warning without the arm twitch (changes V1); The 85% warning: tested values (2026-10-19); The bubble; The snort; Bubble limits; Can anyone stand on his eyelids? | `style-guide/warning-85.md` |
| Nests (V2 spec 5: Egg nests and the seam); How to read it; The seam: where walking ends; Invisible fixes; How the seam looks; Common: 16 meadow nests, 2 per garden; On him: 22 nests; Out of the map | `style-guide/nests-map.md` |
| The Epic cuff pockets; Build 1 and Build 2; When he's awake; The new Rare pockets; Plan B check; The lap fold and the knee pocket | `style-guide/nests-pockets.md` |
| The nest art (made 2026-10-19); The refill pop; The slide tip; Eye limit: what the belly top can hold; Belly top and the walk layer; Studio markers (`NestMarkers`) | `style-guide/nests-art.md` |
| The music button; Sound and sight together | `style-guide/audio.md` |
| Queued for the next Studio session | `style-guide-history.md` (done items and the original list); the open Play checks in `open-checks.md` |

Paths inside the split files (`mockups/...`, `art-list.md`) mean the ones in `docs/design/v2/`.
