# V2 specs: Heist update

V2 improves the core heist (spec 1, `docs/specs/core-heist.md`) after Adam's first playtest on 2026-10-14. It is built after spec 1 and before spec 2 (Hatching and pets). The owners' input is in `research/`: `gameplay.md` (game_creator), `look.md` (designer), `tech.md` (code_lead) and `stuck.md` (stuck research).

The specs are written one at a time, in build order. Each has at most 15 rules.

| Order | File | What it covers | Status |
|---|---|---|---|
| 1 | `new-player-safety.md` | Rule 11 becomes "one free save": a new player's first would-be wake drops the meter to 70 and replays the 85% warning, then the safety is used up. A player stops being new with their first Rare egg home | `approved` |
| 2 | `stuck-safety.md` | Stop players getting stuck inside the giant: one collision source, an automatic stuck scan, a test walk of every way up, and a way out for a stuck player | `approved` |
| 3 | `gardens-and-ways-up.md` | Random gardens (middle four first), six ways up the giant that all reach the belly through one lap landing and its two belly ramps, rail guards on the planks, and fair noise on every way up | `approved` |
| 4 | `egg-reachability.md` | The reachability check: a difficulty score for every nest, which sets its rank, its egg colour and its hatch-odds order | `approved` |
| 5 | `egg-nests-and-climbing.md` | 38 hand-placed nests, random refills within a rank, Epic eggs in pockets on his white cuffs, walking anywhere on his belly, sides and arms down to a stitched seam, and nothing players stand on moves while he sleeps (climbable patches and buttons dropped, Adam 2026-10-14) | `approved` |
| 6 | `wake-up.md` | A thrilling wake-up, even solo: he hunts everyone outside a garden, the harmless "bonk", faster slams, a bigger shake and "RUN HOME!" | `approved` |
| 7 | `audio.md` | The music and sound effects, moved here from spec 10 (Launch polish): calm music that follows the meter, a chase tune, every sound effect from Roblox's free library (each one picked, with its loudness), and a music-note button | `approved` |

Status words are the same as in `docs/specs/index.md`.

## Rule numbers

- V1's rules are Rule 1 to Rule 15 in `core-heist.md`.
- A V2 spec that changes a V1 rule keeps that rule's number, and says which V1 rule it replaces.
- A brand-new V2 rule takes the next free number, from Rule 16 up, so no two rules ever share a number.
- **Next free number: Rule 101.** (Spec 2, `stuck-safety.md`, uses Rules 20 to 33. Spec 3, `gardens-and-ways-up.md`, uses Rules 34 to 45. Spec 4, `egg-reachability.md`, uses Rules 46 to 59. Spec 6, `wake-up.md`, uses Rules 60 to 69. Spec 5, `egg-nests-and-climbing.md`, uses Rules 70 to 84, with 81 and 83 dropped and left unused, plus Rule 100. Spec 7, `audio.md`, uses Rules 85 to 99.) Each spec updates this line when it adds rules.
