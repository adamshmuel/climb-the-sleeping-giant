# Build check: Sneak the Nest

Can a beginner build what each image shows in Roblox Studio? One row per image in `mockups/`.

All scenes are real Studio screenshots of the mockup scene in `Workspace.Mockup_sneak-the-nest` (built 2026-10-07, revised the same day). So everything in them can be built in Studio. The question for each row is how hard it is for a beginner.

## Features shared by several images

| Feature | Roblox features needed | Beginner difficulty |
|---|---|---|
| Oval eggs | `Part` with a `SpecialMesh` (`MeshType = Sphere`), taller than wide | easy |
| Egg glow | `PointLight` inside the egg; `Highlight` (outline only) in the rarity color for Uncommon and above | easy |
| Rarity patterns | small parts placed on the egg and grouped in one `Model` per tier: white `Ball` spots (Uncommon), white `Cylinder` rings (Rare stripes), crossed thin `Neon` blocks (Epic stars), gold `Cylinder` band with spike blocks and a gem (Legendary crown). Build each tier once, then copy it. A `Decal` was not used, because a decal on a stretched sphere mesh projects onto the flat box faces and looks smeared | medium |
| Carried egg | the same egg model, smaller (1.6 × 2.5 studs), welded to the player's back with a strap part | medium |
| Clouds below the cliffs | a flat pale floor part and about 260 soft `Ball` puffs; 8 large lilac `Ball` hills far away | easy |
| Sunset sky | `Lighting` and `Atmosphere` values listed in `style-guide.md`, Roblox's default `Sky` | easy |

## Images

| Image | Roblox features needed | Beginner difficulty | Differences |
|---|---|---|---|
| `concept-nest.png` | rock and island `Cylinder` parts (`Rock`, `Grass`); about 200 `Wood` cylinder twigs; `WoodPlanks` bridges with rope cylinders; `Neon` safe lines; sleeping giant from `Ball` parts; patterned eggs; `BillboardGui` noise meter and "zZZ"; clouds; sunset lighting | medium | Players stand in fixed poses; in the game they move with animations. |
| `gameplay-wake.png`: wake pose swap | second giant model (standing, arms out, open eyes and mouth from flat discs, cross brows); a script hides the sleeping giant and shows the awake one; `BillboardGui` "!"; meter `UIGradient` switched to red | medium | Shown as one frozen moment. |
| `gameplay-wake.png`: chase | a script moves the awake giant out of the nest toward players carrying eggs and stops it at the safe lines; dust puffs (`Ball` parts or a `ParticleEmitter`) under the feet; red edge glow as a full-screen `ImageLabel` or `Frame` + `UIGradient` | **hard** | The red edge glow was added as an overlay after the Studio capture (`wake.html`). Screen shake and the music change can't be seen in a still image. |
| `gameplay-hatch.png` | incubator (`Cylinder` base); broken striped shell (`Ball` + zigzag blocks, `Neon`); flying top shell; light rays (thin `Neon` parts); `PointLight`; `ParticleEmitter` sparkles; baby-bird pet from `Ball` parts; pet pads; cash chest (wood box, gold trim, open lid, gold mound); flat gold coin discs outlined with a `Highlight`; `BillboardGui` "+12" | medium | The hatch is frozen at its peak. In the game the egg wobbles, cracks and pops over about a second (tweens or a script). The glass dome is removed for this shot. |
| `hud-desktop.png` | `ScreenGui`; `Frame`, `TextLabel`, `TextButton`, `ImageLabel`; `UICorner`; `UIStroke` (2–3 px on button words); `UIGradient`; `Enum.Font.FredokaOne`; icons as uploaded images; reward dot as a round `Frame` | easy | Built in HTML for the mockup, with web fonts standing in for Roblox's (Fredoka for FredokaOne, Nunito for Builder Sans). The background is a Studio shot without the in-world meter, so it doesn't double up with the HUD meter. |
| `hud-phone.png` | same as desktop, plus `UIAspectRatioConstraint` and a `UIGridLayout` (2 × 2 buttons); Roblox's built-in thumbstick and jump button | easy | The thumbstick and jump button are drawn as faint circles only to show the free corners. Hiding the objective in the nest needs a small script that checks where the player is. |
| `icon.png` | same scene as the concept; one player close to the camera in a crouched tiptoe pose with a striped Rare egg on its back and a worried face (`FaceControls`); the giant's face with the half-open eye and "zZZ" behind | easy (once the scene exists) | Cut from a 1920 × 1053 capture and shrunk to 512 × 512. At 150 px the player, the egg and the giant's face read; the peeking eye is small. |
| `thumbnail-sneak.png` | same scene as the concept; 5 players in a crouched tiptoe pose, 3 with patterned eggs on their backs, 2 turned three-quarters toward the camera with scared faces (`FaceControls`); noise meter nearly red; one eye peeking; title added afterwards (`thumbnail.html`) | easy (once the scene exists) | Captured at the Studio window size (1920 × 1053), cropped to 16:9 (1872 × 1053) and enlarged about 3% to 1920 × 1080. A sharp final thumbnail is a later production task. |

## Helper files (not separate mockups)

- `hud.html`, `hud-bg.png`: the HUD page and its Studio background.
- `thumbnail.html`, `thumbnail-shot.png`: the title overlay page and the raw Studio shot under it.
- `wake.html`, `wake-shot.png`: the red edge-glow overlay page and the raw Studio shot under it.
