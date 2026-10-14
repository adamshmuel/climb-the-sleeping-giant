--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlayerInfo = require(ServerScriptService.Server.Players.PlayerInfo)

-- A stand-in for a Player: a name, a display name, an id and some attributes.
local function fakePlayer(attributes: { [string]: any }, displayName: any?)
	return {
		UserId = 7,
		Name = "Mia",
		DisplayName = if displayName == nil then "Mia" else displayName,
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
	}
end

describe("PlayerInfo.fromPlayer", function()
	it("copies the id and the name", function()
		local info = PlayerInfo.fromPlayer(fakePlayer({}))
		expect(info.userId).toBe(7)
		expect(info.name).toBe("Mia")
	end)

	it("gives the display name, not the user name, as displayName", function()
		local player = fakePlayer({}, "Mia")
		player.Name = "mia_2014"
		local info = PlayerInfo.fromPlayer(player)
		expect(info.name).toBe("mia_2014")
		expect(info.displayName).toBe("Mia")
	end)

	it("falls back to the user name when the display name is empty", function()
		local player = fakePlayer({}, "")
		player.Name = "mia_2014"
		expect(PlayerInfo.fromPlayer(player).displayName).toBe("mia_2014")
	end)

	it("falls back to the user name when the display name is not text", function()
		local player = fakePlayer({}, 5)
		player.Name = "mia_2014"
		expect(PlayerInfo.fromPlayer(player).displayName).toBe("mia_2014")
	end)

	it("uses safe defaults when the player has no attributes", function()
		local info = PlayerInfo.fromPlayer(fakePlayer({}))
		expect(info.tiptoe).toBe(false)
		expect(info.carrying).toBeNil()
		expect(info.eggsHome).toBe(0)
	end)

	it("reads Tiptoe, Carrying and EggsHome", function()
		local info = PlayerInfo.fromPlayer(fakePlayer({ Tiptoe = true, Carrying = "Rare", EggsHome = 3 }))
		expect(info.tiptoe).toBe(true)
		expect(info.carrying).toBe("Rare")
		expect(info.eggsHome).toBe(3)
	end)

	it("counts Tiptoe only when it is the boolean true", function()
		expect(PlayerInfo.fromPlayer(fakePlayer({ Tiptoe = 1 })).tiptoe).toBe(false)
		expect(PlayerInfo.fromPlayer(fakePlayer({ Tiptoe = "true" })).tiptoe).toBe(false)
		expect(PlayerInfo.fromPlayer(fakePlayer({ Tiptoe = false })).tiptoe).toBe(false)
	end)

	it("ignores a Carrying value that is not a rarity name", function()
		expect(PlayerInfo.fromPlayer(fakePlayer({ Carrying = "Legendary" })).carrying).toBeNil()
		expect(PlayerInfo.fromPlayer(fakePlayer({ Carrying = 5 })).carrying).toBeNil()
		expect(PlayerInfo.fromPlayer(fakePlayer({ Carrying = true })).carrying).toBeNil()
	end)

	it("uses 0 for an EggsHome that is not a usable number", function()
		expect(PlayerInfo.fromPlayer(fakePlayer({ EggsHome = "2" })).eggsHome).toBe(0)
		expect(PlayerInfo.fromPlayer(fakePlayer({ EggsHome = -1 })).eggsHome).toBe(0)
		expect(PlayerInfo.fromPlayer(fakePlayer({ EggsHome = 0 / 0 })).eggsHome).toBe(0)
		expect(PlayerInfo.fromPlayer(fakePlayer({ EggsHome = math.huge })).eggsHome).toBe(0)
	end)
end)
