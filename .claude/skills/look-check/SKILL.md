---
name: look-check
description: The before-and-after check that proves a change did not make the game look worse - fixed cameras on computer and phone, before and after shots, and the designer's side-by-side verdict. Use for any task that changes something the player can see (a part, a model, a color, a light, a button), including safety, fit and route fixes, and when planning or budgeting such a task.
---

# Look check: a look never gets worse

Any task that changes something the player can see proves it didn't make the game look worse. This covers fixes too, not only look tasks.

## Steps

1. **Fixed cameras.** `designer` keeps one list per version in `docs/design/<version>/look-cameras.md`:
   - the wide view a new player first sees;
   - the main character's face;
   - each spawn view;
   - a "player's spot" row for anything players walk on or in, taken from where they stand on it and facing the way the approved mockup faces;
   each with its exact camera position and field of view, on computer and phone. It writes the list the first time a task needs it.
2. **Before shots.** Before the first world change, take every fixed camera that shows the changed area, on computer and phone. Save them in `work/<task>/look-before/`.
3. **After shots.** After the change, take the same shots from the same cameras into `work/<task>/look-after/`. Close-ups may be added, never instead of the fixed shots.
4. **Designer judges side by side, inside the same task, before `code_lead` approves it.** For each pair: **same or better**, or **worse**, with the reason. One "worse" sends the change back, even if every test passes. Saving time is never a reason to accept a worse look. For a change on or beside a main character, the designer also gets `SunkParts.spec`'s rows (path, position, worst depth) with the shots, and a new row there counts as "worse".
5. **The plan budgets it.** `code_lead` adds the before shots, after shots and the designer check to the steps and caps of every such task.
6. **Never cut a fixed camera.** Before cutting any shot or check, grep `look-cameras.md` and the spec's proof lists. A fixed camera or a listed proof moves to another task, never out; only `designer` removes a camera.

A "worse" on a main character or on the first view is a red alert: use the `stop-and-step-back` skill.

## Choosing between looks

When the choice is between looks or ways to play, `designer` mocks up each option from the fixed cameras (computer and phone), and `game_creator` and `product` judge them side by side before anyone picks. A choice made from words alone is not finished.

## Shots

- Use `screen_capture`, and the device simulator for phone. Anything that only exists in Play is shot in Play.
- Take fixed-camera shots with the ready-made [shots job](shots-job.md), in Edit and in Play: only `screen_capture`'s own `camera_position` and `look_at_position` place the camera. A camera set by script doesn't show in the shot. The job's last step compares each after shot with its before shot, before the designer judges.
- Judge a shot only with what this version really spawns. A stand-in from a later version is named as such and judged in that version's check. Check a copied library model's `Transparency` before the shot: library copies can be stored hidden.
- Judge the whole screen (`playing-the-game` skill, step 7).
- Aim so the target sits at the wanted screen y; a phone sees only about 35° below the view centre. A Play proof recreates the bug shot's camera position and target.
