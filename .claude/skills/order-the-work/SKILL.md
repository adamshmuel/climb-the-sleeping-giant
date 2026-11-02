---
name: order-the-work
description: Step-by-step checklist for putting a game project's remaining work in the right order, by what each piece stands on - decision first, then the world's layers, then a "Stands on:" list per piece - plus the reasons that never count for doing work early. Use before writing or checking any order of work, plan, handoff, ruling, fix list or "Stands on:" line.
---

# Order the work

Work done in the wrong order gets done twice. Go through the steps below in order, and write the answer to each step into your output, so a reader can check every one. Skipping a step, or answering it in your head only, is how the order goes wrong.

## Words

| Word | Meaning |
|---|---|
| **Final** | Decided **and** built. An open decision is never final: options not yet picked, mockups not yet judged, a choice waiting for the user. A part that any step will still add, move, reshape or remove is not final either |
| **Open change** | Any decision not yet made, or any part still to be built, moved, reshaped or removed, anywhere in the plan |
| **Stands on** | Work stands on a thing when that thing changing could make the work's result wrong. Not only what the work needs to run |
| **Sits on** | A layer sits on another when it is placed on it, reached through it or measured against it |
| **Placing** | Putting a thing into the world: new, moved, **put back, restored or undone** to an earlier spot. Putting back is placing, even to a spot saved in git, so it is ordered like any other placing |

## Step 1: Decision first

Look at the big picture before the task list. Write down:

1. **The biggest open problem.** What it has cost so far (tasks, hours, redone work), and what it blocks for the player and for the team.
2. **The decision that ends it,** and the options already on the table.
3. **The least work to decide.** Only the work that decision really needs, so it is made well and soon (for example: clearing the space the options go into, a mockup of each option, judging them side by side, the user's pick). This work goes first.
4. **Everything else waits,** unless it stands on no open change at all **and** costs little.

## Step 2: The layer map

Every game's world splits into the same five generic layers:

| Layer | What it is |
|---|---|
| Where things are found | the place the player explores to collect things |
| Where things are kept | where collected things are stored, and the player uses them |
| Home base | where the player starts, and goes in and out |
| The collectibles | the things the player collects |
| Scenery | what is only there to look at |

Read the project's layer map (the workflow rules name its path). If there is none, write it: the five layers **by name**, what each one is in this game, and which sits on which. Never swap them for layers of your own, and never list work (decisions, checks, reviews, approvals) as a layer. A layer the game doesn't have says "none in this game".

## Step 3: One goal per piece

Split every piece of work that mixes two goals (for example: removing one part, and checking a different part). Each piece gets its own row in Step 4. Being in the same task or step is never a reason to run together. A task ends when its own goal is done; work in it that stands on something later moves to after that thing.

## Step 4: The table

Fill this for every piece of work, and put the table in your output:

| Work | Layer it changes | Layers it reads (sits on, reached through, measured against) | Open changes to those layers, **anywhere in the world** | Stands on |
|---|---|---|---|---|

**The rule:** if a layer the work changes or reads has an open change anywhere, the work stands on that change **and** on the build that makes it final. Distance doesn't matter: a layer is one thing.

**Placing things that sit on a layer** (see Placing above) changes the layer that sits on top, and reads the layer under it. So placing collectibles waits for every open change to where they are found, even when they only go back to where they were. If a mockup or a check seems to need them in place first, show them in the mockup only; don't place them in the world.

**The question,** asked for every open change against every piece of work: **"If that change happens, is my result wrong?"** "Yes" or "maybe" means it stands on it. Never ask it the other way round ("does my work change that decision?").

Use the question that fits the goal:

1. **A check of the whole play** (can't get stuck, can reach everything, fair to every side) covers every layer the player moves on, plus everything that sits on them, whole and everywhere. It waits for every open change to them, so it runs once.
   - **Except the reach walk, which comes first.** Before anything is built, placed or argued about at a spot (a way up, a ladder, an item, a goal), a quick walk proves a player can get to that spot from where players already are, with a plain stand-in if the thing isn't built yet. It stands on nothing but the ground the player walks on, so it is never "a whole-play check" and never waits. Every task that builds or places at a spot stands on its reach walk. If the walk fails, the spot moves before any more work on it.
   - **Name the shape before fitting.** A task that places or fits parts names on its "Stands on:" line the exact shape it fits to (the body, the final design of the thing it touches, the reach walk). That shape is built and checked first, and the cause of a misfit is checked on 5 real examples first (Lesson 26). Fitting to shapes that weren't final cost V2 five tasks on the skin and pillow.
2. **Choosing between design options:** change only the layer the choice is in, and only as much as the mockups need. The layers that sit on it wait for the choice.
3. **A design change in one layer:** the layers that sit on it are updated next, and the whole change is tested only after them.

## Step 5: Reasons that never count

If any reason below is why a piece goes early, it doesn't go early. Look for these in your own words and in any order you are given:

| Reason given | Why it fails |
|---|---|
| "It's far from / away from the change" | A layer is one thing. Distance never makes work safe from an open change to its layer |
| "Under every option it will be like this" | A guess about options not yet chosen or built. Not final means not final |
| "This test runs every time, so it will catch any change" | That is doing it now and redoing it if it changes |
| "We can redo it if it changes" | Same. Work is done once |
| "It finishes or closes a task already started" | Being started is never a reason to go first |
| "It's quick or cheap" | Cheap goes early only if it stands on no open change |
| "My work doesn't change that decision" | The question asked the wrong way round (Step 4) |
| "The handoff, plan or ruling already put it here" | An order already written, even one the user approved, is an idea to test with this checklist |
| "A later spec replaces it anyway" | That decides how much to do, never when |
| "It's in the same task as the work before it" | Split it (Step 3) |
| "It only puts things back where they were" or "it chooses nothing new" | Putting back is placing. Whether the old spot still works depends on the open change, so it waits like any other placing |

## Step 6: Order and check

1. Put every piece after everything it stands on. The decision's work from Step 1 comes first.
2. For every piece placed before the decision's build, read its row again: does it change or read a layer that the decision changes? If yes, move it after the build.
3. Run the project's plan check on the written order (the workflow rules name it).

## Output

- The Step 1 answers (four short lines).
- The layer map path, and any change you made to it.
- The Step 4 table.
- The numbered order. Each piece has its "Stands on:" line (or "Stands on: nothing") and one line saying why.
- Any order you were given that this checklist changed, and why.
