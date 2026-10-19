--!strict
-- Questions about how rare an egg is. Pure: it only reads the order of the rarities in Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Rarity = {}

-- Is this egg a Rare, or rarer than a Rare? Anything that isn't a rarity name is false. Epic and Legendary count as
-- soon as they are added to Config.RarityOrder after Rare, with no change here.
function Rarity.isRareOrRarer(name: string): boolean
	-- The order runs from the commonest to the rarest, so "Rare or rarer" is Rare's place in the list or any later one.
	local reachedRare = false
	for _, rarity in Config.RarityOrder do
		if rarity == "Rare" then
			reachedRare = true
		end
		if reachedRare and rarity == name then
			return true
		end
	end
	return false
end

return Rarity
