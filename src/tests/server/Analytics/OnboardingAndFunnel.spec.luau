--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type FakePlayer = Helpers.FakePlayer
type Harness = Helpers.Harness
local OWN_GARDEN_SPAWN_X = Helpers.OWN_GARDEN_SPAWN_X
local awayFromHome = Helpers.awayFromHome
local bank = Helpers.bank
local callsOf = Helpers.callsOf
local catch = Helpers.catch
local cleanUp = Helpers.cleanUp
local enter = Helpers.enter
local grab = Helpers.grab
local join = Helpers.join
local leave = Helpers.leave
local makePlayer = Helpers.makePlayer
local newHarness = Helpers.newHarness
local sampleOf = Helpers.sampleOf
local spawnCharacter = Helpers.spawnCharacter

afterEach(cleanUp)

-- The steps of the onboarding calls, as "1 Spawned" lines, so one expect shows the whole list.
local function onboardingLines(harness: Harness, player: FakePlayer?): { string }
	local lines: { string } = {}
	for _, call in callsOf(harness, "onboarding", player) do
		table.insert(lines, `{call.step} {call.stepName}`)
	end
	return lines
end

local function heistLines(harness: Harness, player: FakePlayer?): { string }
	local lines: { string } = {}
	for _, call in callsOf(harness, "funnel", player) do
		table.insert(lines, `{call.sessionId} {call.step} {call.stepName}`)
	end
	return lines
end

describe("Analytics onboarding", function()
	it("logs step 1 'Spawned' when a new player's character appears", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		expect(#harness.calls).toBe(1)
		expect(harness.calls[1].method).toBe("onboarding")
		expect(harness.calls[1].player).toBe(mia)
		expect(harness.calls[1].step).toBe(1)
		expect(harness.calls[1].stepName).toBe("Spawned")
	end)

	it("logs nothing for a player who has joined but has no character yet", function()
		local harness = newHarness()
		join(harness, makePlayer(1, 1))
		expect(harness.calls).toEqual({})
	end)

	it("logs step 1 for a player already in the game, with a character, when it starts", function()
		local mia = makePlayer(1, 1)
		mia.Character = {}
		local harness = newHarness({ mia })
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned" })
	end)

	it("waits for the character of a player already in the game who has none yet", function()
		local mia = makePlayer(1, 1)
		local harness = newHarness({ mia })
		expect(harness.calls).toEqual({})
		spawnCharacter(mia)
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned" })
	end)

	it("does not log step 1 again when the player respawns", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		spawnCharacter(mia)
		spawnCharacter(mia)
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned" })
	end)

	it("logs step 2 'First egg grabbed' on the first grab and not on the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Common")
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned", "2 First egg grabbed", "3 First egg home" })
	end)

	it("logs step 3 'First egg home' for the first banked egg and step 4 'Second egg home' for the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned", "2 First egg grabbed", "3 First egg home" })
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"4 Second egg home",
		})
	end)

	it("logs nothing more for the third egg home", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		for _ = 1, 3 do
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		expect(#onboardingLines(harness, mia)).toBe(4)
	end)

	it("logs step 5 'First Uncommon home' for the first Uncommon and not the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"4 Second egg home",
			"5 First Uncommon home",
		})
	end)

	it("logs step 6 'First Rare home' for the first Rare and not the second", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		for _ = 1, 2 do
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		grab(harness, mia, "Rare")
		bank(harness, mia)
		grab(harness, mia, "Rare")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"4 Second egg home",
			"6 First Rare home",
		})
	end)

	it("logs steps 3 and 5 together when the first egg home is an Uncommon", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Uncommon")
		bank(harness, mia)
		expect(onboardingLines(harness, mia)).toEqual({
			"1 Spawned",
			"2 First egg grabbed",
			"3 First egg home",
			"5 First Uncommon home",
		})
	end)

	it("logs a step once even if the egg count reads the same again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		bank(harness, mia)
		mia.attributes.EggsHome = 0
		grab(harness, mia, "Common")
		bank(harness, mia)
		local count = 0
		for _, line in onboardingLines(harness, mia) do
			if line == "3 First egg home" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)

	it("counts each player's steps on their own", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		local bo = makePlayer(2, 2)
		enter(harness, mia)
		enter(harness, bo)
		grab(harness, mia, "Common")
		grab(harness, bo, "Common")
		expect(onboardingLines(harness, mia)).toEqual({ "1 Spawned", "2 First egg grabbed" })
		expect(onboardingLines(harness, bo)).toEqual({ "1 Spawned", "2 First egg grabbed" })
	end)

	it("logs step 1 again for a player who leaves and comes back, because it is a new visit", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		leave(harness, mia)
		local miaAgain = makePlayer(1, 1)
		enter(harness, miaAgain)
		grab(harness, miaAgain, "Common")
		expect(onboardingLines(harness, miaAgain)).toEqual({ "1 Spawned", "2 First egg grabbed" })
	end)

	it("ignores an event for a player it is not tracking", function()
		local harness = newHarness()
		local stranger = makePlayer(9, 1)
		grab(harness, stranger, "Common")
		bank(harness, stranger)
		catch(harness, stranger)
		expect(harness.calls).toEqual({})
	end)
end)

describe("Analytics Heist funnel", function()
	it("logs steps 1, 2 and 3 in order with one session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed", "heist-1 3 Home" })
		local calls = callsOf(harness, "funnel", mia)
		expect(calls[1].funnelName).toBe("Heist")
		expect(calls[2].funnelName).toBe("Heist")
		expect(calls[3].funnelName).toBe("Heist")
		expect(calls[1].player).toBe(mia)
	end)

	it("asks for one new session id for each heist, not for each step", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		bank(harness, mia)
		expect(harness.idsMade).toBe(1)
	end)

	it("gives the next heist a new session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		for _ = 1, 2 do
			harness.analytics:check({ awayFromHome(mia, 11) })
			grab(harness, mia, "Common")
			bank(harness, mia)
		end
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-1 3 Home",
			"heist-2 1 Left garden",
			"heist-2 2 Grabbed",
			"heist-2 3 Home",
		})
	end)

	it("keeps each player's heist on its own session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		local bo = makePlayer(2, 2)
		enter(harness, mia)
		enter(harness, bo)
		harness.analytics:check({ awayFromHome(mia, 11), awayFromHome(bo, 11) })
		grab(harness, bo, "Common")
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed" })
		expect(heistLines(harness, bo)).toEqual({ "heist-2 1 Left garden", "heist-2 2 Grabbed" })
	end)

	it("logs step 1 only once while the heist is open: out, back home, out again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		harness.analytics:check({ awayFromHome(mia, 30) })
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X, 0) })
		harness.analytics:check({ awayFromHome(mia, 12) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("keeps the same heist when the player walks home without an egg and then grabs", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X, 0) })
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed" })
	end)

	it("logs no step 1 while the player carries an egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		mia.attributes.Carrying = "Common"
		harness.analytics:check({ awayFromHome(mia, 50) })
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("logs no step 1 at exactly 10 studs from the spawn spot, and logs it just past 10", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 10) })
		expect(heistLines(harness, mia)).toEqual({})
		harness.analytics:check({ awayFromHome(mia, 10.1) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("measures the 10 studs across the ground only, ignoring height", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 5, 200) })
		expect(heistLines(harness, mia)).toEqual({})
		harness.analytics:check({ awayFromHome(mia, 11, 2) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("logs no step 1 while the player stands in their own garden, however far from the spawn spot", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X + 60, 0) })
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("counts another player's garden as outside their own", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, 2, 2 * OWN_GARDEN_SPAWN_X, 0) })
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden" })
	end)

	it("logs no step 1 for a player who has no garden", function()
		local harness = newHarness()
		local mia = makePlayer(1, nil)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, nil, 500, 500) })
		harness.analytics:check({ sampleOf(mia, 3, 500, 500) }) -- standing in someone else's garden
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("logs no step 1 for a player whose garden number has no spawn spot", function()
		local harness = newHarness()
		local mia = makePlayer(1, 9)
		enter(harness, mia)
		harness.analytics:check({ sampleOf(mia, nil, 500, 500) })
		expect(heistLines(harness, mia)).toEqual({})
	end)

	it("ignores a sample of a player it is not tracking", function()
		local harness = newHarness()
		local stranger = makePlayer(9, 1)
		harness.analytics:check({ awayFromHome(stranger, 50) })
		expect(harness.calls).toEqual({})
		expect(harness.idsMade).toBe(0)
	end)

	it("opens a heist at a grab with no heist open and logs step 2 only", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 2 Grabbed" })
		bank(harness, mia)
		expect(heistLines(harness, mia)).toEqual({ "heist-1 2 Grabbed", "heist-1 3 Home" })
	end)

	it("ends the heist at a catch, so the next grab uses a new session id", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		catch(harness, mia)
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 2 Grabbed",
		})
	end)

	it("starts a new heist with its own step 1 after a catch, when the player leaves the garden again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		catch(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 40) })
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 1 Left garden",
		})
	end)

	it("ends the heist when the egg is lost another way: Carrying is gone at the next check", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		mia.attributes.Carrying = nil -- the carrier died
		harness.analytics:check({ sampleOf(mia, 1, OWN_GARDEN_SPAWN_X, 0) })
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 2 Grabbed",
		})
	end)

	it("starts a new heist with its own step 1 when the egg was lost and the player is outside again", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		mia.attributes.Carrying = nil -- the carrier died
		harness.analytics:check({ awayFromHome(mia, 40) })
		expect(heistLines(harness, mia)).toEqual({
			"heist-1 1 Left garden",
			"heist-1 2 Grabbed",
			"heist-2 1 Left garden",
		})
	end)

	it("does not end the heist at a check while the player still carries the egg", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		grab(harness, mia, "Common")
		harness.analytics:check({ awayFromHome(mia, 40) })
		harness.analytics:check({ awayFromHome(mia, 60) })
		bank(harness, mia)
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed", "heist-1 3 Home" })
	end)

	it("does not end a heist that has not reached step 2 when the player carries nothing at a check", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		harness.analytics:check({ awayFromHome(mia, 12) })
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 1 Left garden", "heist-1 2 Grabbed" })
	end)

	it("starts a new heist when a grab comes while an earlier one is still open at step 2", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		grab(harness, mia, "Common")
		mia.attributes.Carrying = nil -- lost with no check in between
		grab(harness, mia, "Common")
		expect(heistLines(harness, mia)).toEqual({ "heist-1 2 Grabbed", "heist-2 2 Grabbed" })
	end)

	it("forgets an open heist when the player leaves", function()
		local harness = newHarness()
		local mia = makePlayer(1, 1)
		enter(harness, mia)
		harness.analytics:check({ awayFromHome(mia, 11) })
		leave(harness, mia)
		local miaAgain = makePlayer(1, 1)
		enter(harness, miaAgain)
		grab(harness, miaAgain, "Common")
		expect(heistLines(harness, miaAgain)).toEqual({ "heist-2 2 Grabbed" })
	end)
end)
