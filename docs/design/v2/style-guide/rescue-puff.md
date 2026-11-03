# The rescue puff (V2 spec 2, Rule 33: What a rescue looks like)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`.

When the game moves a stuck player back to a safe spot, or a Reset on the giant puts them back, the player sees a **soft puff of sleepy lavender cloud with gold sparkles**. One puff plays where they vanish and one where they appear, both at the same moment. There's no text, no card and no screen flash. It should feel like the giant's sleep magic tucking them back, not like a punishment.

| What | Value | Why |
|---|---|---|
| Where | Two puffs, both in the world: one at the spot they left, one at the safe spot they land on. Everyone nearby sees them. | The player sees where they were and where they are now. Other players see why someone suddenly moved. |
| When | Both start at the same moment as the move. Each lasts under 1 second. | The move is instant, so the puffs hide the jump. |
| Cloud | Roblox's built-in smoke texture (`rbxasset://textures/particles/smoke_main.dds`). 30 puffs at the landing spot, 22 at the old spot. Colour fades from `#E6EAFF` to sleep lavender `#9AA8F5`. Size grows from 2.5 to 6 studs. Starts 5% see-through and fades to fully clear. Lifetime 0.5 to 0.8 s, speed 5 to 9, drag 4, no glow (light emission 0). | Tested in Studio: a **white** puff vanished on his white beard. A brighter, glowing puff washed out to plain white. Lavender with no glow reads on the beard, on the blue belly and on grass. Lavender also matches the sleep colour of the meter and Tiptoe. |
| Sparkles | Roblox's built-in sparkle texture (`rbxasset://textures/particles/sparkles_main.dds`). 18 at the landing spot, 14 at the old spot. Gold `#FFC93C`, size 1.4 shrinking to 0.5 studs, light emission 0.6, lifetime 0.6 to 0.9 s, speed 6 to 10. Drawn a little in front of the cloud (Z offset 2). | The gold sparkles are what the eye catches first, even next to a glowing Rare egg. |
| Landing puff shape | Comes out of a short cylinder (3 × 4 × 3 studs) around the player's body, pushed outwards. | A ring around the body, so the player stays visible inside it. |
| Sound | One soft "poof". The sound itself comes in V2 spec 7 (Audio). | |
| Screen | Nothing changes. The meter, Tiptoe and the carry pill stay as they were, and the bottom corners stay free. | A rescue isn't news the player has to read. |

Mockups: `mockups/rescue-desktop.png` and `mockups/rescue-phone.png`. The phone views use a wider camera shot (field of view 80, then cropped) so the crop shows what a phone sees at Roblox's normal view.
