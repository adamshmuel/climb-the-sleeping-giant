# Climb the Sleeping Giant: research (2026-10-11)

The research behind the idea in [climb-the-sleeping-giant.md](climb-the-sleeping-giant.md). This is a dated snapshot: the numbers are what the charts showed on the fetch date, and they are not updated.

Contents:
- [Trend evidence](#trend-evidence)
- [Competitor study](#competitor-study)
  - [The closest games](#the-closest-games)
  - [What we learned](#what-we-learned) (including the price ranges players already pay)
  - [Developer forum lessons (opinions, not data)](#developer-forum-lessons-opinions-not-data)
  - [Official Roblox rules and guides used](#official-roblox-rules-and-guides-used)

## Trend evidence

Data fetched 2026-10-11 at 18:43 UTC from the Roblox charts and game details (`roblox-trends` skill).

| Signal | Number |
|---|---|
| Simulation in Top Playing Now | 33 games, 2,738,851 players. The biggest genre. |
| Simulation in Up-and-Coming | 40 games, 431,406 players. The biggest genre in the fastest-growing list. |
| Tycoon subgenre | Top Playing Now: 5 games, 1,680,412 players. Up-and-Coming: 10 games, 208,357 players. |
| Steal An Egg | No. 1 on Roblox: 1,323,939 playing (1,215,470 four days earlier). Created 2026-07-25. 7.75 billion visits. 92% upvotes. |
| Break and Steal an Egg | 95,356 playing. 97% upvotes. Created 2026-09-05. |
| Other egg games charting today | Steal Animal Egg 18,364. Drill for Eggs 17,632. Clone to Steal Eggs 12,237. Lift Rock For Eggs 11,910. Shoot For Eggs 11,878. Crack the Egg 6,360. All created in September 2026. |
| Sneaking past sleepers | Don't Steal the Bobo: 468 million visits, 14.2 million favorites, 95% upvotes, still 4,216 playing after a year. Dont Wake the Kitty: 76.5 million visits. Dont Wake Grandma: 205.9 million visits. |
| Co-op against one big monster | 99 Nights in the Forest: 314,875 playing, 30.0 billion visits. Its deer monster is in every thumbnail. |
| Social chase | Huss Valley, a tag game made 2026-08-31: 140,623 playing, No. 1 on Up-and-Coming, even though it is a plain green field. |

What it means:
- The "grab an egg from a guard, hatch it, earn" loop is the hottest thing on Roblox, and it is still growing.
- Sneaking past sleepers has worked for a year.
- Co-op against one big monster and chaotic chases are what grow fastest.
- Our game combines all three.
- The danger is that the egg genre is crowded: new copies launch every week.

## Competitor study

Reference screenshots and summaries are in `references/top-games/<game>/` (the shared reference library, filled 2026-10-11 with 28 games).

### The closest games

| Game | How it plays | What it sells (Robux) | Where players drop off (badges) | How it looks |
|---|---|---|---|---|
| **Steal An Egg** (1,323,939 playing) | Grab eggs from under big guard animals, carry them home, eggs grow and hatch, pets earn cash. You can also raid other players' bases. | X2 Money 399, X2 Growth Speed 467 | Welcome 227.9M. Hatched Secret 80.3M (35%). Hatched Eternal 54.5M (24%). Divine Trail 20.3M (9%). Hatched Divine 10.3M (4.5%). | A flat green studded floor, base walls, huge blocky pets. `steal-an-egg/shot-08.jpg` to `shot-10.jpg`. Its store icon (`store-icon.png`) is a polished 3D render, far nicer than the game itself. |
| **Break and Steal an Egg** (95,356) | Break an egg with a pickaxe, grab the animal, escape the guard who chases you, place it in your pen. No player stealing. | No passes for sale | Only one badge (Welcome 9,958,360) | Copies Steal An Egg's look and buttons. A "RUN!" banner shows while you carry. `break-and-steal-an-egg/shot-06.jpg`. |
| **Don't Steal the Bobo** (4,216 now, 468M visits) | Sneak up on sleeping Bobos, grab one, run when it wakes, take it home. Rarer ones sit farther out. No player stealing. Trading. | "Make guards sleep for 60s": 9 Robux (seen in a gameplay video). Packs, potions, a free spin wheel with paid spins. | Welcome 66.5M (no other badges) | Flat red and green floors, cute plush characters, a "Safe Zone" painted on the floor. `dont-steal-the-bobo/shot-02.jpg` to `shot-05.jpg`. |
| **Steal the Bobo** (the same studio's follow-up) | The same idea, plus stealing from other players | n/a | 268 playing, 10.3M visits, 89% upvotes | The version with player stealing flopped next to the original. |
| **Clone to Steal Eggs** (12,237) | Send clones to steal eggs from a chain of guard creatures | Auto Hatch 40, x2 Cash 75, VIP 150, +4 Pet Slots 95, +2 Pet Slots 185, Extra Clone 95 | Chicken 82%. Snake 51%. Yeti 34%. T-Rex 19%. Whale 6.8%. Dragon 3.0%. | A template look: flat studs, voxel animals |
| **Dont Wake Up for Eggs** (2,708) | Sneak eggs without waking the animals | x2 Cash 75, VIP 150, +4 Pet Slots 148, +2 Pet Slots 76 | First Egg 82% of Welcome, so 18% leave before their first egg | A template look. Only 79% upvotes. |
| **Steal Animal Egg** (18,364) | Take eggs from animals, steal from players | Starter Packs 3 / 9 / 59 / 199, VIP 99, x2 Cash 199, x2 Growth 229, Auto Place 149, cosmetics 49-799 | "For the HUGE" 1,992,732 | Busy buttons, a starter-pack offer always on screen |
| **Drill for Eggs** (17,632) | Dig down to guarded eggs, sneak them back | VIP 160, MVP 395, x2 Power 160, x2 Money 120, x2 Hatch Speed 149, Supreme 1,495, Legend 4,500. A "Jail Guards for 15s" button. | No badges | Flat studs with dug pits |
| **Ride A Pet** (79,337, 96% upvotes) | Ride pets to find eggs, hatch faster pets | Infinite Radar 399 | No badges | **The best-looking egg game:** real terrain, low-poly trees, fenced ranches, big detailed creatures. `ride-a-pet/shot-03.jpg` and `shot-04.jpg`. |

### What we learned

1. **The loop is proven, but the twist has to be new.** Guard animals, sleeping guards and "don't wake them" all exist. The new parts are the one colossal giant you climb on, the server-wide wake-up, the Deep Sleep event and the bounce-off.
2. **Player stealing isn't needed, and may hurt.** The two highest-rated games in the wave have none: Break and Steal (97%) and Bobo (95%). When Bobo's studio added player stealing, the new game flopped (268 playing against 4,216). We keep "nobody can rob you".
3. **The first egg must come in seconds.** Dont Wake Up for Eggs loses 18% of players before their first egg.
4. **Every tier loses about half the players.** Clone to Steal Eggs goes 82%, 51%, 34%, 19%, 7%, 3% from one guard to the next. Most players must reach the Rare zone in their first session.
5. **Rare hatches drive people on.** 35% of Steal An Egg players hatch a Secret pet, and only 4.5% a Divine one.
6. **The in-game look of the egg games is low.** Their icons are polished renders, but their worlds are flat studs. A world as rich as Ride A Pet's or Adopt Me's is a real edge. Players also judge the first screen within seconds.
7. **Price ranges players already pay:**

   | Item | Range (Robux) |
   |---|---|
   | 2x Cash | 75-399 (middle about 199) |
   | VIP | 85-375 |
   | Faster hatching | 149-467 |
   | More pet slots | 76-185 |
   | Auto hatch | 40 |
   | Put the guards to sleep for 60 seconds | 9 |
   | Starter packs | 3-199 |

### Developer forum lessons (opinions, not data)

- **Roblox now ranks games over 28 days.** The ranking looks at how many people click your game, whether they leave in the first few minutes, how many days they come back, and how many days they play with friends. [Recommended For You Algorithm Improvements](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)
- **Since August 2026, retention plus fair spending earn more Home page spots.** Retention means players coming back. "If retention is low, focus on core gameplay first." [Boost Your Discovery](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042)
- **Test up to 5 thumbnails at once and leave them alone for 7 days.** Personalized thumbnails raised click-and-play rates by 12% on average. [5 Tips From Roblox Staff on Thumbnail Personalization](https://devforum.roblox.com/t/5-tips-from-roblox-staff-to-get-the-most-out-of-thumbnail-personalization/3471689)
- **If the icon doesn't show the twist, you're "just another Steal a ___ game".** A kid picks the icon they recognize. [Steal a House: Trend Game with a Twist](https://devforum.roblox.com/t/new-game-steal-a-house-trend-game-with-a-twist/3812996)
- **Copying the trend isn't enough.** One brainrot copy had 2.5% of players come back the next day, with 5-minute sessions. [How do "slop" games do so well?](https://devforum.roblox.com/t/how-do-slop-games-do-so-well/4510868)
- **The first 20 days of data matter most.** A small ad budget at release helps Roblox learn who likes the game. [How to (actually) make a popular game](https://devforum.roblox.com/t/how-to-actually-make-a-popular-game/3115791)
- **Keep the first minutes simple.**
  - No long tutorial that can't be skipped.
  - Clear goals.
  - Confetti on every reward.

  [How to increase retention in a simulator](https://devforum.roblox.com/t/how-to-increase-retention-engagement-etc-in-a-simulator/3292053)
- **Bugs and unfair moments cost approval, and the game doesn't recover.** [How do I improve my game's monetization?](https://devforum.roblox.com/t/how-do-i-improve-my-games-monetization/2522234)

### Official Roblox rules and guides used

- [Discovery](https://create.roblox.com/docs/discovery):
  - The most important signals are click-and-play rate, early leaving (judged between 61 and 180 seconds), days played and playtime.
  - Games that copy another game's title and look are "no longer prioritized".
  - Roblox advises: "Add your own spin to existing trends."
- [Roblox Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select):
  - Under-16 players only get a game after a trial with players aged 16 and over.
  - The game needs 250 plays from "highly engaged" players within 60 days.
  - The owner must verify their account, turn on 2-step verification, and either pay a refundable fee or have Roblox Plus for 2 months.
- [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity): roaring, suspense music, creepy-looking characters and jump scares still count as Mild fear.
- [Roblox's August 2026 rule](https://www.pocketgamer.biz/roblox-restricts-reward-driven-media-feeds-in-kids-and-select/): no rewards for watching an endless video or picture feed. Steal An Egg was removed for exactly this, then put back without the feed.
- [Friend referral system](https://create.roblox.com/docs/production/promotion/referral-system) and [invite prompts](https://create.roblox.com/docs/production/promotion/invite-prompts): Roblox's built-in way to reward both the friend who invites and the friend who joins.
- [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails):
  - Show real gameplay.
  - Keep text to a short description of what happens.
  - Keep important things away from the bottom edge.
- [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding) (the first minutes of a new player): teach only the essentials, get to the fun fast, and end with a "moment of joy".
- Older guidance that still applies: players dislike paying to skip timers, and random items sold for Robux have extra rules ([Monetization](https://create.roblox.com/docs/production/monetization)).
