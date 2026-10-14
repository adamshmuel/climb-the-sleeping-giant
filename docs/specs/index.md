# Spec list: Climb the Sleeping Giant

V1 of the game (see `docs/ideas/climb-the-sleeping-giant.md`, "V1 gameplay") is split into small specs. They are built one at a time, in this order. The first one is the core heist, so something fun is playable early.

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
| 2 | Hatching and pets | Eggs at home go into the incubator, wobble, crack and pop into a pet. First egg hatches in 3 seconds. Sizes (Big, Huge) and Golden. Pets sit on pads; one pet can follow you. A guaranteed Rare egg for every new player. | `todo` |
| 3 | Cash and saving | Pets earn cash into the cash bin; walk over it to collect. Cash and income on screen. Your eggs, pets and cash are saved. Offline cash for up to 8 hours and the welcome-back pile. | `todo` |
| 4 | Upgrades and the high climb | The Upgrade menu: Quiet Shoes, Fast Legs, Strong Back, More Incubators, More Pet Pads. Epic eggs in his beard and the Legendary egg on his nightcap. | `todo` |
| 5 | The Index | The collection book: silhouettes of missing pets, hatch odds shown, +5% cash for a full rarity page. | `todo` |
| 6 | Deep Sleep and Team Eggs | The server event every 10 minutes with its countdown, the Dream Egg on his nose, and the Team Egg that needs 2 players. | `todo` |
| 7 | Friends | Friend Boost, and the invite reward (a free Rare egg for both friends). | `todo` |
| 8 | Daily rewards | The 7-day login streak with a gift each day. | `todo` |
| 9 | Shop and Robux | The Shop: game passes (2x Cash, Fast Hatch, VIP, +4 Pet Pads) and repeatable buys (Lullaby, Starter Pack, cash packs). | `todo` |
| 10 | Launch polish | Music (calm, thinning at 60%, chase tune when he wakes), sound effects (snore loop that stops at 60%, the "Mmm..." mumble, the roar, the bounce-off "boing", the slam thud, the egg-back pop, the cheer when an egg is home, the Heavy Sleep snore), chosen from Roblox's free audio library, a tiptoe walking animation, a speed check on real phones, and the store page (icon, thumbnails, description). | `todo` |

## Notes for the next product agent

### Core heist: changes made during the build, and why

The spec already holds each decision. These are the reasons the spec doesn't give.

| Change | Why |
|---|---|
| The empty meadow ring is 85% see-through (the waiting ring is 60%) | designer made the waiting ring fainter (it read as a solid white plate). At the old 70%, empty and waiting would look the same. designer still has to confirm that 85% is visible on a phone. Anything from 80% up keeps a clear step. |
| Eggs 7–12 sit in two rows at the front of the garden, not beside the incubator | Flowers fill the space beside the incubator in all 8 gardens. Moving them was extra world work. |
| Egg spot Common_3 moved to (-54, 2, -86) | From garden 4 its label lined up with Common_4's and read "CommonCommon" |
| The player's slope limit is 70° (Roblox's default is 89°), and the belly path is smoothed to at most 60° | code_lead (Task 8), so players slide off his steep skin. The belly path's length was kept, because a longer path would push the solo Rare heist past 85%. |
| Only the left ramp leads to the belly (Task 23); Rule 15 now says so. Then the meadow became silent (×0, was ×0.5) and the Rare carry became ×2.5 (was ×2) | The right boot top doesn't join the belly path: the ground drops away between his legs. With noise in the meadow, the far gardens' long walk round to the left ramp would have woken him on a Rare_1 heist (about 125% from garden 8). game_creator decided the silent meadow, so the peak (about 66%, at the ramp's foot) is the same from every garden. A join wouldn't help: it would add about 45 studs on the loud boots to skip a silent walk. game_creator's trigger for adding one is in section 5, "Ways up to the belly". |
| Egg spots (Task 16) | Common spots are about a 3-second walk from each spawn spot. Rare_1 to Rare_4 climb the belly path; Rare_4 is at (2.5, 64.5, -29.5). |

All playtest triggers are in the last column of `core-heist.md`, section 5.

### What the core heist build review must cover

In addition to every rule and story check:
- **Guard slabs:** walk every invisible guard slab by hand. Any slab gentler than 70° can be walked up. designer saw a player slide over the forehead guard to the top of the nightcap, skipping the cap ladder.
- **Phone noise (game_creator, after Task 42):** in a server with one player and 2 eggs already home, on the iPhone 14 simulator, with auto-jump left at the game's setting, following the footprints and with no Tiptoe, play 3 Rare_1 heists from garden 1. For each one, report the peak and the time of every leg on the giant (up the ramp, up the belly path, down the belly path, down the ramp), next to Task 41's computer legs.
  - The middle of the 3 peaks is under 60%, and the times on the giant are within 10% of the computer's: the Rare carry becomes ×3. Then re-measure Rare_2 from garden 8. If that wakes him, the solo drain becomes 1.5 per second.
  - The times on the giant are shorter: the walker cut corners. Keep ×2.5, and report which shortcut.
  - Peaks of 60% or more: nothing changes.
- **Phone heist:** one full Rare_1 heist in the phone simulator, with auto-jump left at the game's setting (off). He must not wake from hops the player didn't choose, and no ledge on the route may stop the player.
- **Phone controls:** check the thumbstick and Jump button. The phone simulator stops drawing them once keyboard input is used, so use mouse clicks or touch in the simulator, and say plainly what couldn't be tested.
- **Camera:** check the 36° spawn tilt with a real mouse. Studio's test tools can't drag the camera. At all 8 spawn spots, on computer and phone, the Z Z Z must clear the meter, including during the 60% pulse. The first egg or its footprints must still show above the extra grass. Then walk without touching the camera: it must ease to 15° down over 0.6 s and show the footprints, at every garden. Turn the camera first and then walk: it must not ease.
- **Thuds:** test each case:
  - a jump in place on the belly (+30);
  - a slide off his side into the meadow (+30);
  - a jump from the belly that stops on a boot top (+30 once);
  - walking down the ramp (silent);
  - a jump from the right boot top toward the belly (+20), and a fall into the gap between his legs: the player must be able to walk out to the meadow;
  - the bounce-off (silent).
- **Solo noise:**
  - Check B3 (fair for every garden): with 2 eggs home, walking from Rare_1 must peak between 60% and 80% from gardens 4, 1 and 8, within 5 points of each other; walking from Rare_2 from garden 8 must not wake him; garden 8 to the meadow just beside the ramp's foot (not onto the ramp, whose noise starts about 2.4 studs out on the grass) and back with no egg must leave the meter at 0;
  - walking from Rare_2 must never wake him, from any garden;
  - jumps that start and end in the meadow, and walking in the meadow while carrying, must add nothing;
  - walking from Rare_3 or Rare_4 may wake him.
- **Labels and footprints:**
  - Rare_4's label looked like it sat by his left eye from far below; check it from the boot top;
  - from garden 3, the footprints must lead to the moved Common_3.
- **Crowds:** 8 players on one ladder, and players passing through each other on the route.
- **Test-tool limits found while writing the spec:**
  - Escape can't be pressed, so a stuck character can't be reset;
  - the W key does reach the game;
  - in the phone simulator, the camera undoes any test-script camera aim;
  - mute the sound in every Play session.

### Notes for later specs

| Spec | Note |
|---|---|
| 2: Hatching and pets | Moves the banked eggs (on the pet pads, then in the two front rows) into the incubators. Brings back the dome eggs and hatch timers that spec 1 hid. Pets replace the eggs on the pads. Adds the guaranteed Rare for new players. |
| 3: Cash and saving | In spec 1, banked eggs are lost when a player leaves. Saving starts here. Brings back the "+$/s" tags and coin piles that spec 1 hid. |
| 4: Upgrades and the high climb | The Epic beard egg must sit at least 6 studs from Rare_4 (2.5, 64.5, -29.5). It must also be away from his eyes, where a purple egg reads as a bruise. Strong Back reduces the carry slowdown (Uncommon 5%, Rare 10%). Brings back Plot_4's second incubator (Incubator2) with More Incubators. Beard and nightcap thuds are already set in spec 1 (40 and 60). Check that no guard slab lets players skip the cap ladder to the Legendary egg. |
| 6: Deep Sleep and Team Eggs | The Dream Egg sits on the nose pad (top at 100.2 studs high). The Team Egg model isn't made yet (its prompt is in `art-list.md`). |
| 9: Shop and Robux | The Lullaby button shows on phones only at 85% or more, or while he's awake. The core heist must stay fun without it. |
| 10: Launch polish | The sound list is in `core-heist.md`, section 11. Check speed on a real phone (the scene has 5,839 parts). |
