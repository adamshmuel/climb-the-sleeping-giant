--!strict
-- How much noise one player makes. Pure maths: it is given what the player is doing and returns numbers.
-- Every number comes from Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type NoiseInput = {
	zone: Config.ZoneName,
	garden: number?, -- set when the player is inside any garden
	moving: boolean,
	tiptoe: boolean,
	carrying: Config.RarityName?,
	onLadder: boolean?, -- on a climbing ladder; a little louder (spec 3 Rule 39)
}

local Noise = {}

function Noise.perSecond(input: NoiseInput): number
	if input.garden ~= nil or not input.moving then
		return 0
	end
	local carryFactor = 1
	if input.carrying ~= nil then
		carryFactor = Config.Rarity[input.carrying].CarryNoise
	end
	local tiptoeFactor = 1
	if input.tiptoe then
		tiptoeFactor = Config.Noise.TiptoeFactor
	end
	local ladderFactor = 1
	if input.onLadder == true then
		ladderFactor = Config.Noise.LadderMultiplier
	end
	return Config.Noise.WalkPerSecond
		* Config.Noise.ZoneMultiplier[input.zone]
		* carryFactor
		* tiptoeFactor
		* ladderFactor
end

-- The one-off burst (a thud) when a jump or fall ends. `zone` is the highest zone the fall left, not where it
-- ended (see LandingDetector). Nothing where it ended in a garden, and nothing for the meadow.
function Noise.jumpBurst(zone: Config.ZoneName, garden: number?): number
	if garden ~= nil or zone == "Meadow" then
		return 0
	end
	return Config.Noise.JumpBurst * Config.Noise.ZoneMultiplier[zone]
end

return Noise
