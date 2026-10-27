# Lessons: Scenery and the world

About placing, fitting or fixing objects in the world, and checks that measure them. The map of all lessons is `docs/lessons/index.md`.

## Lesson 1: Scenery gets the cheap fix
- **What happened:** the Sock is scenery: the giant dropped it, and nothing in the game is played on it. It still took Tasks 32 and 35 to 39, then Task 37, plus 16 rulings, to make its edges perfect for players who walk into it (2026-10-26 to 10-27).
- **Do instead:** check the idea's "What matters most" list first. Scenery gets the cheapest fix that keeps players safe and the look intact: block it off, make its shape simpler, or let the rescue (Rule 28: Stuck players are rescued) catch the player. A second task on the same object goes to `product` first.
- **Who checks:** `product`, `code_lead`, the main chat.

## Lesson 2: Change the scenery, not the giant
- **What happened:** every fix that fits a part tightly against the giant's body or head took many tries, because his mesh is curved and leans out over itself. The forehead fill was built and then taken out (Task 34), the beard moved on to Task 33, the Sock's lips took four tasks, and the pillow pokes into his nightcap (Task 40).
- **Do instead:** when scenery meets the giant badly, change the scenery so it doesn't touch him tightly (make it smaller, move it, or simplify it) before trying to fit parts to his shape. Example: make the pillow half as big, so he still leans on it and nothing pokes through.
- **Who checks:** `designer`, `code_lead`, `product`.

## Lesson 8: Checks that look straight down miss upright surfaces
- **What happened:** the slide guard checks measured the Sock's cloth by looking straight down, so they missed its upright, overhanging lip and failed boards that were fine (Task 37, step 37-2).
- **Do instead:** measure an upright or overhanging surface along the direction it faces, not from above.
- **Who checks:** `code_lead`, `builder`.

## Lesson 9: Rank what matters before fixing the world
- **What happened:** the Sock, the pillow and the forehead's sides got many tasks before anyone wrote down that players never play with them (2026-10-26 to 10-27). The "What matters most" list came only after the time was spent.
- **Do instead:** `game_creator` writes the idea's "What matters most" list before a version's first world-fixing task, and `code_lead` checks each new task against it ("what it's for").
- **Who checks:** `game_creator`, `code_lead`.

## Lesson 10: Check the safety net reaches the spot
- **What happened:** the rescue (Rule 28: Stuck players are rescued) only covers players on the giant. The Sock lies on the meadow, so it had no safety net and had to be made perfect (2026-10-26 to 10-27).
- **Do instead:** before choosing a cheap fix for scenery, check that the safety net really reaches that spot. If it doesn't, simplify or block off the object first.
- **Who checks:** `product`, `code_lead`.

## Lesson 19: Sink scenery instead of fitting parts to it
- **What happened:** players hung on edges that stick out near the ground: the Sock's lips and the pillow's bulging back. Each was fixed by fitting invisible parts to its curved shape, task after task (2026-10-26 to 10-27).
- **Do instead:** sink the scenery into the ground or the hill until no edge hangs over. If a hang is left, sink it a little more (one number), never fit parts to it.
- **Who checks:** `designer`, `code_lead`.

## Lesson 21: Never start a walk, check or camera inside a mesh
- **What happened:** three times a script started inside a part and believed what it found: the gap walk in step 39-5c and in step 37-5 started inside the Sock's fill, and in step 37-6 the shot camera sat inside the Sock's mesh. A ray never hits the part it starts in, so each check said "clear" (2026-10-27).
- **Do instead:** before a walk, check or shot, test the start spot is open (nothing overlaps it). Test it with `GetPartsInPart` on a body-sized probe part, which uses the real shapes. On a slope, put the probe's bottom 0.1 above the highest of 5 down-ray hits (centre and 4 corners); if it's still blocked, move it 0.5 studs downhill, at most 4 times, then log "not open" and skip it (Task 33 step 1: a probe set on its centre's ground dug into every 51-76° slope). Never use `GetPartBoundsInBox` for this: it compares rough outer boxes, so near the giant every spot looks closed (Task 41 step 3, Task 42 step 1 and its review, 2026-10-27). Place a camera with a ray from the player's head out to the camera, the way Roblox's camera does. Every handoff with a walk or a shot says how its start is checked.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 26: Try 5 examples before choosing a fix
- **What happened:** in Task 41 the team guessed that players wedged in a gap and planned to sink the pillow to close it. A slide simulation showed sinking it 0.1 to 3 studs changed nothing, so the guess was wrong (2026-10-27).
- **Do instead:** before choosing a fix for stuck spots, run the cheap read-only check on about 5 real examples and confirm the cause. Only then pick the fix.
- **Who checks:** `code_lead` (in the handoff), `builder`.
