# Spec list: Climb the Sleeping Giant

V1 of the game (see `docs/ideas/climb-the-sleeping-giant.md`, "V1 gameplay") is split into small specs. They are built one at a time, in this order. The first one is the core heist, so something fun is playable early.

V2, the "Heist update", improves the core heist after Adam's first playtest. It is built after spec 1 and before spec 2. It is a folder of small specs with its own map: `docs/specs/v2/index.md`.

Each spec has at most 15 rules. Status words:

| Status | Means |
|---|---|
| `todo` | Not written yet |
| `draft` | Being written |
| `in review` | Written; `game_creator` and `designer` are checking it |
| `approved` | Adam approved it (Gate 3) |
| `built` | The code is done |
| `reviewed` | `product` played and reviewed the build |

| Order | Spec | What it covers | Status |
|---|---|---|---|
| 1 | Core heist | The valley and the sleeping giant. Sneak onto him, grab a Common, Uncommon or Rare egg, carry it home through your Safe Gate. The shared sleep meter, Tiptoe, his warnings, and the wake-up (bounce-off, blame banner, hand slams, Heavy Sleep). File: `core-heist.md`. | `reviewed` |
| V2 | Heist update | New-player safety, stuck safety, random gardens and four ways up, egg ranks and nests, a thrilling wake-up, and the music and sound effects. Seven small specs, listed in `v2/index.md`. | `approved` |
| 2 | Hatching and pets | Eggs at home go into the incubator, wobble, crack and pop into a pet. First egg hatches in 3 seconds. Sizes (Big, Huge) and Golden. Pets sit on pads; one pet can follow you. A guaranteed Rare egg for every new player. | `todo` |
| 3 | Cash and saving | Pets earn cash into the cash bin; walk over it to collect. Cash and income on screen. Your eggs, pets and cash are saved. Offline cash for up to 8 hours and the welcome-back pile. | `todo` |
| 4 | Upgrades | The Upgrade menu: Quiet Shoes, Fast Legs, Strong Back, More Incubators, More Pet Pads. (The Epic and Legendary eggs moved to V2, `v2/egg-nests-and-climbing.md`.) | `todo` |
| 5 | The Index | The collection book: silhouettes of missing pets, hatch odds shown, +5% cash for a full rarity page. | `todo` |
| 6 | Deep Sleep and Team Eggs | The server event every 10 minutes with its countdown, the Dream Egg on his nose, and the Team Egg that needs 2 players. | `todo` |
| 7 | Friends | Friend Boost, and the invite reward (a free Rare egg for both friends). | `todo` |
| 8 | Daily rewards | The 7-day login streak with a gift each day. | `todo` |
| 9 | Shop and Robux | The Shop: game passes (2x Cash, Fast Hatch, VIP, +4 Pet Pads) and repeatable buys (Lullaby, Starter Pack, cash packs). | `todo` |
| 10 | Launch polish | A tiptoe walking animation, a speed check on real phones, and the store page (icon, thumbnails, description), the Play try at the 7 rare stuck spots that V2 didn't reach (Rule 22: What counts as stuck), and the beard wedge fix (V2 stuck safety's one stuck spot left to the rescue for now, Rule 22: What counts as stuck). A death on the giant while he's asleep keeps the egg and puts the player back on their last safe spot (moved from V2 stuck safety, Rule 25: Reset on the giant takes you back), built in the same task as the kill floor. Measure it in Play before the first fix: in V2, the new body landed at home every time, and the likely cause is that the player's own device runs the new body's physics and undoes a big move made just after the spawn (code_lead, `work/t13/codelead-6c.md`, cause (e)), which unit tests can't show. The music and sound effects moved to V2 (`v2/audio.md`). | `todo` |

## Notes for the next product agent

The core heist's build notes (changes made during the build and why, and what its build review covered) are past notes, kept in [history/core-heist-build-notes.md](history/core-heist-build-notes.md).

### Notes for later specs

| Spec | Note |
|---|---|
| 2: Hatching and pets | Moves the banked eggs (on the pet pads, then in the two front rows) into the incubators. Brings back the dome eggs and hatch timers that spec 1 hid. Pets replace the eggs on the pads. Adds the guaranteed Rare for new players. |
| 3: Cash and saving | In spec 1, banked eggs are lost when a player leaves. Saving starts here. Brings back the "+$/s" tags and coin piles that spec 1 hid. |
| 4: Upgrades and the high climb | Epic eggs now wait in the pockets on his white cuffs (V2 spec 5, Rule 71: How many eggs and nests), so there is no Epic beard egg. Any new nest this spec adds on him keeps V2 spec 5's spacing from every other nest, including Rare_4 (top of its spot at (2.5, 60.9, -30.5)), and stays away from his eyes, where a purple egg reads as a bruise. Strong Back reduces the carry slowdown (Uncommon 5%, Rare 10%). Brings back Plot_4's second incubator (Incubator2) with More Incubators. Beard and nightcap thuds are already set in spec 1 (40 and 60). Check that no guard slab lets players skip the cap ladder to the Legendary egg. |
| 6: Deep Sleep and Team Eggs | The Dream Egg sits on the nose pad (top at 100.2 studs high). The Team Egg model isn't made yet (its prompt is in `art-list.md`). |
| 9: Shop and Robux | The Lullaby button shows on phones only at 85% or more, or while he's awake. The core heist must stay fun without it. |
| 10: Launch polish | Check speed on a real phone (the scene has 5,839 parts). |
| V2: Audio | The sound list is in `core-heist.md`, section 11. It moved from spec 10 to V2 (`v2/audio.md`). |
