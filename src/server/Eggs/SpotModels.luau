--!strict
-- Shows the egg on each egg spot and takes it away again, and writes the spot's Waiting attribute so every client can
-- read it. Nothing writes RefillAt any more (Task 7b: an empty nest shows no timer); show clears an old one.
-- A meadow spot may also have an invisible EggPost (a folder of parts, Rule 85): solid while its egg waits and no player
-- stands close (PostClear), never solid without an egg.
-- The spot decides nothing here: Grab says when an egg is there, and this module only draws it.
-- A meadow spot also has a flat glow ring (GlowRing) under the egg: show sets it to the waiting look. The labels are
-- drawn by each player's own client (SpotLabels), from the Waiting attribute.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PostClear = require(script.Parent.PostClear)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)

export type SpotModels = {
	-- Puts a copy of the spot's egg on it (the only one), and sets Waiting to true and RefillAt to nothing. Its EggPost
	-- turns solid unless a root in `playersAt` (none if nil) is close; then it turns solid on a later `step`.
	show: (self: SpotModels, spotName: string, playersAt: { Vector3 }?) -> (),
	-- Turns solid every EggPost that `show` left blocked and that no root in `playersAt` is close to now.
	step: (self: SpotModels, playersAt: { Vector3 }) -> (),
	-- Takes the egg off the spot, makes its EggPost not solid and sets Waiting to false. An empty nest shows no timer, so it writes no RefillAt and
	-- leaves the glow ring as it is.
	hide: (self: SpotModels, spotName: string) -> (),
	-- Writes the spot's Locked attribute (a right cuff nest locks while he is awake, Rule 100). The egg stays as it is.
	setLocked: (self: SpotModels, spotName: string, locked: boolean) -> (),
	-- Takes every egg away.
	destroy: (self: SpotModels) -> (),
}

-- The name of the egg model on a spot, and of a meadow spot's glow ring.
local EGG_NAME = "Egg"
local RING_NAME = "GlowRing"
local POST_NAME = "EggPost"

local SpotModels = {}

-- Shortens the egg's beam so its two attachments are `studs` apart in the world, keeping its direction. A copy of the
-- egg only: the template is never changed. An egg with no beam is left alone.
local function shortenBeam(egg: Model, studs: number)
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("Beam") then
			local bottom = descendant.Attachment0
			local top = descendant.Attachment1
			local part = if top then top.Parent else nil
			if bottom ~= nil and top ~= nil and part ~= nil and part:IsA("BasePart") then
				local along = top.WorldPosition - bottom.WorldPosition
				if along.Magnitude > 0 then
					top.Position = part.CFrame:PointToObjectSpace(bottom.WorldPosition + along.Unit * studs)
				end
			end
		end
	end
end

-- How see-through the glow ring is: 60% with an egg waiting, 85% on an empty spot (spec section 6, "Empty egg spot").
-- Exported so the real-world test checks the same numbers.
SpotModels.WAITING_RING_TRANSPARENCY = 0.6
SpotModels.EMPTY_RING_TRANSPARENCY = 0.85

function SpotModels.new(
	spots: { WorldIndex.EggSpot },
	templates: WorldIndex.EggTemplates,
	zoneOf: ((position: Vector3) -> Config.ZoneName)?
): SpotModels
	local spotByName: { [string]: WorldIndex.EggSpot } = {}
	for _, spot in spots do
		spotByName[spot.name] = spot
	end

	local function find(spotName: string): WorldIndex.EggSpot
		local spot = spotByName[spotName]
		if spot == nil then
			error(`unknown egg spot: {spotName}`, 3)
		end
		return spot
	end

	-- Removes the egg on a spot, if it has one.
	local function removeEgg(spot: WorldIndex.EggSpot)
		local egg = spot.model:FindFirstChild(EGG_NAME)
		if egg ~= nil then
			egg:Destroy()
		end
	end

	-- Sets the spot's glow ring, if it has one (only the meadow spots do).
	local function setRing(spot: WorldIndex.EggSpot, transparency: number)
		local ring = spot.model:FindFirstChild(RING_NAME)
		if ring ~= nil and ring:IsA("BasePart") then
			ring.Transparency = transparency
		end
	end

	-- Makes every part of the spot's EggPost solid or not. A spot with no EggPost does nothing.
	local function setPostSolid(spot: WorldIndex.EggSpot, solid: boolean)
		local post = spot.model:FindFirstChild(POST_NAME)
		if post == nil then
			return
		end
		for _, part in post:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = solid
			end
		end
	end

	-- Spots whose egg waits but whose post is still off because a player was close.
	local blocked: { [string]: boolean } = {}

	local models: SpotModels
	models = {
		show = function(_self, spotName, playersAt)
			local spot = find(spotName)
			removeEgg(spot)
			local egg = templates[spot.rarity]:Clone()
			egg.Name = EGG_NAME
			-- An egg that is not anchored would fall through the world and be deleted. The egg keeps its light, sparkles
			-- and beam, but not its label: every client draws its own label (SpotLabels).
			for _, descendant in egg:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
				elseif descendant:IsA("BillboardGui") then
					descendant:Destroy()
				end
			end
			egg:PivotTo(spot.cframe)
			-- Eggs on his body (belly, beard, nightcap) get a short beam, so a column of light doesn't wash the screen.
			if zoneOf ~= nil and Config.Ranks.BodyZones[zoneOf(spot.cframe.Position)] then
				shortenBeam(egg, Config.Ranks.BodyBeamStuds)
			end
			egg.Parent = spot.model
			setRing(spot, SpotModels.WAITING_RING_TRANSPARENCY)
			spot.model:SetAttribute("Waiting", true)
			spot.model:SetAttribute("RefillAt", nil)
			if PostClear.blocked(spot.cframe.Position, playersAt or {}) then
				blocked[spotName] = true
				setPostSolid(spot, false)
			else
				blocked[spotName] = nil
				setPostSolid(spot, true)
			end
		end,
		step = function(_self, playersAt)
			for spotName in blocked do
				local spot = find(spotName)
				if not PostClear.blocked(spot.cframe.Position, playersAt) then
					blocked[spotName] = nil
					setPostSolid(spot, true)
				end
			end
		end,
		hide = function(_self, spotName)
			local spot = find(spotName)
			removeEgg(spot)
			blocked[spotName] = nil
			setPostSolid(spot, false)
			spot.model:SetAttribute("Waiting", false)
		end,
		setLocked = function(_self, spotName, locked)
			find(spotName).model:SetAttribute("Locked", locked)
		end,
		destroy = function(_self)
			for _, spot in spots do
				removeEgg(spot)
				setPostSolid(spot, false)
			end
			table.clear(blocked)
		end,
	}
	return models
end

return SpotModels
