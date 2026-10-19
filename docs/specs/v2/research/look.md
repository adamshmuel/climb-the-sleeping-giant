# V2 input: look and world (designer, 2026-10-14)

designer's look-side answers after Adam's first playtest. These are proposals, not an approved spec. Gameplay choices belong to game_creator (see `gameplay.md`). Sources are the reference library (`references/top-games/`, last full search 2026-10-11), our V1 mockups (`docs/design/v1/mockups/`), a belly-slope measurement taken in Studio on 2026-10-14, and the web links at the bottom.

## Why the V1 world is the way it is (designer's answers to Adam)
- **Garden 1 is at the far right:** the 8 gardens form a half-ring in front of him. The game hands out the lowest free number, so a solo player always gets garden 1, at one end. Nobody wrote down why. Gardens 4 and 5 see his face from the front; from gardens 1 and 2 his "Mmm... my eggs..." bubble is hidden behind his head.
- **The climb starts only on the egg path:** his real shape is bumpy, and in early tests players sank into his belly. So one safe path was built (a plank ramp, then an invisible walkway), and the rest of him was made too steep on purpose. Measured on 2026-10-14: most of the belly is 45°–80° and bumpy. Players slide off anything steeper than 70°.
- **Belly eggs are in a line:** the walkway runs straight up his belly, and it's the only place to stand, so the eggs line up.

## A. Random gardens, and ladders on the boots
- **Garden order (look):** fill gardens from the middle out (4, 5, 3, 6, 2, 7, 1, 8), so the first players spawn facing his sleeping face. game_creator chose two random groups (middle four first), which keeps this.
- **Boot ladders:** the same rope ladder as on his beard and nightcap, hooked over each boot's rim. One look for "this is a way up", as climbing games do (Uncharted and Tomb Raider mark every climbable ledge the same way). A boot is about 30 studs tall, the beard ladder's size class.
  - Outer sides of the boots face gardens 2–3 and 6–7.
  - Inner sides drop into the gap between his legs, which leads nowhere today. Only add them if a plank also joins the right boot to the belly.
- **Build from:** the existing rope-ladder build (wooden rungs with a hidden climbable `TrussPart` behind them), already proven in Play. No new models.
- **Test in Studio:** one mockup ladder on the outer side of the left boot; climb it with normal controls; the top must land flat on the boot walkway with no jump; screenshot it from gardens 2 and 3.

## B. Logical egg spots, and climbing the belly
- **An egg reads as "placed" when it sits in something.** Steal Animal Egg puts eggs in straw nests (`steal-animal-egg/shot-08.jpg`); Steal An Egg puts them under a guard animal (`steal-an-egg/shot-01.jpg`). So: a small straw nest at every possible spot.
- **Spots that fit the giant, low to high:** boot laces; his resting palm on the grass (seen from gardens 1 and 8, `source/spawn-plot1-zzz-final.png`); a pyjama pocket; between pyjama buttons; the fold where the beard meets the belly; a bird's nest in his beard; the nightcap pom-pom.
- **Higher = rarer** matches our zones already (Drill for Eggs: "deeper = rarer"; Steal An Egg: "farther = rarer").
- **Announcing a rare egg:** Break and Steal shows "Titanic Egg spawns in 24:37" on screen (`break-and-steal-an-egg/shot-04.jpg`). Our Rare eggs already have a light beam that shows from far away.
- **One visible climbing rule:** big pyjama buttons are steps, stitched patches are climbable, plain pyjama is not. This is like Shadow of the Colossus, where the climbable parts of each giant are covered in fur. Buttons are real bumps, so they read as steps on a phone without text. His pyjamas already have sewn-on patches (`view-belly.png`, `concept-valley.png`).
- **A fully walkable belly** with no markings (as in Breath of the Wild) would need a smooth invisible layer over the whole 45°–80° bumpy belly: a bigger build.
- **Build from:** generated button and patch models (for example "giant round pyjama button, 4 holes, toy style", "sewn fabric patch with big cross stitches"), nests from a store or generated model, and an invisible walk piece under each button or patch.
- **Test in Studio:** generate 1 button and 1 patch; place 5 buttons up one side of the belly and walk them on computer and phone; check that small pieces sit flat on his curved belly (large flat pieces float or sink there, as the slam circles did); place 3 nests and check the eggs read from 75 studs away.

## C. A thrilling wake-up (look side)
- **Today:** his eyes swap, his head tips over 0.5 s, his fist goes up, the screen shakes by at most 0.5 studs, and a banner appears.
- **What top games do:** DOORS puts eyes on the walls and floods the hall with red light before its monster Seek chases you (`doors/shot-03.jpg`, `shot-05.jpg` to `shot-07.jpg`). Steal Animal Egg flashes a big red "RUN!!" banner while you carry an egg (`steal-animal-egg/shot-06.jpg`); Break and Steal shows "RUN!" (`break-and-steal-an-egg/shot-06.jpg`). In Bobo, Break and Steal and 99 Nights, the guard or monster visibly chases you.
- **How ours could look, without sound:**
  1. His face is the moment: eyes snap open with a white "!" pop; a round dark open mouth for the roar (spheres, like his eyes); his head tips faster.
  2. A bigger shake: about 1.5–2 studs at the wake, fading out. Each slam shakes your screen more the closer it lands.
  3. A red glow pulses at the screen edges for the 15 seconds. The world stays bright, as the style guide asks.
  4. A big "RUN HOME!" pill at the top for carriers.
  5. The world reacts: birds burst out of the trees, the Z Z Z pop like bubbles, dust puffs off his body, flowers near each slam shake.
- **Build from:** Roblox's own tools. The edge glow is a screen image; birds, dust and Z pops are particle effects; the mouth is spheres. One store or generated bird model.
- **Test in Studio:** shake at 1.5 and 2 studs; the red edge at two strengths on computer and phone (it must not cover his face, the meter or the thumbstick); the mouth from gardens 1, 4 and 8.

## Not checked
- No Studio look on 2026-10-14 (another agent was in Play).
- The boot sides up close, and whether they can take a ladder without clipping.
- Which of his arms faces garden 1 (only his right arm moves).
- No new models generated yet.
- The web sources are blogs, wikis and guides, not studies.

## Sources
- [80.lv: environment language for video games](https://80.lv/articles/defining-environment-language-for-video-games/)
- [Feedme Design: beyond the yellow paint](https://feedme.design/the-role-of-visual-cues-in-game-design-beyond-the-yellow-paint)
- [ModDB: affordances in level design](https://www.moddb.com/games/wayfarers-call-of-osiris/news/level-design-player-navigation-with-an-aid-of-affordances-and-obstructions)
- [Team Ico Wiki: Colossus I](https://teamico.fandom.com/wiki/Colossus_I)
- [GameSpot: Shadow of the Colossus walkthrough](https://gamespot.com/articles/shadow-of-the-colossus-walkthrough/1100-6135919/)
- [DroidGamers: DOORS Seek chase](https://www.droidgamers.com/guides/doors-floor-2-seek-chase-guide/)
- [Gamer Journalist: beating Seek in DOORS](https://gamerjournalist.com/how-to-beat-seek-in-roblox-doors/)
