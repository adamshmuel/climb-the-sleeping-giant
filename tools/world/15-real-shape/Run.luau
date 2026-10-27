--!strict
-- World prep, V2 stuck safety Task 19 onwards: the giant stands on his real shape, patched (docs/plans/v2/stuck-safety.md,
-- "How his real shape is patched"; Rule 20, One collision source).
-- Why: players must stand on the surface they see. His six body pieces first had Roblox's old collision shape, which
-- left 1332 spots where a player could get stuck. Roblox's closest match of the mesh players see (CollisionFidelity
-- PreciseConvexDecomposition) leaves about 436, and small patches and slide guards take care of the rest.
-- This file grows one section per task, each with fixed numbers, so a second run always says "already done":
--   1. His real shape (stuck safety Task 19): sets the six body pieces to PreciseConvexDecomposition.
--   2. Walk pieces (Task 24, this file's second section): V1's invisible walk pieces on his legs and belly sit on his
--      skin, or go. See "Section 2" below.
--   2b. Head (Task 25): his nose deck, his nightcap and both ladder ends sit on his skin. See "Section 2b" below.
--   2c. Zone over the nose rails (Task 25): the Beard_Ladder zone box grows 4 studs upward. See "Section 2c" below.
--   2d. Rail tops and the ladder slot (Task 25, Rulings 12 and 13): the 2 rails beside the nose become wedges with no
--       flat top, and one invisible LadderSlotBlock per side fills the slot beside the cap ladder. See "Section 2d" below.
--   2e. Beard ladder foot (Task 25, step 6b-1): the 2 beard rails grow 3.15 studs at their bottom end to touch his belly,
--       and one more rung goes in below the 16. See "Section 2e" below.
--   2f. His body follows his skin (Task 26, step 26-2): body_and_cushion becomes Tunable (the other five pieces stay
--       PreciseConvexDecomposition), and the beard ladder's climbing truss grows 2.0 studs at its bottom end. See
--       "Section 2f" below.
--   2f2. A closer fit (Task 26, step 26-4b): body_and_cushion, head_with_beard and nightcap become Tunable with
--       CollisionPrecision 1 (legs_and_boots and both arms stay PreciseConvexDecomposition until 2f5, the arms for good).
--       See "Section 2f2" below.
--   2f3. The slot blocks reach his closer skin (Task 26, step 26-4d2): both LadderSlotBlocks grow forward and down, from
--       1 x 12 x 4 to 1 x 17 x 6 (Ruling 7). See "Section 2f3" below.
--   2f4. The beard truss and the cap rails' part B (Task 26, step 26-4d4, Ruling 8): the beard ladder's invisible
--       climbing truss grows from 30 to 32 at its bottom end, and both part B SideRails end sooner (z 6.0 -> 2.5). See
--       "Section 2f4" below.
--   2f5. The legs' closer fit (Task 26, step 26-4f, Ruling 9): legs_and_boots becomes Tunable with CollisionPrecision 1
--       too (both arms stay PreciseConvexDecomposition). See "Section 2f5" below.
--   2f6. The beard truss's foot swings back (Task 26, step 26-6a1b, Ruling 12): the invisible climbing truss keeps its top
--       end and its 2 x 2 x 32 size, and its foot end moves 1.0 stud toward his beard, so a walker is only lifted where
--       he visibly touches the ladder. See "Section 2f6" below.
--   2g. Beard rails reach his drawn belly (Task 25, after the Task 26 ruling): each beard rail grows 2.75 studs at its
--       bottom end only, and one more rung, a copy of the lowest, goes in below the 17. See "Section 2g" below.
--   3a. The pillow's closer fit (Task 22, step 22-2): the pillow behind his head (World.GiantsThings.Pillow.body.body_geom)
--       becomes Tunable with CollisionPrecision 1, so a player stands on the pillow he sees. See "Section 3a" below.
--   3a2. Lit like before (Task 22, step 22-6d): the pillow's CastShadow becomes false, because the precise solid shape
--       shades the pillow itself and made it look dark navy and tan. See "Section 3a2" below.
--   3b. Patches (Task 22, step 22-9): 41 invisible blocks (Patch_Cave_<n>) in the new folder World.WalkSurfaces.Patches that
--       close off the cave under his cushion. See "Section 3b and 3c" below.
--   3c. The cave skirt (Task 22, step 22-9): 20 visible red blocks (CaveSkirt_<n>) in the new folder World.CaveSkirt across
--       the cave's mouth, solid for players. See "Section 3b and 3c" below.
--   4. Slide guards and small patches (Task 23, step 23-10): 11 invisible slide guards (SlideGuard_<Place>_<n>) in the new
--      folder World.WalkSurfaces.SlideGuards and 111 invisible small patches (Patch_<Place>_<n>, and the Sock's
--      Ramp_Sock_1) in the new folder World.WalkSurfaces.SmallPatches (Task 32 added the 20 Sock parts, Task 37 the 8
--      lip boards and 6 boxes). See "Section 4" below.
-- Section 1 does this:
--   - It refuses to run in Play: a running game can't change CollisionFidelity.
--   - It checks everything first. Each of the six body pieces (World.Giant.<piece>.<piece>, a MeshPart) must be there
--     with its recorded size and place, in the collision group Default, with CanCollide, CanQuery and CanTouch on. Any
--     difference stops the script with nothing changed and names what is wrong.
--   - It sets CollisionFidelity to PreciseConvexDecomposition on each piece that is not there yet. Nothing else about the
--     pieces changes. stray_bits_A, stray_bits_B, AwakeEyes and SleepEyes are left alone.
--   - It waits until Roblox has worked out the new shapes (it takes about 24 seconds): a few fixed rays per piece are sent
--     again every READ_EVERY seconds until two reads in a row agree, and (for a piece changed now) until its rays have
--     moved away from what they hit before the change. It gives up after MAX_WAIT seconds and says so.
--   - It reports how long the wait took.
-- Section 2 (stuck safety Task 24, "His walk pieces sit on his skin": legs and belly) does this:
--   - It checks everything first. In V1's world the 33 old pieces in World.WalkSurfaces (Boots_Walk 8, RightBoots_Walk 8, Belly_Walk 17)
--     must each match a recorded name, size and place (measured by hand in Studio on 2026-10-20), and there must be no
--     CrossingRamp_* part and no CrossingGuards folder. Any difference stops the script with nothing changed.
--   - It knows three worlds, each checked against fixed recorded numbers, and changes nothing on any difference:
--       (a) V1's world: all 33 old pieces are there (the saved place file still has them). They all go and the final
--           parts come in.
--       (b) The first run's world (an earlier version of this section ran in Studio): the step piece, CrossingRamp_Ankle
--           and its 2 guards are as recorded, and CrossingRamp_Knee (5 x 8.8 x 8.8) and Knee_Guard_1 and Knee_Guard_2 are
--           the first run's. Those three go (their old size and place are in the report) and the long knee ramp and its
--           2 guards come in.
--       (c) The final world: nothing is changed, and it says "already done".
--       (d) The final shape with the two knee guards on the material's own friction (the world after an earlier run of
--           this section): only their friction is set, and the report says so (Ruling 12).
--       Anything else stops with nothing changed. (a), (b) and (d) end in exactly the same world.
--   - Between two ChangeHistoryService waypoints it destroys the old pieces (each one's old size and place is in the
--     report) and puts in the new ones, all built away from the Workspace first:
--       * one fitted Boots_Walk "step piece" over the 1 stud step in the left boot top;
--       * CrossingRamp_Ankle and CrossingRamp_Knee: solid invisible wedges, 5 studs wide, at most 45 degrees, that sit flush
--         with the top of the wall they cross and are solid down into his skin (Rule 20, crossing ramps). The knee ramp is
--         one long wedge (Ruling 10) from his shin over the knee wall, the shelf and the steep band below Rare egg 1;
--       * the folder CrossingGuards with 2 invisible edge guards for each ramp, where the ramp's sides cross steep skin.
--     Nothing else in the place changes. The mockup folders are not touched.
--   - A second run finds the new parts exactly as recorded and says "already done".
--   - There is no third ramp (CrossingRamp_Steep): a separate 45 degree ramp flush with the top of the steep band under
--     Rare egg 1 would have to start over the knee wall (the strip of skin between the wall and the band is too narrow),
--     where nothing can hold it up. The knee ramp goes on over the band instead (Ruling 10).
-- Section 2b (stuck safety Task 25, "His nose deck, his nightcap and the ladder ends sit on his skin": his head) does this:
--   - Source: docs/plans/v2/stuck-safety.md, Task 25 and its Rulings 1 to 11 (Rule 20, One collision source; Rule 15, The
--     climb needs no jump; Rule 22, What counts as stuck). All numbers below are the plan's fixed final numbers.
--   - It refuses to run in Play, and it checks everything first: every head part under World.WalkSurfaces (Nose_Walk,
--     the 3 Nightcap_Walk, the folder ForeheadGuard, the models BeardLadder and CapLadder, 52 parts in all) must be
--     as recorded, with its recorded size, place, turn and settings.
--   - It knows two worlds, each checked against fixed recorded numbers, and changes nothing on any difference:
--       (a) V1's head (the saved place file and today's world): the 52 parts are exactly as measured in Studio on
--           2026-10-20. The change below is made.
--       (b) The final head: nothing is changed, and it says "already done". Part A may be this section's box or section
--           2d's wedge (with the 2 slot blocks); both count as the final head, and so does section 2e's longer beard
--           rails (31.85 instead of 28.70) with the 17th rung.
--       Anything else stops with nothing changed and names what differs.
--   - The change (between two ChangeHistoryService waypoints, new parts built away from the Workspace first):
--       * Nose_Walk and the 3 Nightcap_Walk go: his skin is walkable there (the nose top is under 65 degrees at body size
--         and the cap's slope is under 51), so players walk on it (Rule 20). The middle Guard of ForeheadGuard (the
--         slab, |x| under 7, rising 68.6 degrees) goes too; the four side Guards stay.
--       * V1's 2 SideRail go. 4 new invisible SideRail (2 per side) close the open nose top's sides, down into his skin:
--         part A on the nose (turned about +-14.6 degrees to follow the walkable edge) and part B beside the cap ladder.
--       * The cap ladder is re-made as shape B (the designer's pick): 71.5 degrees, 10 rungs 1.80 apart in the middle
--         of his face, from the bridge of his nose to the brim's top edge. Same rail, rung and truss as V1's, same names
--         and settings; truss 2 x 2 x 16.
--       * The beard ladder is shortened to 16 rungs, tilted to 65.3 degrees about its truss foot, and its truss and rails
--         are shortened, so its top lands on his nose. Its foot stays where it is.
--   - A second run finds the final head exactly as recorded and says "already done".
-- Run in Studio EDIT mode: this file returns a function. Rojo syncs the folder into ServerStorage.Tools.world, and
-- `return require(game:GetService("ServerStorage").Tools.world["15-real-shape"]:Clone().Run)()` runs it.
-- It runs again safely: section 1 changes nothing when all six pieces are PreciseConvexDecomposition and their rays are
-- steady (body_and_cushion, head_with_beard and nightcap may be Tunable once sections 2f and 2f2 have run, legs_and_boots
-- once 2f5 has), and sections 2, 2b, 2c, 2d, 2e, 2f, 2f2, 2f3, 2f4, 2f5, 2f6, 2g, 3a, 3a2, 3b and 3c change nothing once their parts are there; all
-- say "already done". The place
-- file must be saved by Adam afterwards, because Roblox keeps the worked-out shapes with the place.

local sectionHisRealShape = require(script.Parent.S1HisRealShape)
local sectionWalkPieces = require(script.Parent.S2WalkPieces)
local sectionHead = require(script.Parent.S2bHead)
local sectionZone = require(script.Parent.S2cZone)
local sectionRailTops = require(script.Parent.S2dRailTops)
local sectionBeardFoot = require(script.Parent.S2eBeardFoot)
local sectionBodyFollowsSkin = require(script.Parent.S2fBodyFollowsSkin)
local sectionCloserFit = require(script.Parent.S2f2CloserFit)
local sectionSlotBlocks = require(script.Parent.S2f3SlotBlocks)
local sectionTrussAndPartB = require(script.Parent.S2f4TrussAndPartB)
local sectionLegsCloserFit = require(script.Parent.S2f5LegsCloserFit)
local sectionTrussSwing = require(script.Parent.S2f6TrussSwing)
local sectionBeardBelly = require(script.Parent.S2gBeardBelly)
local sectionPillowCloserFit = require(script.Parent.S3aPillowCloserFit)
local sectionLitLikeBefore = require(script.Parent.S3a2LitLikeBefore)
local sectionPillowFlat = require(script.Parent.S3dPillowFlat)
local sectionFolderRecords = require(script.Parent.S3bcCave)
local sectionSlideGuards = require(script.Parent.S4SlideGuards)

return function(): string
	local ok, message = pcall(sectionHisRealShape)
	if not ok then
		return "STOPPED WITH AN ERROR: " .. tostring(message)
	end
	local okWalk, walkMessage = pcall(sectionWalkPieces)
	if not okWalk then
		return "SECTION 1: " .. message .. "\nSTOPPED WITH AN ERROR in section 2: " .. tostring(walkMessage)
	end
	local okHead, headMessage = pcall(sectionHead)
	if not okHead then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSTOPPED WITH AN ERROR in section 2b: "
			.. tostring(headMessage)
	end
	local okZone, zoneMessage = pcall(sectionZone)
	if not okZone then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSTOPPED WITH AN ERROR in section 2c: "
			.. tostring(zoneMessage)
	end
	local okRails, railsMessage = pcall(sectionRailTops)
	if not okRails then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSTOPPED WITH AN ERROR in section 2d: "
			.. tostring(railsMessage)
	end
	local okFoot, footMessage = pcall(sectionBeardFoot)
	if not okFoot then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSTOPPED WITH AN ERROR in section 2e: "
			.. tostring(footMessage)
	end
	local okBody, bodyMessage = pcall(sectionBodyFollowsSkin)
	if not okBody then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSTOPPED WITH AN ERROR in section 2f: "
			.. tostring(bodyMessage)
	end
	local okCloser, closerMessage = pcall(sectionCloserFit)
	if not okCloser then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSTOPPED WITH AN ERROR in section 2f2: "
			.. tostring(closerMessage)
	end
	local okSlot, slotMessage = pcall(sectionSlotBlocks)
	if not okSlot then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSTOPPED WITH AN ERROR in section 2f3: "
			.. tostring(slotMessage)
	end
	local okTruss, trussMessage = pcall(sectionTrussAndPartB)
	if not okTruss then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSTOPPED WITH AN ERROR in section 2f4: "
			.. tostring(trussMessage)
	end
	local okLegs, legsMessage = pcall(sectionLegsCloserFit)
	if not okLegs then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSTOPPED WITH AN ERROR in section 2f5: "
			.. tostring(legsMessage)
	end
	local okSwing, swingMessage = pcall(sectionTrussSwing)
	if not okSwing then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSTOPPED WITH AN ERROR in section 2f6: "
			.. tostring(swingMessage)
	end
	local okBelly, bellyMessage = pcall(sectionBeardBelly)
	if not okBelly then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSECTION 2f6: "
			.. swingMessage
			.. "\nSTOPPED WITH AN ERROR in section 2g: "
			.. tostring(bellyMessage)
	end
	local okPillow, pillowMessage = pcall(sectionPillowCloserFit)
	if not okPillow then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSECTION 2f6: "
			.. swingMessage
			.. "\nSECTION 2g: "
			.. bellyMessage
			.. "\nSTOPPED WITH AN ERROR in section 3a: "
			.. tostring(pillowMessage)
	end
	local okLit, litMessage = pcall(sectionLitLikeBefore)
	if not okLit then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSECTION 2f6: "
			.. swingMessage
			.. "\nSECTION 2g: "
			.. bellyMessage
			.. "\nSECTION 3a: "
			.. pillowMessage
			.. "\nSTOPPED WITH AN ERROR in section 3a2: "
			.. tostring(litMessage)
	end
	local okFlat, flatMessage = pcall(sectionPillowFlat)
	if not okFlat then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSECTION 2f6: "
			.. swingMessage
			.. "\nSECTION 2g: "
			.. bellyMessage
			.. "\nSECTION 3a: "
			.. pillowMessage
			.. "\nSECTION 3a2: "
			.. litMessage
			.. "\nSTOPPED WITH AN ERROR in section 3d: "
			.. tostring(flatMessage)
	end
	local okCave, caveMessage = pcall(sectionFolderRecords)
	if not okCave then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSECTION 2f6: "
			.. swingMessage
			.. "\nSECTION 2g: "
			.. bellyMessage
			.. "\nSECTION 3a: "
			.. pillowMessage
			.. "\nSECTION 3a2: "
			.. litMessage
			.. "\nSECTION 3d: "
			.. flatMessage
			.. "\nSTOPPED WITH AN ERROR in sections 3b and 3c: "
			.. tostring(caveMessage)
	end
	local okGuards, guardsMessage = pcall(sectionSlideGuards)
	if not okGuards then
		return "SECTION 1: "
			.. message
			.. "\nSECTION 2: "
			.. walkMessage
			.. "\nSECTION 2b: "
			.. headMessage
			.. "\nSECTION 2c: "
			.. zoneMessage
			.. "\nSECTION 2d: "
			.. railsMessage
			.. "\nSECTION 2e: "
			.. footMessage
			.. "\nSECTION 2f: "
			.. bodyMessage
			.. "\nSECTION 2f2: "
			.. closerMessage
			.. "\nSECTION 2f3: "
			.. slotMessage
			.. "\nSECTION 2f4: "
			.. trussMessage
			.. "\nSECTION 2f5: "
			.. legsMessage
			.. "\nSECTION 2f6: "
			.. swingMessage
			.. "\nSECTION 2g: "
			.. bellyMessage
			.. "\nSECTION 3a: "
			.. pillowMessage
			.. "\nSECTION 3a2: "
			.. litMessage
			.. "\nSECTION 3d: "
			.. flatMessage
			.. "\nSECTIONS 3b and 3c: "
			.. caveMessage
			.. "\nSTOPPED WITH AN ERROR in section 4: "
			.. tostring(guardsMessage)
	end
	return "SECTION 1 (his real shape): "
		.. message
		.. "\n\nSECTION 2 (walk pieces): "
		.. walkMessage
		.. "\n\nSECTION 2b (his head): "
		.. headMessage
		.. "\n\nSECTION 2c (zone over the nose rails): "
		.. zoneMessage
		.. "\n\nSECTION 2d (rail tops and the ladder slot): "
		.. railsMessage
		.. "\n\nSECTION 2e (the beard ladder's foot): "
		.. footMessage
		.. "\n\nSECTION 2f (his body follows his skin): "
		.. bodyMessage
		.. "\n\nSECTION 2f2 (a closer fit): "
		.. closerMessage
		.. "\n\nSECTION 2f3 (the slot blocks reach his closer skin): "
		.. slotMessage
		.. "\n\nSECTION 2f4 (the beard truss 32 long, part B ends sooner): "
		.. trussMessage
		.. "\n\nSECTION 2f5 (the legs' closer fit): "
		.. legsMessage
		.. "\n\nSECTION 2f6 (the beard truss's foot swings back): "
		.. swingMessage
		.. "\n\nSECTION 2g (the beard rails reach his drawn belly): "
		.. bellyMessage
		.. "\n\nSECTION 3a (the pillow's closer fit): "
		.. pillowMessage
		.. "\n\nSECTION 3a2 (lit like before): "
		.. litMessage
		.. "\n\nSECTION 3d (the pillow laid flat and sunk under his head): "
		.. flatMessage
		.. "\n\nSECTIONS 3b and 3c (the cave's patches and the cave skirt): "
		.. caveMessage
		.. "\n\nSECTION 4 (slide guards and small patches): "
		.. guardsMessage
end
