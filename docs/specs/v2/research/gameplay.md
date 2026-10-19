# V2 input: gameplay (game_creator, 2026-10-14)

game_creator's proposals after Adam's first playtest. Live data was fetched 2026-10-14 at 07:58 UTC. These are proposals, not an approved spec: product turns them into the V2 specs.

Words used here:
- **Stud:** Roblox's unit of length. A player is about 5 studs tall.
- **Sleep meter:** the shared bar that fills with noise. At 100% the giant wakes.
- **Carrier:** a player carrying an egg.

**New rival:** "Climb For Animals Eggs" (made 2026-09-06) had 25,343 players and 99% likes. Kids climb plain yellow ladders up to eggs. That proves kids like climbing for eggs, but "climb" alone isn't special any more. Our difference is the giant who can wake up.

## A. Gardens and ways up

**The real problem isn't which garden you get. It's how far each garden is from the only way onto the belly.**
- From garden 4's spawn, the foot of the left ramp is about 26 studs away.
- From garden 8 it's about 190 studs: roughly 12 extra seconds each way.
- In a race for the Rare eggs, garden 4 wins every time. Random gardens alone only change who loses.

| Decision | Details |
|---|---|
| **Random gardens, in two groups** | A new player gets a random free garden from the middle four (3, 4, 5, 6). Once those are taken, a random one from 1, 2, 7, 8. A solo player gets one of four, so it varies, and the first players still spawn facing his face (designer's point). |
| **Six ways up instead of one** | Both front ramps reach the belly: a plank between his legs joins the right boot to the belly. A rope ladder on the outer side of each boot serves gardens 3 and 6. A rope ladder up each of his sides serves gardens 1–2 and 7–8. Designer picks the exact spots. |
| **Not Adam's four boot ladders as they are** | Ladders on the inner sides of the boots would serve gardens 4 and 5, which already have the ramps. So two of the four move to his sides. |
| **Fairness rule** | Every spawn is at most about 4 seconds' walk from a way up. Every way up costs the same noise to the same egg, give or take 5 points. Climbing a ladder is 70% of walking speed (official Roblox docs), so a ladder comes out about 6 points quieter than the ramp. Ladder steps therefore count ×1.2 noise. These numbers are game_creator's own maths, not measured: the path check confirms them. |

- **Evidence:** spawn and ramp positions read from the running game. No source shows whether players prefer random or first-free gardens; forum threads show both are common.
- **Changes:** Rule 15 (The climb needs no jump), how gardens are handed out, and the world.
- **Money or new features:** none.

## B. Random eggs, rarity and climbing

| Topic | Decision |
|---|---|
| **How random spawns work** | Eggs only appear on hand-placed nests, never at a truly random spot. Each rarity keeps its number of eggs (Meadow 8, Boots 4, Belly 4). When an egg refills, it picks a random free nest of its rarity. It never picks the nest it just left, never one within 8 studs of another egg, and never one within 15 studs of a player. Each garden has 2 meadow nests near its bridge, so the first egg still comes within 15 seconds. |
| **What makes a spot "logical"** | All five must be true: a nest the player can see (designer's spots: boot laces, his palm, a pyjama pocket, between buttons, the beard–belly fold, a bird's nest in the beard, the nightcap pom-pom); reachable with no jump; flat enough to stand beside; never on his face or eyes; nests spread over both halves of the belly, not in a line. |
| **Rarity follows difficulty** | A spot's rarity comes from the quietest walk there and back while carrying the egg: how high a solo player's meter peaks if they never use Tiptoe. **Uncommon:** under 40%. **Rare:** 40–85% (you get the scare, he doesn't wake). **Epic:** 85–130% (you must tiptoe part of the way). **Legendary:** over 130% (you must tiptoe most of the way). In plain words, rarity means "how much tiptoeing it needs". These are starting values: if most Epic heists end in a wake-up, the Epic band moves up. |
| **Climb anywhere** | The gentle top of the belly can be walked anywhere (a smooth invisible layer over the bumps). On the steep sides you can climb only the marked parts: stitched patches and big buttons, with real Roblox climbing ladders hidden under them. Plain pyjama stays slippery. Steep shortcuts are shorter, so quieter, but a slip off them is a loud thud: risk against reward. |
| **Keeping it clear** | One look rule: patches and buttons mean climb. The footprints always show the quietest route. The first time a player slides off plain pyjama, a tip says "Climb the patches and buttons!". Longer routes wake him on their own, because every second on him makes noise. No new grip meter: the sleep meter stays the only meter. |
| **What the path check must measure** | For every nest: reachable with no jump (if not, the nest stays off); the quietest round-trip noise, which sets its rarity; the walk time from each garden's spawn; enough flat room to stand; and no way up more than 5 points quieter than another. Rerun after every world change. |

- **Evidence:**
  - Steal An Egg: eggs reset every 5 minutes, the rare ones roll at random, and a server-wide notice names the rarest ones and where they are ([eldorado](https://www.eldorado.gg/blog/?p=20045)).
  - Don't Steal the Bobo: rare ones in the middle, common ones at the edges ([rowatcher](https://rowatcher.com/games/8791358380/don-t-steal-the-bobo)).
  - Break and Steal an Egg: many eggs on little nests across its field (`references/top-games/break-and-steal-an-egg/shot-06.jpg`).
  - Shadow of the Colossus: you can climb anything you can hold onto, like fur or ledges ([review](https://taw.duke4.net/?p=269)).
  - The climbing egg games use plain ladders (their store thumbnails).
- **Changes:** Rule 3 (Eggs wait in three zones), Rule 15 (The climb needs no jump) and the noise numbers.
- **Money:** none. The walk-anywhere belly is the biggest build item.

**Added by Adam after this round:** the path check becomes a reachability algorithm. Its scores set the ranks. The number of egg colours equals the number of ranks, and a harder rank gives better pet odds (see the V2 plan).

## C. A wake-up that's thrilling solo

**Why Adam felt "nothing happened":**
- Slams only aim at carriers, so a solo player without an egg is never targeted.
- The screen shake is tiny (0.5 studs).
- There is no sound yet.

| Option | What happens | Evidence |
|---|---|---|
| **1. He hunts you home (game_creator's pick)** | Slams aim at every player outside a garden, carriers first. A carrier who is hit loses the egg, as today. A player without an egg gets a harmless "bonk": a tumble and a star puff, nothing lost. The gap between slams shrinks from 2.5 to 2 seconds over the 15 seconds. Each red circle still gives the same 1.5 seconds' warning. | Steal An Egg and Break and Steal: a guard chases you, with a "RUN!" banner. 99 Nights: the deer chases you and speeds up the longer it chases ([Sportskeeda](https://www.sportskeeda.com/roblox-news/can-kill-deer-99-nights-forest), [Deltia's](https://deltiasgaming.com/?p=359038)). |
| 2. His searching eyes | A big gaze sweeps the meadow. Anyone it sees gets slammed. You hide behind his teacup, his sock or the mushrooms. | Doors (hide from monsters), 99 Nights (break line of sight), Don't Let Him In. A bigger build. |
| 3. Escape run | Slams land in a row behind you as you run home. | The Seek chase in Doors ([guide](https://dungeonpath.com/posts/doors/seek-chase-complete-guide/)). Scripted for one player; fits our open valley badly. |

- **In every option:** sound moves forward from spec 10 (the roar, chase music, slam thud, "boing"), plus designer's look (see `look.md`).
- **Designer's near-miss question:** no fake near-miss. With option 1 the fist really aims at the player, and a hit is a harmless bonk.
- **Changes:** Rule 12 (Waking bounces everyone off), Rule 13 (Hand slams hunt egg carriers), and the sound moving into V2.
- **Money:** none.

## D. Where pets are kept (for spec 2, not V2)

| Decision | Details |
|---|---|
| Pads = pets that earn | Start at 6, up to 16 with the in-game cash upgrade. |
| New: Pet Bag | Every pet not on a pad goes into the bag. Any number of pets, identical pets stack, bag space is never sold. |
| New: "Equip Best" button | Puts your best earners on your pads with one tap. |
| New: Release | Release a spare pet for coins, after a confirm step (spec 3: it pays cash). |
| Eggs waiting to hatch | Stack in an Egg Basket with no limit, so a heist is never blocked. |

- **Evidence:** Steal An Egg ("Equip Best", pen upgrades), Pet Simulator 99 (stacking, "+15 Pets" for 375 Robux), Grow a Garden (60-pet bag), Adopt Me (Backpack, Storage, Releaser, "+1 Pet Pen Slot" for 295 Robux).
- **For Adam, when spec 2 is written:** the money question (does "+4 Pet Pads", 129 Robux, go past 16 to 20? game_creator recommends yes) and the new features (Pet Bag, Equip Best, Release).

## What game_creator did not check
- It didn't play the game this round (Studio was busy).
- No data on whether players prefer random or first-free gardens.
- No gameplay screenshots of Climb For Animals Eggs, only its store pictures and numbers.
- The ladder noise numbers are its own maths, not measured.
- Climbing with the phone thumbstick is still untested.
