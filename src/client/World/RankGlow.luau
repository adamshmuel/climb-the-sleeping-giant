--!strict
-- The rank glow's numbers (spec 4 Rule 52; style guide egg-ranks.md, "The rank glow"). Pure: no Roblox services
-- besides the Config type. The glow is a halo of 12 see-through rings behind a waiting egg; it hides up close and fades
-- in with distance, so a kid sees the rank from far away.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type RankColors = { edge: Color3, centre: Color3 }

local RankGlow = {}

-- Hidden at or below this many studs, full strength at or above FULL_FROM, a straight line between.
RankGlow.HIDE_WITHIN = 55
RankGlow.FULL_FROM = 75
RankGlow.RING_COUNT = 12

-- Ring 1 is full size, the last ring this share of it.
local SMALLEST_RING = 0.45

-- Ring strength worked back from the style guide's ring see-through (89.6%, 88.3%, 87.6%): 1 - see-through.
local STRENGTH: { [string]: number } = {
	Common = 0,
	Uncommon = 0.104,
	Rare = 0.117,
	Epic = 0.124,
	Legendary = 0.124,
}

local COLORS: { [string]: RankColors } = {
	Uncommon = { edge = Color3.fromHex("5BD45B"), centre = Color3.fromHex("E4FFDC") },
	Rare = { edge = Color3.fromHex("3FA9FF"), centre = Color3.fromHex("E6F6FF") },
	Epic = { edge = Color3.fromHex("B05CFF"), centre = Color3.fromHex("F3E3FF") },
	Legendary = { edge = Color3.fromHex("FFC93C"), centre = Color3.fromHex("FFF6D6") },
}

function RankGlow.fade(distance: number): number
	return math.clamp((distance - RankGlow.HIDE_WITHIN) / (RankGlow.FULL_FROM - RankGlow.HIDE_WITHIN), 0, 1)
end

function RankGlow.hasGlow(rank: Config.RarityName): boolean
	return COLORS[rank] ~= nil
end

function RankGlow.strength(rank: Config.RarityName): number
	return STRENGTH[rank] or 0
end

-- The halo is twice the egg's height across.
function RankGlow.size(eggHeight: number): number
	return eggHeight * 2
end

function RankGlow.ringTransparency(rank: Config.RarityName, distance: number): number
	return 1 - RankGlow.strength(rank) * RankGlow.fade(distance)
end

function RankGlow.ringScale(index: number): number
	local along = (index - 1) / (RankGlow.RING_COUNT - 1)
	return 1 - (1 - SMALLEST_RING) * along
end

function RankGlow.colors(rank: Config.RarityName): RankColors?
	return COLORS[rank]
end

-- Ring 1 (the biggest) is the edge colour, the last ring the centre colour, blended between.
function RankGlow.ringColor(rank: Config.RarityName, index: number): Color3?
	local colors = COLORS[rank]
	if colors == nil then
		return nil
	end
	return colors.edge:Lerp(colors.centre, (index - 1) / (RankGlow.RING_COUNT - 1))
end

return RankGlow
