--!strict
-- Shows the egg on each egg spot and takes it away again, and writes the spot's Waiting attribute so every client can
-- read it. Nothing writes RefillAt any more (Task 7b: an empty nest shows no timer); show clears an old one.
-- The spot decides nothing here: Grab says when an egg is there, and this module only draws it.
-- A meadow spot also has a flat glow ring (GlowRing) under the egg: show sets it to the waiting look. The labels are
-- drawn by each player's own client (SpotLabels), from the Waiting attribute.

local WorldIndex = require(script.Parent.Parent.World.WorldIndex)

export type SpotModels = {
	-- Puts a copy of the spot's egg on it (the only one), and sets Waiting to true and RefillAt to nothing.
	show: (self: SpotModels, spotName: string) -> (),
	-- Takes the egg off the spot and sets Waiting to false. An empty nest shows no timer, so it writes no RefillAt and
	-- leaves the glow ring as it is.
	hide: (self: SpotModels, spotName: string) -> (),
	-- Takes every egg away.
	destroy: (self: SpotModels) -> (),
}

-- The name of the egg model on a spot, and of a meadow spot's glow ring.
local EGG_NAME = "Egg"
local RING_NAME = "GlowRing"

local SpotModels = {}

-- How see-through the glow ring is: 60% with an egg waiting, 85% on an empty spot (spec section 6, "Empty egg spot").
-- Exported so the real-world test checks the same numbers.
SpotModels.WAITING_RING_TRANSPARENCY = 0.6
SpotModels.EMPTY_RING_TRANSPARENCY = 0.85

function SpotModels.new(spots: { WorldIndex.EggSpot }, templates: WorldIndex.EggTemplates): SpotModels
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

	local models: SpotModels
	models = {
		show = function(_self, spotName)
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
			egg.Parent = spot.model
			setRing(spot, SpotModels.WAITING_RING_TRANSPARENCY)
			spot.model:SetAttribute("Waiting", true)
			spot.model:SetAttribute("RefillAt", nil)
		end,
		hide = function(_self, spotName)
			local spot = find(spotName)
			removeEgg(spot)
			spot.model:SetAttribute("Waiting", false)
		end,
		destroy = function(_self)
			for _, spot in spots do
				removeEgg(spot)
			end
		end,
	}
	return models
end

return SpotModels
