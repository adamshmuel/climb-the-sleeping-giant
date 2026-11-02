# Look cameras (V2)

The fixed cameras for every before-and-after look check. A task that changes something the player can see takes the cameras that show the changed area, before and after, from exactly these spots. Close-ups can be added, but never replace these.

Measured in Studio (Edit mode) on 2026-11-02.

## How to take a shot

| Screen | How |
|---|---|
| Computer | Studio window at 1280 x 720. Field of view (how wide the camera sees) 70, which is the game's own value: never change it. In Edit mode, `screen_capture` with the camera position and look-at point below. |
| Phone | Play with the device simulator on a landscape phone of 844 x 390 (for example iPhone 14). Field of view stays 70. On the client, set `workspace.CurrentCamera.CameraType` to `Scriptable` and its `CFrame` to `CFrame.lookAt(position, lookAt)` from the table, take `screen_capture`, then set `CameraType` back to `Custom`. |

- Same camera, same screen size, same time of day for "before" and "after". Hide mockup folders (`Workspace.Mockup_*`) in both shots or in neither.
- Save the shots in `work/<task>/look-before/` and `work/<task>/look-after/`, named `<camera>-computer.jpg` and `<camera>-phone.jpg`.

## The cameras

| Name | What it shows | Camera position | Looks at |
|---|---|---|---|
| `meadow-wide` | **The first view a new player sees, and the thumbnail angle.** The whole giant from in front of garden gate 5: his face, beard, belly, boots and the boot ladders. Same camera as `work/t58b/upright-spawn-view.png` | (33.6, 12.4, -139.5) | (0, 80, -10) |
| `meadow-front` | The whole giant straight from the front, from the meadow between gates 4 and 5 | (0, 14, -160) | (0, 70, 0) |
| `face` | **The giant's face**, close and straight on: closed eyes, nose, cheeks, the lower cap and the top of the beard. Nothing stands between the camera and the face ladders | (0, 100, -75) | (0, 97, -6) |
| `gate-1` | Spawn view from garden gate 1 (far left): the side of his head and his left arm | (-142.2, 3.9, 11.7) | (-38.0, 44.2, -1.3) |
| `gate-2` | Spawn view from garden gate 2 | (-132.0, 4.5, -54.1) | (-33.3, 44.8, -18.1) |
| `gate-3` | Spawn view from garden gate 3 | (-92.9, 4.0, -108.2) | (-22.3, 44.3, -30.5) |
| `gate-4` | Spawn view from garden gate 4 | (-33.4, 3.9, -138.7) | (-7.8, 44.2, -36.9) |
| `gate-5` | Spawn view from garden gate 5 | (33.4, 3.9, -138.7) | (7.8, 44.3, -36.9) |
| `gate-6` | Spawn view from garden gate 6 | (92.9, 3.9, -108.2) | (22.3, 44.2, -30.5) |
| `gate-7` | Spawn view from garden gate 7 | (132.0, 4.5, -54.1) | (33.3, 44.8, -18.1) |
| `gate-8` | Spawn view from garden gate 8 (far right): the side of his head and his right arm | (142.2, 3.9, 11.7) | (38.0, 44.2, -1.3) |
| `tie-top-side` | Close-up of the left cap tie's top rows and the fold, from outside his left ear and a little behind. It shows a climber halfway up the leaning rows (about y 100) and one standing at the top. The sight lines were measured clear. For the right tie, use x 52 and look at x 32 | (-52, 107, 42) | (-32, 105, 32) |
| `tie-top-front` | The same rows seen from the ear side, so you see the climber's side view: is the climber close to the strap or floating beside it, and does anything stick out toward the ear? The sight lines were measured clear. For the right tie, use x 46 and look at x 32 | (-46, 106, 14) | (-32, 105, 32) |

### How the gate cameras were worked out

- Each gate's spot is its `SpawnSpot` in `Workspace.World.Plots.Plot_<n>`, with the player's feet on its top.
- The camera sits where Roblox's camera starts at spawn: 12.5 studs from a point 6 studs above the feet, tilted 21 degrees up, turned toward his face at (0, 97, -6). This is the same spawn view the V2 mockups used (`build-check.md`).
- The real spawn camera eases back after a moment. For that reason the before-and-after shots use these fixed spots, not a live Play camera.

## Which cameras to take

| What changes | Cameras |
|---|---|
| Anything on his face, beard, nose, forehead or cap (for example the face ladders) | `meadow-wide`, `meadow-front`, `face`, `gate-4`, `gate-5` |
| His belly, boots or the ways up to the belly | `meadow-wide`, `meadow-front`, and the gate cameras that face that side |
| His sides, arms or cuffs | `meadow-wide`, plus `gate-1` to `gate-3` (left) or `gate-6` to `gate-8` (right) |
| The meadow, the gardens or the light | `meadow-wide`, plus every gate camera |
| How a climber looks on a cap tie (taken in Play, with the climber held in place) | `tie-top-side`, `tie-top-front` |

## Not found

Adam's old wide meadow phone shot (the "before" he compared) has no saved camera. `meadow-wide` is the closest saved camera: it is the gate 5 spawn and thumbnail angle used for every face check since Task 58b.
