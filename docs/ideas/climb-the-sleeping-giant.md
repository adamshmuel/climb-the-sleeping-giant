# Climb the Sleeping Giant

(Earlier name: Sneak the Nest. Same core idea, rebuilt on new research from 2026-10-11.)

This file is the idea as it is now. Two files beside it hold the rest:

| File | What's in it | When to read it |
|---|---|---|
| [climb-the-sleeping-giant-research.md](climb-the-sleeping-giant-research.md) | Trend evidence and the competitor study (charts, prices, badges, forum lessons, Roblox guides), fetched 2026-10-11 | When you need the evidence behind a decision, or the competitors' prices and looks |
| [climb-the-sleeping-giant-history.md](climb-the-sleeping-giant-history.md) | What changed from "Sneak the Nest" and why, and every decision made after Gate 1, with what would change it | When you want to change a rule or a value, or need a playtest trigger |

Contents:
- [What changed and why](#what-changed-and-why) (moved to the history file)
- [Pitch](#pitch)
- [Genre](#genre)
- [Who it's for](#who-its-for)
- [Trend evidence](#trend-evidence) (moved to the research file)
- [Competitor study](#competitor-study) (moved to the research file)
- [Core loop](#core-loop)
- [What matters most](#what-matters-most): core gameplay, supporting, scenery, the things that touch the giant
- [Twist](#twist)
- [The giant and his valley](#the-giant-and-his-valley), with the 5 zones
- [V1 gameplay](#v1-gameplay):
  - [The first 60 seconds](#the-first-60-seconds)
  - [Minutes 1 to 10](#minutes-1-to-10)
  - [Sneaking and noise](#sneaking-and-noise)
  - [The wake-up](#the-wake-up)
  - [Deep Sleep (the server event)](#deep-sleep-the-server-event)
  - [Hatching and pets](#hatching-and-pets)
  - [The base and cash](#the-base-and-cash)
  - [Upgrades](#upgrades)
  - [Playing with friends](#playing-with-friends)
  - [Daily rewards](#daily-rewards)
  - [In V1, and left out of V1](#in-v1-and-left-out-of-v1)
- [Virality](#virality)
- [Look](#look)
- [Retention](#retention)
- [Monetization](#monetization): game passes, developer products, fairness rules
- [Decisions made after Gate 1, and why](#decisions-made-after-gate-1-and-why) (moved to the history file)
- [Reviewing a built feature](#reviewing-a-built-feature): my checks at Gate 4
- [Risks (premortem)](#risks-premortem)

## What changed and why

Moved to [the history file, "What changed and why"](climb-the-sleeping-giant-history.md#what-changed-and-why). In short: the heart of the game stayed, and the name, twist, egg places, wake-up, events, friends, collecting, prices, audience and look were rebuilt on the 2026-10-11 research.

## Pitch

A giant is snoring in the middle of the valley, and he has hoarded every egg in the land: under his boots, on his belly, in his beard and under his nightcap. Tiptoe across him, grab an egg and run home before he wakes. Your eggs hatch into pets that earn cash, and the cash buys quieter shoes and faster legs so you can climb higher on him for rarer eggs. Everyone in the server shares the same giant, so one clumsy step wakes him for all eight players.

## Genre

Simulation > Tycoon (Roblox's official genre and subgenre).

Roblox describes a tycoon as a game about "the management of a business or base", where players collect money and use it to upgrade. Here the base is your garden plot and the pets are the money makers. Steal An Egg, Break and Steal an Egg and Don't Steal the Bobo use the same genre.

## Who it's for

- **Main players:** kids aged 8-14 who play on phones and like collecting pets, being a bit naughty, and screaming with friends.
- **Younger kids (5-8):** they can play too, because the game stays Mild. A Mild game may have "mild fear-based content", such as a roar or suspense music. It has no blood.
- **Teens 16+ at launch:** every new game starts as a trial for players aged 16 and over. The chaos and the jokes (the bounce-off, the blame banner) must be funny for them too.

## Trend evidence

Moved to [the research file, "Trend evidence"](climb-the-sleeping-giant-research.md#trend-evidence) (data fetched 2026-10-11). In short: Simulation > Tycoon is the biggest genre, the egg-heist loop is No. 1 on Roblox and still growing, sneaking past sleepers has worked for a year, and the egg genre is crowded.

## Competitor study

Moved to [the research file, "Competitor study"](climb-the-sleeping-giant-research.md#competitor-study): the 9 closest games with their prices, badge drop-offs and looks, what we learned, the price ranges players already pay, developer forum lessons and the official Roblox guides used.

## Core loop

The core loop is the set of actions a player repeats over and over.

1. **Sneak:** tiptoe toward the giant. Your noise fills his sleep meter, which the whole server shares.
2. **Grab:** pick up an egg. The higher on the giant, the rarer the egg and the more each step counts.
3. **Escape:** carry the egg back through your base's Safe Gate before he wakes.
4. **Hatch:** put the egg in an incubator and watch it wobble, crack and pop.
5. **Earn:** the pet sits on a pad at your base and makes cash, even while you're offline.
6. **Upgrade:** spend cash on quieter shoes, faster legs, a stronger back, more incubators and more pads, then climb higher for rarer eggs.

**Fun in the first 10 seconds:** you spawn at your garden gate looking straight at the giant's enormous sleeping face. His snores blow the grass flat and "Zzz" bubbles float up. Glowing footprints lead to an egg next to his boot, eight steps away.

## What matters most

This list sorts every real thing in the world by how much it matters to the player. Use it to match effort to value. It follows two rules: scenery gets the cheap fix, and change the scenery, not the giant.

| Tier | What it means | How much effort a problem gets |
|---|---|---|
| **Core gameplay** | Players play with it in the core loop: sneak, grab, carry home, hatch, earn, upgrade | Real time. Fix it properly and check it in Play |
| **Supporting** | Helps the core loop: keeps players safe, shows the way, or rewards them | A solid fix, but the simplest one that does the job |
| **Scenery** | There only for looks and story. No egg, no path and no noise zone sits on it, and nothing in the game sends players there | The cheapest fix that keeps players safe and the look intact: block it off, make it smaller or simpler, move it, or let the rescue (Rule 28: Stuck players are rescued) catch the player. A second task on the same thing goes to `product` first |

**Keep it current:** when a spec adds a part or an object, it gets a row here. Pets join the core list when hatching (spec 2) is built.

### Core gameplay

| Thing | Why it's core |
|---|---|
| His face, his eyelids and the sleep meter (the big "Zzz" bubble), with its warnings: the eyelid flutter, the snoring stopping, the double snort and the "Mmm... my eggs..." bubble | Sneaking is the core loop. These tell every player how close he is to waking |
| The wake-up: sitting up, the bounce-off, the slam fist and the red slam circles | The shared danger, and the funniest moment of the twist |
| His boots and knees: the boot tops, the boot toe nests, the knee pockets and the lap fold | Boots and Knees zone, Uncommon eggs |
| The four ways up onto the boot tops: two boot ramps and two boot ladders (the side ladders, side pads and thigh planks were dropped on 2026-11-03). Then the two lap planks, the lap landing with its front apron, the two belly ramps and the belly path | The only roads onto him. Every heist uses one, and each garden has its own close by |
| His belly top and upper sides down to the stitched seam, with the lower belly nests and the 2 belly pockets | Belly zone, Rare eggs, walk anywhere |
| His arms out to his white cuffs, the 4 cuff pockets and the 2 cuff straps | Epic eggs |
| The beard–belly fold nests at the foot of his beard | Rare eggs |
| The beard ladder and the cap ladder: one middle pair on his centre line (x 0), the beard ladder from the belly to his nose, the cap ladder from his nose to the nightcap brim | The only way to his nightcap. On the centre line it is the same distance from both sides, so the climb, the way home and the Deep Sleep race stay level for every garden (V2, Adam, 2026-11-04) |
| His nightcap: the cap ladder top, the brim, the side stripe and the top of the cap | Legendary eggs, the top of the climb, and the Dream Egg during Deep Sleep |
| Every egg and its straw nest: 16 in the meadow, 22 on him | What players come for |
| Each garden: the Safe Gate, the incubators, the pet pads, the cash chest, and the plank bridge over the stream | Home: carry the egg in, hatch it, earn and upgrade. Every heist starts and ends here |

### Supporting

| Thing | How it helps |
|---|---|
| The glowing footprints | Show the way to the next egg and back home |
| The stitched seam and its blue hem band | Show where walking ends on his sides |
| The invisible guards: rail guards on the planks, edge guards, slide guards, and the forehead guard's smooth side walls and side rails | Stop falls and stuck spots |
| The rescue and its lavender puff (Rule 28: Stuck players are rescued, and Rule 33: What a rescue looks like) | Gets a stuck player back to their last safe spot |
| The 12 landing spots in the meadow | Where players float down when he wakes |
| Egg glow, sparkles, light beams, rank words and the refill pop | Let players spot an egg and its rank from far away |
| The picket fences and stepping stones in each garden | Show where your safe plot starts, and lead to the pads, incubators and chest |
| The light on his face | Keeps his face, and its warnings, bright |
| The safe-home confetti, the caught puff and the slam dust | Reward and feedback moments |

### Scenery

| Thing | Notes |
|---|---|
| The pillow behind his head, and the red cushion he leans on (the chair) with its armrests | See below |
| The Sock, the teacup and the candle (things he dropped) | Story props. The footprints guide players, not these |
| Trees, bushes, flowers, mushrooms, rocks, logs, stumps, lantern posts, the stream, the hills, the garden hedges and flower borders, the pollen and petals | The storybook valley that makes the game look full |
| The lace bows on his boot tops | Players walk straight through them |
| The tail and pom-pom of his nightcap | Their nests were dropped in spec 5 (Egg nests and climbing) |
| The parts of him off every route: his back, under his beard, his cheeks, the sides of his forehead, his skin below the seam | Only for looks. But he is the star of every thumbnail, so **he is never reshaped**: block these parts off with smooth guards, or change the scenery next to them |

### The things that touch the giant

| Thing | Tier | Does the player play with it? | Would a player notice if it were smaller, simpler or moved? |
|---|---|---|---|
| **The Sock** | Scenery | No. No egg, no path, no noise. Players only bump into it in the meadow by his left side (your right as you face him), near the boot ladder gardens 1 to 3 use (`BootLadder_Left`) | No, if it still reads as a giant sock from the gardens. Smaller, with no overhanging edge, or moved a few studs off the walk: nobody would notice |
| **The pillow** | Scenery | No. No egg and no path. A player only lands on it by stepping or jumping off the back of his nightcap, so it only has to let them slide off safely. (Zone 5 is called "Beard, Pillow and Nightcap", but nothing is played on the pillow) | Half as big, with his head still clearly leaning on it: no. Moved away from his head: yes, because his head would float |
| **The nightcap** | Core gameplay (the brim, the side stripe, the top of the cap and the cap ladder top) | Yes. The 4 Legendary nests, the Dream Egg in Deep Sleep, the loudest steps (x3) and the top of the climb | Yes. It is the goal. Only its tail and pom-pom are scenery |
| **The beard** | Core gameplay for the fold at its foot only; the rest is scenery | The fold, with its Rare nests, and the middle beard ladder, the way up to his nose (V2, Adam, 2026-11-04) | The fold: yes. The rest: block it, never reshape it |
| **The forehead and nose** | Supporting (the nose top only, where the beard ladder ends and the cap ladder starts); the rest is scenery | The nose top is on the way to the cap. No egg on them: the Dream Egg sits on his cap. A player got stuck on the forehead sides in the first playtest | No. A smooth guard that slides players off is enough |

## Twist

**One colossal giant, and you climb on him.**

- **Scale.** Other egg games guard each egg with an animal about your size. Here one giant, as big as a hill, lies across the whole valley. You don't walk around him: you walk up his boot, across his belly and into his beard.
- **The server shares him.** There is one sleep meter for everyone. One loud step from anyone wakes him for all.
- **The wake-up.** He sits up and roars. Everyone on his body goes flying off and lands softly in the meadow. Then he slams his hands at anyone carrying an egg. A banner names whoever woke him: "Adam woke the Giant!"
- **Deep Sleep.** Every 10 minutes the whole server gets the same 60-second chance at the best egg.

It keeps the tension of a steal game with no griefing (players bullying or robbing each other). And it gives every server a shared story to laugh about.

## The giant and his valley

- **The giant:** a huge, cute-grumpy old giant in patched pajamas, with a bushy beard, rosy cheeks and a long nightcap. He hoards eggs because he likes shiny things. He is silly, not scary.
- **The valley:** a sunny storybook meadow with a stream, flowers, big mushrooms, fences and trees. The giant half-lies in the middle, leaning back on a red cushion with a huge pillow behind his head and his boots toward the gardens, so every garden sees his face. Things he dropped make landmarks: a teacup as big as a house, a sock, a candle.
- **Bases:** 8 garden plots in a ring on low hills around the valley, one per player. Each has a fence, a **Safe Gate**, incubators, pet pads and a cash bin. Inside your plot you are always safe. The giant never reaches into plots.
- **Server size:** 8 players.

### The 5 zones (from easy to hard)

| Zone | Where | Egg rarity | Noise per step |
|---|---|---|---|
| 1. The Meadow | The grass around his boots and hands | Common | Silent (x0): he can't hear you on the grass |
| 2. Boots and Knees | Climbing up his boots and legs | Uncommon | Normal (x1) |
| 3. The Belly | The wide, soft middle of his body | Rare | Higher (x1.5) |
| 4. His arms and cuffs | Out along his sleeves to pockets on his white cuffs | Epic | Higher (x1.5): it counts as the Belly |
| 5. The Beard, Pillow and Nightcap | Up his beard onto his cap, next to his ear | Legendary | High (x2) on the beard, highest (x3) on the cap |
| Event: the top of his nightcap | Only during Deep Sleep | Secret (the Dream Egg) | Half noise during Deep Sleep |

Players walk on invisible walking surfaces shaped to his body, hidden under the giant model. This is decided now, because it is the reliable Roblox way to make a big model walkable. It also lets the builder choose exactly where players can stand.

## V1 gameplay

V1 is the first version that gets built. This section describes what the player sees and does.

### The first 60 seconds

Roblox counts players who leave between 61 and 180 seconds as a bad sign. So this minute must hook.

- **0-5 s:** You spawn at your Safe Gate facing the giant's sleeping face. Snoring, swaying grass, floating "Zzz". Glowing footprints lead to a Common egg by his boot.
- **5-15 s:** You walk to it and hold the grab button. The egg lifts onto your back, and the footprints turn toward home.
- **15-25 s:** You place it in your incubator. Your first egg hatches in 3 seconds: wobble, crack, pop, a pet jumps out, confetti.
- **25-40 s:** The pet hops onto a pad and coins float up. The footprints lead to your cash bin.
- **40-60 s:** You can afford Quiet Shoes level 1. Footprints lead up his boot to an Uncommon egg. The sleep meter appears over his head, and the Tiptoe button pulses once.

### Minutes 1 to 10

- **Minutes 1-3: first scare.** On your boot-climb the giant stops snoring and an eyelid flutters. You freeze or tiptoe, and the meter drains. A new player (someone who hasn't brought a Rare egg or better home yet) gets **one free save**: the first time their own noise would wake him, he stays asleep, the meter drops to 70 and the 85% warning plays again. After that, their noise wakes him like anyone's. So they feel every warning and one real close call, and the danger is never fake.
- **Minutes 3-5: first Rare.** A Rare egg is guaranteed on his belly for every new player. Hatching it is the first "wow". The Index (the collection book) opens and shows the silhouettes still missing.
- **Always on screen:** the Deep Sleep countdown, for example "Deep Sleep in 4:12".
- **Minutes 5-10: first wake-up.** In a busy server someone will wake him. Everyone goes flying, everyone laughs, and nobody loses anything but the egg they carried.

### Sneaking and noise

- **One sleep meter for the whole server**, shown as a big "Zzz" bubble over the giant. It shrinks and turns red as he gets closer to waking.
- **What makes noise:**
  - walking (normal);
  - landing from a jump (loud);
  - carrying a heavy egg (adds a little);
  - the zone you're in (see the table). The meadow is silent, so noise only counts once you step onto his boots.
- **Tiptoe:** a toggle button (a big button on phones, a key on computers). It moves you at 60% speed and makes very little noise. There is no separate sprint button.
- **Quiet moments drain the meter:** 1 point per second for each player in the server. A busy server has to tiptoe. A solo player walking a Rare home gets the 60% warning, and only wakes him from the highest spots without tiptoeing.
- **A jump landing on the giant is loud for everyone:** it counts in full, so one clumsy jump near the top of the meter wakes him for the whole server.
- **Jumping or falling off him is loud too:** one thud per fall, sized by the zone you fell from (for example, off his belly counts like a jump on his belly). It's a fast way down, but a gamble when the meter is high. Jumps that start and end in the meadow make no thud.
- **Eggs are shared:** every egg sits at a fixed spot, and the first player to finish the grab gets it. The spot refills after a short wait. A carried egg is yours until you get home or he catches you; nobody can take it from you.
- **Warnings before he wakes:**
  - at 60%: snoring stops, an eyelid flutters, the music thins;
  - at 85%: the snoring and Zzz stop, he snorts twice through his nose, and a bubble beside his nose says "Mmm... my eggs...". His arm doesn't move: while he sleeps, nothing a player stands on moves, because players walk out along his arms.
- **Starting values only:** the playtest decides the exact noise numbers. If most heists in the Belly zone end in a wake-up, lower the Belly noise.

### The wake-up

1. **He wakes.** The meter fills. He sits up with a huge yawn and a cartoon roar with no words. The screen shakes and the music turns into a chase tune.
2. **Bounce-off.** Everyone standing on him is bounced off with a "boing" and floats down into the meadow. This happens *before* he moves, so nobody stands on a moving part.
3. **Blame banner.** For 3 seconds everyone sees "💥 [name] woke the Giant!", and he glares at that player.
4. **Hand slams, for 15 seconds.** He slams his huge hands at players carrying eggs. A glowing shadow shows where each hand will land, 1.5 seconds before, so a child has time to react and run out of it.
5. **Caught.** A slam that hits a carrier pops the egg back to where it was. The player is flicked gently back to their Safe Gate. They lose nothing else: no cash, no pets.
6. **Heavy Sleep.** He lies back down and snores extra loud. For 45 seconds the meter can't rise, which gives everyone a safe window and stops repeat wake-ups.

### Deep Sleep (the server event)

- **When:** every 10 minutes. A countdown is always on screen.
- **For 60 seconds:**
  - he snores deeper;
  - noise counts half;
  - a glowing **Dream Egg** (Secret rarity) appears on the top of his nightcap, above the cap ladder top.
- **The race:** the whole server tries for the cap at once, up the one middle pair of ladders (the beard ladder, then the cap ladder, on his centre line), so this is where the funniest wake-ups happen.
- **Team Egg:** a giant **Team Egg** also appears on his belly. It needs 2 players holding it to move it, and both carriers get a pet from it, rolled at Epic odds or better.

### Hatching and pets

- **Incubators:** you start with 1 and can buy up to 4. You can go on more heists while eggs hatch.
- **Hatch times** (starting values):

  | Rarity | Hatch time |
  |---|---|
  | Common | 5 s (your very first egg: 3 s) |
  | Uncommon | 30 s |
  | Rare | 2 min |
  | Epic | 10 min |
  | Legendary | 45 min |
  | Secret | 2 hours |

  Long timers for rare eggs give a reason to come back later. If fewer than 30% of new players are still playing when their first Rare hatches, cut the Rare time to 1 minute.
- **Reveal:** every hatch wobbles, cracks and pops. Rarer pets get a bigger burst, a sound everyone nearby hears, and a server message for Epic and above.
- **Pets in V1:** 16 in total:
  - 3 each for Common, Uncommon, Rare, Epic and Legendary;
  - 1 Secret.

  They are cute creatures from the giant's world, such as a pillow bunny, a sock dragon, a teacup turtle and a dream owl.
- **Sizes:**

  | Size | Chance | Cash |
  |---|---|---|
  | Normal | most hatches | x1 |
  | Big | 1 in 10 | x2 |
  | Huge | 1 in 100 | x5 |

- **Golden:** 1 in 50 hatches is Golden, which earns x3 cash.
- **Showing the odds:** the Index shows these odds, even though eggs are never sold for Robux.
- **The Index:** shows every pet as a silhouette until you hatch it. Completing a rarity page gives a permanent +5% cash. Sizes and Golden are shown as extra stars.
- **A companion:** one pet can follow you around, just to show it off.

### The base and cash

- **Pets on pads** drop coins into your cash bin. Rarer pets drop more. You start with 6 pads.
- **Collecting:** walk over the bin to collect, with a coin burst and a counter.
- **Offline cash:** pets keep earning for up to 8 hours while you're away. A welcome-back pile waits when you return.
- **Your plot shows your progress:** more pads, bigger incubators and decorations unlock as you grow, so visitors can see how far you've got.

### Upgrades

| Upgrade | What it does | Levels |
|---|---|---|
| Quiet Shoes | Each step makes less noise | 5 |
| Fast Legs | Faster walking (and faster escapes) | 5 |
| Strong Back | Heavy eggs slow you down and add noise less | 5 |
| More Incubators | Hatch more eggs at once | Up to 4 |
| More Pet Pads | More pets earning at once | 6 to 16 |

How progression feels:
- **One session:** reach the Belly, and buy the next upgrade.
- **A few days:** reach his cuffs and his nightcap, fill the Rare and Epic pages, and win a Dream Egg.
- **Weeks:** a Huge Golden Legendary, the full Index, and then new giants.

### Playing with friends

- **One giant per server:** shared danger and shared laughs.
- **Friend Boost:** +10% cash for each friend in your server, up to +30%.
- **Invite reward:** when a friend joins through your invite for the first time, both of you get a free Rare egg. This uses Roblox's friend referral system.
- **Team Eggs:** only 2 players together can carry them.
- **The blame banner and the bounce-off:** moments friends laugh about together.
- **Nobody can steal from anyone.** Your base and pets are always safe.

### Daily rewards

- A 7-day login streak with a free gift each day.
- Day 3 gives a Rare egg, day 5 an Epic egg and day 7 a Legendary egg.
- Missing a day restarts the streak.

### In V1, and left out of V1

V1 includes everything above.

These are out of V1 and go into named later updates:

- **New giants:** Frost Giant, Lava Giant and more. Each is a new valley with the same systems and new eggs and pets. The plan is one every 2-3 weeks after launch.
- **Rebirth:** resetting your progress for a permanent bonus.
- **Trading and gifting pets.**
- **Weekend events,** for example "The Giant's Birthday".
- **Season pass:** a limited-time reward track with free and paid rewards.
- **Rewarded video ads,** for example "watch an ad to double your offline cash". These are allowed, because the player starts each ad and the number of ads is limited.
- **A cosmetics shop:** trails, pet hats, emotes.

These are never in the game:
- stealing from other players;
- selling eggs for Robux;
- rewards for watching any endless feed.

## Virality

Virality means why players invite friends and share the game.

1. **The name and icon say the twist.** "Climb the Sleeping Giant" tells a kid the twist in four plain words: you climb onto a giant who is asleep, something no other game offers. The name doesn't say what you collect, so the icon has to: a tiny player tiptoeing across a sleeping giant's beard with a glowing egg, more eggs tucked into his beard and nightcap, and his huge eyelid half open.
2. **Clip moments are built in:** the bounce-off, the blame banner, a near miss under a giant hand, his face waking up a few steps from you.
3. **The stakes are shared.** One player's noise affects everyone, so chat fills with "SHHH!". This turns strangers into a team and gives them a reason to bring friends.
4. **Friends pay off:** the Friend Boost, Team Eggs and the invite egg.
5. **YouTube moments:** Dream Egg races, Huge Golden pets, "I climbed onto the giant's nightcap".
6. **A countdown everyone shares:** Deep Sleep every 10 minutes keeps players around and gives the whole server one moment.

## Look

The bar: **in play, the game must look at least as full and polished as Adopt Me and Ride A Pet, and clearly better than the flat-stud egg games.** The icon must be as polished as the egg games' store art.

| Bar | Reference screenshots (in `references/top-games/`) |
|---|---|
| A full, bright world with props and warm light | `adopt-me/shot-01.jpg`, `shot-02.jpg`, `shot-05.jpg`, `shot-07.jpg` |
| Real terrain, low-poly trees, big detailed creatures | `ride-a-pet/shot-03.jpg`, `shot-04.jpg` |
| Huge creatures next to small players (scale) | `fisch/shot-02.jpg`, `99-nights-in-the-forest/shot-03.jpg` |
| A themed world built from giant everyday objects | `speed-keyboard-escape/shot-01.jpg`, `shot-02.jpg` |
| The floor we must beat (how our competitors look in play) | `steal-an-egg/shot-08.jpg` to `shot-10.jpg`, `break-and-steal-an-egg/shot-06.jpg`, `dont-steal-the-bobo/shot-02.jpg` to `shot-05.jpg` |
| Store art level (icon and thumbnail) | `store-icon.png` and `store-thumb.png` in `steal-an-egg`, `break-and-steal-an-egg`, `dont-steal-the-bobo` and `ride-a-pet` |

What it asks for:
- **Style:** a bright storybook cartoon with warm golden light and soft shadows. Readable on a phone.
- **The giant:** a generated model made in pieces (body, head, eyelids, beard, arms and hands, nightcap). It must look soft and charming, never creepy, to stay Mild.
  - Tested on 2026-10-11: a generated giant can be made in pieces, its eyes can be swapped between asleep and awake, and its head can tilt smoothly while the game runs.
  - Not tested: hands slamming and the whole sitting-up motion. These are the first things to test in the build.
- **Scale:** about 120 studs wide and tall, half-lying, next to a 5-stud player. That size difference is the picture that sells the game.
- **The valley:** store models for trees, flowers, rocks, fences, mushrooms and the stream. Generated models for the giant's dropped things (teacup, sock, candle) and for the eggs and the 16 pets. No plain grey blocks.
- **Screen buttons:** bold, colorful and labeled, like Adopt Me's. The countdown and the sleep meter are big and easy to read on a phone. The bottom corners stay free for movement and Jump.
- **Icon and thumbnails:** test up to 5 thumbnails at once. All of them show real gameplay with the giant as the star. Text is short and only says what happens (for example, "Don't wake him!"), and nothing sits at the bottom edge.
- **What `designer` checks:** that each look can be built from real store models or generated models, before anything is approved.

## Retention

Retention means reasons for players to come back.

| Roblox signal | How the game earns it |
|---|---|
| Days played (day 1, days 2-7, days 8-28) | Long hatch timers for rare eggs, 8 hours of offline cash, the 7-day streak, Index pages, a new giant every 2-3 weeks |
| Playtime | Deep Sleep every 10 minutes, the climb from zone to zone, hatching while you go on heists |
| Days played with friends | Friend Boost, Team Eggs, the invite egg, a giant everyone shares |
| Leaving in the first few minutes (a bad sign) | First egg in 15 seconds, first pet in 25, first upgrade in 60, a guaranteed Rare by minute 5 |

Starting targets, to be checked in Roblox's Creator Analytics after launch:
- fewer than 30% of new players leave before 3 minutes;
- 15% come back the next day;
- 5% come back on day 7;
- the average session lasts 15 minutes or more.

If the next-day number is under 10%, fix the first 10 minutes before adding content.

## Monetization

Monetization is what the game sells and for how much.

All prices are starting points taken from what 12 competing games charge (see the competitor study). Once the game has players, Roblox's price optimization tool tests them.

### Game passes (one-time purchases)

| Pass | What you get | Starting price (Robux) | Competitors (Robux) |
|---|---|---|---|
| 2x Cash | Pets earn double | 199 | 75-399 |
| Fast Hatch | Eggs hatch twice as fast | 149 | 149-467 |
| VIP | A gold name and chat tag, a VIP nightcap for you and your companion pet, +10% cash, 12 hours of offline cash instead of 8 | 149 | 85-375 |
| +4 Pet Pads | 4 extra pads | 129 | 95-185 |

### Developer products (repeatable purchases)

| Product | What you get | Starting price (Robux) | Notes |
|---|---|---|---|
| Lullaby | The giant falls into Heavy Sleep for 60 seconds for the **whole server**. A banner says "[name] sang the Giant a lullaby!" If he's awake, he lies back down. | 19 | Competitors sell "guards sleep 60 s" for 9. After a Lullaby ends, the next one can start after 2 minutes, so the giant is never asleep forever. If fewer than 1 in 200 players buys one in the first week, test 9. |
| Starter Pack (once per player) | Cash worth about 10 minutes of early play, plus a Nightcap hat | 19 | Competitors: 3-199 |
| Cash packs (small, medium, large) | Cash worth 15 minutes, 1 hour or 5 hours of your current earnings | 25 / 99 / 349 | Scales with your progress, so it's never worthless |

### Fairness rules

- **Nothing anyone buys can hurt another player.** There is no player stealing. The only purchase that touches others, the Lullaby, helps everyone.
- **No Robux eggs, ever.** Selling eggs would make them "paid random items", which come with extra rules and upset players. Eggs only come from heists, daily rewards and invites.
- **No paying to skip a timer.** Players dislike it, according to Roblox's guide. Fast Hatch is a permanent pass instead.
- **No rewards for watching feeds.** This breaks Roblox's August 2026 rule.
- **Calm shop wording:** "Open Shop", never "BUY NOW". No offer pop-up during a heist.
- **Pay to go faster, never to win.** A player who never pays can still reach every zone and every pet.

## Decisions made after Gate 1, and why

Moved to [the history file, "Decisions made after Gate 1, and why"](climb-the-sleeping-giant-history.md#decisions-made-after-gate-1-and-why): the look decisions, the gameplay decisions and the price reasons, each with what would change it. The main rules they set are in the sections above. Exact numbers live in the specs.

## Reviewing a built feature

### My checks at Gate 4 (first-impression review of a built feature)

Play it as a brand-new player, on computer and on a phone screen, in a solo server and with other players if possible. Take screenshots and compare them with `references/top-games/`, especially `adopt-me`, `ride-a-pet` and `steal-an-egg`.

1. **First 10 seconds:** I spawn facing his whole sleeping face, with no camera fix from a script, and the footprints and the meter are on screen. Only the thin middle cap and beard ladders cross his face (V2, 2026-11-04): his eyes and the "!" stay readable, and the bottom corners are free on a phone.
2. **Would a kid stay?** The world looks at least as full as Ride A Pet's, and clearly better than the flat-stud egg games.
3. **First egg home within 60 seconds,** with a clear "Safe!" reward moment.
4. **The first scare happens solo:** a walking Rare heist from Rare_1 passes 60%, and I notice it without sound (pulse, Z Z Z pause, flutter).
5. **Waking him is funny, not unfair:** the bounce-off lands softly, the banner names the waker, and the red circles give time to run. I lose only the egg I carried.
6. **I never get stuck** on his body, on a ladder top or on the forehead. Climbing works with the phone thumbstick.
7. **Nothing feels pushy or paid** in the heist. Purchases come only in spec 9.
8. **The noise balance holds:** solo play warns without constant wake-ups, and a busy server needs to tiptoe.

## Risks (premortem)

Imagine the game launched and failed six months later. Working backward, these are the most likely causes, based on the research above.

| Cause | Category | Probability | Impact | How to reduce it |
|---|---|---|---|---|
| The giant system is too big for a beginner. It has a sleep meter, 5 zones, the bounce-off, hand slams, Deep Sleep and Team Eggs. The game ships late or buggy. One collect bug sank World War Tycoon's approval. | Scope | **High** | **High** | Build in this order: (1) the core heist with the Meadow, Boots and Belly zones and the giant asleep, stirring and awake; (2) hatching, pets and cash; (3) the upper zones and upgrades; (4) Deep Sleep, Team Eggs and the friend features; (5) shop, daily rewards and offline cash. The giant only moves by turning and sliding his pieces. Players are bounced off before he moves. Test the hand slams and the sit-up in Studio first. |
| It looks like "just another egg game". 12 egg or steal games are charting, 9 of them made in September 2026. Sneak games (Bobo, Kitty, Dont Wake Up for Eggs, Dont Wake The Giant) already exist. Kids scroll past. | Competition | **High** | **High** | Lead the name, icon and every thumbnail with the colossal giant you climb on. Never show a plain egg-and-animal picture. Test 5 thumbnails and leave them alone for 7 days. Write the twist in the first line of the description. |
| Players run out of goals with one giant. Every guard tier loses about half the players (Clone to Steal Eggs: 82%, 51%, 34%, 19%, 7%, 3%). | Retention | **High** | **High** | Sizes and Golden multiply the collection. Long hatch timers, the streak and Deep Sleep. Plan a new giant every 2-3 weeks from launch, with the same systems and new art. |
| The game is stuck in the 16+ trial. Roblox needs 250 plays from highly engaged players within 60 days, and the account must be verified, use 2-step verification and pay a fee or have Plus. The kids it's made for never see it. | Launch | Medium | **High** | Before launch, Adam completes the account steps. Make the chaos and jokes work for teens. Use a small sponsored ad budget in the first 20 days, as the forum advises. |
| Players grief by waking the giant on purpose, or the blame banner becomes a way to mock someone. | Fun | Medium | **High** | Heavy Sleep blocks repeat wake-ups for 45 seconds. A wake-up only costs carried eggs. The banner is a joke, with no lasting score of wake-ups. Playtest with 8 players. If one player can ruin a server, raise Heavy Sleep to 90 seconds. |
| The generated giant or pets look cheap (an earlier test head came out with a patchy pink texture), or the world ends up plain again. | Looks | Medium | **High** | `designer` compares every screen side by side with `adopt-me` and `ride-a-pet` before approval. Regenerate or retexture weak models. `game_creator` rejects any plain look. |
| New players get confused or caught on their first try and leave within 3 minutes (18% of Dont Wake Up for Eggs players never get a first egg). | Onboarding | Medium | High | First egg in 15 seconds. A new player gets one free save before their first Rare egg is home. Guidance is footprints, not text. First hatch in 3 seconds. |
| Sneaking feels slow and kids get bored. | Fun (first 10 seconds) | Medium | Medium | Tiptoe only matters high on the giant. The Meadow and Boots can be done at normal speed. A Common heist takes under 30 seconds. |
| Bounce-off and hand-slam physics glitch: players stuck in the giant, or flung across the map. | Fun | Medium | High | Bounce players to set landing spots in the meadow. Slams only check carriers inside the glowing shadow. Test in Play with 8 players on phone and computer. |
| The egg wave fades before launch. | Trend timing | Medium | High | Ship V1 in weeks. The giant identity works without eggs: later giants can hoard other treasures. 99 Nights shows one great monster lasts. |
| Prices are off: the Lullaby is never bought, or the passes are too cheap. | Monetization | Medium | Medium | Start at the market middle. Use Roblox price optimization after 2 weeks. Test the Lullaby at 9 if sales are low. |
| The content rating is filled in wrong, or something scary pushes the game above Mild and it loses the under-16 audience. | Monetization | Low | High | Answer the questionnaire with "Mild fear". The giant stays cute-grumpy. No blood. |
| Phones lag with a huge giant, 8 plots and many pets. | Scope | Medium | Medium | Limit pets per plot (16 pads at most). Keep effects light. Test on a phone screen early. |

**Blocking risks (high probability and high impact):** scope, competition and retention. Each has a fix in the table, and those fixes must shape the specs before anything is built.
