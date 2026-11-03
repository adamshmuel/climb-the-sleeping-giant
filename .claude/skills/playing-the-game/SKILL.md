---
name: playing-the-game
description: How an agent plays the built game in Studio like a real player - start Play, move with the player's controls only, whole sessions on computer and phone, screenshots and console. Use before judging, reviewing or approving anything the player sees or does.
---

# Playing the game

Nobody approves what they haven't seen in the running game. Reading code and passing tests is not enough. Each reviewer plays the same way and judges with its own lens.

## Tools

| Need | Studio tool |
|---|---|
| Find Studio | `list_roblox_studios`, then `get_studio_state`. If none is connected, stop and say so. |
| Start and stop | `start_stop_play` |
| Move and press | `character_navigation` to walk, `user_keyboard_input` and `user_mouse_input` for keys and buttons |
| See the real play screen | `screen_capture` (during Play it shows the screen a player sees, buttons included) |
| Errors | `get_console_output` |
| Phone screen | Studio's device simulator: the phone calls in the `look-check` skill's [shots job](../look-check/shots-job.md) (steps 5 and 7) |
| Only what playing can't show | `script_read`, `script_grep`, `search_game_tree`, `inspect_instance` |

`execute_luau` is only for test setup: muting the sound, switching the device simulator, starting or stopping test helpers. Never use it to move the character, change the game, or read hidden state to decide what to do.

## Steps

1. **Start Play** (mute the sound if the prompt says so).
2. **Move only with the player's controls.** Never move the character or change the game with scripts.
3. **Play whole sessions, not single checks.** Find out what to do from the screen alone. Try what a player would: win, lose, get greedy, try again, keep going past the first goal.
4. **Computer and phone.** Play on a computer screen and on a phone screen.
5. **Every state it touches:** each area, each phase of an enemy or event, carrying an item, being caught or defeated.
6. **Screenshots all the time,** and always at each new spot and state. A report names what each one shows.
   `screen_capture` doesn't draw billboards with `AlwaysOnTop` true (for example the grab pill). A missing billboard in a shot is never called a bug until a shot with its `AlwaysOnTop` set to false during Play (never in `src/`) still misses it.
7. **Judge the whole screen,** not only the part that changed: something covering the main character, text cut off at an edge, or buttons on top of each other are problems even if no rule names them.
8. **Read the console** for errors and warnings, then stop Play and put back any setup you changed.

If a tool can't do something (for example, it can't capture the screen), say so in the report. Never mark it as passed, and never push the check to "later".

## Phone presses

- Aim a phone press or thumbstick at its game point (AbsolutePosition plus half AbsoluteSize) plus an offset measured on the phone in use. The (47, 0) offset and the "shot scaled about 1.44 times" were measured on the old phone device; re-measure both on `Phone_844x390` before relying on them. Never aim from the shot's picture and never add the top bar.
- A button on a billboard: its position is inside the billboard, not on the screen. Aim at the anchor's screen point (`Camera:WorldToViewportPoint`) plus the button's offset, with the camera held still, or pin the button first.
- Before any touch on a billboard, set `AlwaysOnTop` back to its built value. Turning it off is only for shot jobs with no input; with it off, the touch lands on the world.
- Before judging a press that "did nothing", log where it landed with an input listener that only records.

## Lenses

Each reviewer plays the same way but looks for its own things:

| Reviewer | Looks for |
|---|---|
| `product_reviewer` | the new player and the spec: what confuses, blocks, bores or hurts a player, then each rule |
| `game_creator` | the first impression next to the top games, the fun of the core loop, and the business |
| `designer` | the look against the mockups, the style guide and the top games |
