# Build check: Steal the Giant's Eggs

Every mockup image, what it is made of, how hard it is for a beginner to build, and how it scores next to real screenshots of top games. Checked 2026-10-11, and checked again on 2026-10-12 after game_creator's review (round 1). Every image below was retaken or re-rendered in that second check.

## How the scoring works

Each image is scored 1 (poor) to 5 (best) on five things, next to real gameplay screenshots from `references/top-games/`:

| Score | Means |
|---|---|
| **World** | How full and detailed the place looks |
| **Light** | Colours and lighting |
| **Life** | Signs of life: players, pets, things moving or glowing |
| **Buttons** | How finished the screen buttons look |
| **Phone** | How easy it is to read on a phone screen |

### The top-game screenshots we compared with

| Screenshot | World | Light | Life | Buttons | Phone |
|---|---|---|---|---|---|
| `adopt-me/shot-01.jpg` (town with shops) | 4 | 4 | 5 | 4 | 3 (chat and name tags cover the middle) |
| `adopt-me/shot-05.jpg` (house street) | 3 | 4 | 3 | 4 | 4 |
| `ride-a-pet/shot-03.jpg` (forest ranch) | 4 | 4 | 4 | 4 | 4 |
| `ride-a-pet/shot-04.jpg` (golem pen) | 4 | 4 | 4 | 4 | 4 |
| `steal-an-egg/shot-08.jpg` (No. 1 game, base) | 2 | 3 | 4 | 4 | 4 |
| `dont-steal-the-bobo/shot-03.jpg` (sleeping guard game) | 2 | 3 | 3 | 4 | 3 |
| **Best of the top games** | **4** | **4** | **5** | **4** | **4** |

For the icon and thumbnails we compared with the store art of `steal-an-egg`, `adopt-me`, `dont-steal-the-bobo`, `ride-a-pet` and `break-and-steal-an-egg` (`store-icon.png`, `store-thumb.png`). Those are polished posed renders: **5** on every point.

## Images

Difficulty is for a beginner building it in Studio: **easy**, **medium** or **hard**.

### Screen mockups (real Play screenshots with the screen buttons on top)

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `hud-desktop-spawn.png`, `hud-phone-spawn.png` | First second in the game: at your gate in real Play (spawn facing the giant, one camera tilt), his sleeping face with closed lids in view, boot ramp, footprints to the first egg | Giant + sleeping lids, Common eggs, teacup, sock, candle, bridge, boot ramp, ladders, footprints, store trees and flowers | Medium | 5 | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5 |
| `hud-desktop-belly.png`, `hud-phone-belly.png` | Sneaking on his belly next to a Rare egg, sleep meter at 64%, Tiptoe on, "Hold to Grab" | Giant + lids, belly path, beard ladder, Rare and Epic eggs | Hard (walk surfaces) | 4 | 4 | 4 | 4 | 4 | No |
| `hud-desktop-wakeup.png`, `hud-phone-wakeup.png` | He woke up: open eyes, raised fist, red slam circle, players running with eggs (run animation), blame banner. On the phone the Lullaby appears and the banner is small, under the meter. | Giant + awake eyes, raised arm, slam circle | **Hard** (the moving parts) | 5 | 4 | 4 | 4 | 4 | Life: 4 against 5 |
| `hud-desktop-deepsleep.png`, `hud-phone-deepsleep.png` | Deep Sleep: the Dream Egg glows on his nose, players race up the belly and ladder | Giant, Dream Egg, other players with pets | Medium | 4 | 4 | 4 | 4 | 4 | Life: 4 against 5 |
| `hud-desktop-base.png`, `hud-phone-base.png` | Your garden, framed closer: stepping-stone path, hedges, flower border, pets on pads earning cash, eggs hatching, "Hatched!" message | Safe Gate, picket fence, pet pads, incubators, pets, store chest, stones and bushes | Medium | 4 | 4 | 4 | 4 | 4 | Life: 4 against 5 |

All 10 screen mockups now include the **Invite** and **Daily** buttons in the menu.

### Core heist screen (round 3, 2026-10-12, for the core heist spec)

These show only the core heist controls: the sleep meter, Tiptoe, the carry pill and short messages. They leave out the menu grid, cash, the Deep Sleep countdown and the Lullaby, because those come in later specs. Made from `mockups/core-hud.html` over real Play screenshots (`view-carry`, `view-warning`, `view-heavysleep`, `view-caught`, `view-safehome`, each with a phone version).

| Image | What it shows | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|
| `core-desktop-carry.png`, `core-phone-carry.png` | Carrying a Rare egg down the boot ramp while he sleeps; carry pill "Rare egg! Get it home"; footprints lead to your garden | Medium | 5 | 4 | 4 | 4 | 4 | Life: 4 against 5 |
| `core-desktop-warning.png`, `core-phone-warning.png` | **85%**: orange meter, 😟 "He's waking up! Tiptoe!", Tiptoe glowing orange, tip "Stand still or tiptoe!". On him: Zzz off, "Mmm... my eggs..." bubble, right arm twitched up 5° | Medium | 4 | 4 | 4 | 4 | 4 | Life: 4 against 5 |
| `core-desktop-heavysleep.png`, `core-phone-heavysleep.png` | **Heavy Sleep** after a wake-up: locked blue striped meter "Heavy Sleep · safe for 0:42", giant Zzz, players climbing back on | Medium | 5 | 4 | 4 | 4 | 4 | Life: 4 against 5 |
| `core-desktop-caught.png`, `core-phone-caught.png` | **Caught** by a slam: back at your spot outside the gate with a star puff, empty-handed, he is still awake behind you; "Caught! The egg went back. You lost nothing else." | Hard (the slam itself) | 5 | 4 | 4 | 4 | 4 | Life: 4 against 5 |
| `core-desktop-safehome.png`, `core-phone-safehome.png` | **Egg safe at home**: walking through the Safe Gate with the Rare egg, confetti bursting from the arch, green "Safe! Rare egg is home" | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4 against 5 |

Notes:
- In the Heavy Sleep shot, the top of the big Zzz goes under the sleep meter. His face stays clear.
- In the caught and safe-home shots, the star puff and the confetti were burst once, just before each capture. In the game they fade after about 3 seconds.

### View shots (real Play camera, no screen buttons)

| Image | What it shows | Difficulty | World | Light | Life |
|---|---|---|---|---|---|
| `view-spawn.png`, `view-phone-spawn.png` | From your gate, taken in real Play with the default camera plus the one-time tilt (see the style guide, "First view") | Medium | 5 | 4 | 4 |
| `view-meadow.png` | Next to a Common egg at his boot; the "Common" label stays small up close | Easy | 5 | 4 | 4 |
| `view-boots.png` | On top of his boots after the boot ramp, Uncommon egg | Hard (walk surfaces) | 4 | 4 | 4 |
| `view-belly.png`, `view-phone-belly.png` | On his belly path: Rare egg, Epic egg in the beard, ladder, closed lids | Hard (walk surfaces) | 4 | 4 | 4 |
| `view-beard.png` | Climbing the rope ladder up his beard, closed lids up close | Hard (walk surfaces) | 4 | 4 | 3 |
| `view-nightcap.png` | On his nightcap, Legendary egg, the whole valley below | Hard (walking surfaces) | 5 | 4 | 3 |
| `view-wakeup.png`, `view-phone-wakeup.png` | Wake-up from the meadow | Hard | 5 | 4 | 4 |
| `view-deepsleep.png`, `view-phone-deepsleep.png` | Deep Sleep race | Medium | 4 | 4 | 4 |
| `view-base.png`, `view-phone-base.png` | Inside your garden | Medium | 4 | 4 | 4 |

### Concept, icon and thumbnails

| Image | What it shows | Difficulty | Score | Top games | Below? |
|---|---|---|---|---|---|
| `concept-valley.png` | The whole valley: giant, stream, bridges, gardens, giant objects, hills of trees | Medium | World 5, Light 4, Life 3 | 4 / 4 / 5 | Life (people are tiny at this distance) |
| `concept-escape.png` | A player holding a Legendary egg up on his belly while he sleeps (Zzz) | Medium | World 4, Light 4, Life 4 | 4 / 4 / 5 | Life |
| `icon.png` | His sleeping face fills the picture (closed lids, red nose, big "Zzz"); a tiny thief on his forehead holds a gold egg up (cheer animation). Shot in Play on a square 1024×1024 screen. Checked at 150×150 next to the Steal An Egg, Don't Steal the Bobo and Adopt Me icons: "sleeping giant, tiny thief" reads at once. | Easy | **4** | 5 | **Yes, by 1** |
| `thumbnail-climb.png` | "DON'T WAKE HIM!" He is asleep with Zzz; the thief holds a Legendary egg up on his belly. "Legendary egg!" tag next to the thief; nothing at the bottom edge. | Easy | **4** | 5 | **Yes, by 1** |
| `thumbnail-wakeup.png` | "HE'S AWAKE!" Eyes open, fist up, red slam circle, three players running with eggs (run animation) | Easy | **4** | 5 | **Yes, by 1** |

## What is still below the top games, and why

I improved each of these at least 3 times. These are the blockers:

1. **Life (4 against Adopt Me's 5).**
   - Tries: added other players (twice), pets following them, wandering pets, drifting petals and pollen, sparkles, floating Z Z Z.
   - Blocker: Adopt Me's screens are packed with many players and name tags. Our idea caps a server at 8 players, and a still picture can't show movement.
   - In the real game: pets that follow players, sparkles and snore puffs will move. That should close most of the gap.
2. **Icon (4 against 5, up from 3).**
   - Round 2 tries: 5 Play shots. The avatar is now posed with Roblox's cheer animation, holding the egg up. The shot uses a square Play screen, so his whole face fits, and there's a big "Zzz".
   - Blocker: the top icons are posed renders with a huge character close to the camera. In ours the thief must stay small, because the giant's size is the joke.
3. **Thumbnails (4 against 5).**
   - Round 2 tries: 3 new Play shots, with poses from the run and cheer animations.
   - Blocker: the same as the icon. They're clear and honest, but less glossy than renders.

## What the real game can't match, and how it will look instead

| In the mockup | Problem | In the real game |
|---|---|---|
| The giant's body is walkable | The generated model's collision shape is rougher than what you see. In round 1 the avatar sank inside his belly. | **Built and tested in round 2:** a boot ramp, invisible paths, a nose pad and two rope ladders (`art-list.md`, "Walk surfaces"). The whole route was walked and climbed in Play. **Hard** for a beginner, mainly because of placing the paths. |
| 85% warning: hand twitch and mumble | Shown as one still pose (arm up 5°, bubble on). The twitch was not played as a moving animation. The belly scratch is left out (no tested way to slide his hand across his belly). | Move the right arm up 5° and back twice with TweenService; show the bubble for 2 seconds |
| Eyelid flutter (60% warning) | Built as two lid models with a set lift height; the flutter itself was not played as a moving tween | Move both lid models up 1.4 studs and back, twice |
| Waking up: head tips forward, fist goes up | Tested as instant poses only. A smooth tween between them was tested on 2026-10-11 (action items, section 4), but not on this giant. | The same pieces moved smoothly (with TweenService) over about 1 second. The hand slam itself is untested. **Hard**. |
| Awake eyes | Built from Studio spheres because the generated "open eye" failed Roblox's automatic check twice | The sphere eyes, shown or hidden |
| Screen buttons | Made in HTML. One real button was built in Studio on the phone simulator to prove the look (`mockups/source/hud-button-test-phone.png`): fill, Ink outline, emoji picture and word all render. | Built with `ScreenGui`, `UICorner`, `UIStroke`, `UIGradient` and the font Fredoka One |
| 8 gardens with picket fences | About 4,000 small parts in total. Fine on a computer, not tested on a real phone. | One fence model copied around, or a single generated fence mesh. Turn off shadows on the far trees. |
| Animated grass | `Terrain.Decoration` could not be read or set from a script in this Studio | Flowers and drifting petals |
| Other players | Default grey-skinned avatars made in Studio | Real players' own avatars, which are more colourful |

## Phone check

- All 5 key states were captured in Play on Studio's **iPhone 14** device simulator (landscape). That gives a 750×390 play area inside the phone's safe edges. The images are scaled to 844×390 for the mockups.
- The thumbstick and Jump button are visible in the real phone shots, and no button of ours overlaps them.
- On the phone, the Friend Boost line moves into the cash panel. The **Lullaby** button shows in Tiptoe's column only while the meter is at 85% or more, or while he is awake (`hud-phone-wakeup.png`). The rest of the time the right edge only has Tiptoe.
- The phone menu is 3 columns × 2 rows, so all 6 buttons stay above the thumbstick.
- The "woke the Giant" banner on the phone is small and sits under the meter, clear of the slam circle and the runners.
- Round 2 note: in some phone shots Roblox's thumbstick and Jump button did not draw (the shots were taken with the avatar held still). The `hud-phone-spawn.png` shot shows them, and the bottom corners are kept free in every layout.
- Smallest text on the phone: 14 px. Readable in the mockups.
