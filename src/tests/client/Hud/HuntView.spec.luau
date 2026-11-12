--!strict
-- What the player sees while he hunts (plan 6 Task 19; spec 6 Rule 67 and section 8). HuntView.read is pure: it
-- turns what the game knows about the local player into three answers, with no screen and no clock.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local HuntView = require(StarterPlayer.StarterPlayerScripts.Client.Hud.HuntView)

-- A landed carrier, outside every garden, while he is awake. Plot 3 is the player's own garden.
local function carrier(
	changes: { phase: string?, carrying: boolean?, inGarden: number?, floating: boolean? }?
): HuntView.Input
	local input: HuntView.Input = {
		phase = "Awake",
		carrying = true,
		inGarden = 0,
		plotIndex = 3,
		floating = false,
	}
	if changes ~= nil then
		if changes.phase ~= nil then
			input.phase = changes.phase
		end
		if changes.carrying ~= nil then
			input.carrying = changes.carrying
		end
		if changes.inGarden ~= nil then
			input.inGarden = changes.inGarden
		end
		if changes.floating ~= nil then
			input.floating = changes.floating
		end
	end
	return input
end

describe("HuntView.read: the RUN HOME! pill (Rule 67)", function()
	it("shows the pill for a landed carrier outside their garden while he is awake", function()
		expect(HuntView.read(carrier()).runHome).toBe(true)
	end)

	it("does not show the pill while the carrier is still floating after the bounce", function()
		expect(HuntView.read(carrier({ floating = true })).runHome).toBe(false)
	end)

	it("shows the pill the moment Floating turns false", function()
		expect(HuntView.read(carrier({ floating = true })).runHome).toBe(false)
		expect(HuntView.read(carrier({ floating = false })).runHome).toBe(true)
	end)

	it("does not show the pill inside the player's own garden", function()
		expect(HuntView.read(carrier({ inGarden = 3 })).runHome).toBe(false)
	end)

	it("still shows the pill for a carrier standing in someone else's garden", function()
		expect(HuntView.read(carrier({ inGarden = 5 })).runHome).toBe(true)
	end)

	it("hides the pill when he lies down (the phase is not Awake)", function()
		expect(HuntView.read(carrier({ phase = "Asleep" })).runHome).toBe(false)
		expect(HuntView.read(carrier({ phase = "HeavySleep" })).runHome).toBe(false)
	end)

	it("hides the pill when the egg is lost", function()
		expect(HuntView.read(carrier()).runHome).toBe(true)
		expect(HuntView.read(carrier({ carrying = false })).runHome).toBe(false)
	end)

	it("shows the pill at once when a player grabs an egg while he is awake", function()
		expect(HuntView.read(carrier({ carrying = false })).runHome).toBe(false)
		expect(HuntView.read(carrier({ carrying = true })).runHome).toBe(true)
	end)

	it("shows the pill for a carrier with no garden of their own yet", function()
		local input = carrier()
		input.plotIndex = nil
		expect(HuntView.read(input).runHome).toBe(true)
	end)
end)

describe("HuntView.read: the red edges (Task 20 reads this)", function()
	it("are on for anyone outside every garden while he is awake, carrying or not", function()
		expect(HuntView.read(carrier({ carrying = true })).edges).toBe(true)
		expect(HuntView.read(carrier({ carrying = false })).edges).toBe(true)
	end)

	it("are off inside any garden, the player's own or another one", function()
		expect(HuntView.read(carrier({ inGarden = 3 })).edges).toBe(false)
		expect(HuntView.read(carrier({ inGarden = 5 })).edges).toBe(false)
	end)

	it("are off while he sleeps", function()
		expect(HuntView.read(carrier({ phase = "Asleep" })).edges).toBe(false)
		expect(HuntView.read(carrier({ phase = "HeavySleep" })).edges).toBe(false)
	end)

	it("a carrier in another garden gets the pill but no edges and no tip", function()
		local view = HuntView.read(carrier({ inGarden = 5 }))
		expect(view.runHome).toBe(true)
		expect(view.edges).toBe(false)
		expect(view.tip).toBe("none")
	end)
end)

describe("HuntView.read: the tip kind (Task 18 reads this)", function()
	it("is carrier for a carrier outside every garden while he is awake", function()
		expect(HuntView.read(carrier()).tip).toBe("carrier")
	end)

	it("is circle for a player outside every garden who carries nothing", function()
		expect(HuntView.read(carrier({ carrying = false })).tip).toBe("circle")
	end)

	it("is none inside a garden", function()
		expect(HuntView.read(carrier({ inGarden = 3, carrying = false })).tip).toBe("none")
		expect(HuntView.read(carrier({ inGarden = 3 })).tip).toBe("none")
	end)

	it("is none while he sleeps", function()
		expect(HuntView.read(carrier({ phase = "Asleep" })).tip).toBe("none")
		expect(HuntView.read(carrier({ phase = "Asleep", carrying = false })).tip).toBe("none")
	end)
end)

-- A stand-in for an Instance with attributes: set one with `set`, and the watchers of that name run at once.
local function fakeSource(attributes: { [string]: any })
	local watchers: { [string]: { [number]: () -> () } } = {}
	local live = 0
	local source = {}
	function source.GetAttribute(_self: any, name: string): any
		return attributes[name]
	end
	function source.GetAttributeChangedSignal(_self: any, name: string): any
		return {
			Connect = function(_signal: any, callback: () -> ()): any
				watchers[name] = watchers[name] or {}
				local list = watchers[name]
				table.insert(list, callback)
				live += 1
				local on = true
				return {
					Disconnect = function()
						if on then
							on = false
							live -= 1
							table.remove(list, table.find(list, callback))
						end
					end,
				}
			end,
		}
	end
	local function set(name: string, value: any)
		attributes[name] = value
		local list: { () -> () } = table.clone(watchers[name] or {})
		for _, callback in list do
			callback()
		end
	end
	return source :: any, set, function(): number
		return live
	end
end

describe("HuntView.watch", function()
	it("tells the view once at the start", function()
		local giant = fakeSource({ Phase = "Awake" })
		local player = fakeSource({ Carrying = "Egg", PlotIndex = 3 })
		local views: { HuntView.View } = {}
		local stop = HuntView.watch(giant, player, function(view)
			table.insert(views, view)
		end)
		expect(#views).toBe(1)
		expect(views[1].runHome).toBe(true)
		stop()
	end)

	it("tells the view again on each change", function()
		local giant, setGiant = fakeSource({ Phase = "Asleep" })
		local player, setPlayer = fakeSource({ Carrying = "Egg", PlotIndex = 3 })
		local views: { HuntView.View } = {}
		local stop = HuntView.watch(giant, player, function(view)
			table.insert(views, view)
		end)
		expect(views[1].runHome).toBe(false)
		setGiant("Phase", "Awake")
		expect(#views).toBe(2)
		expect(views[2].runHome).toBe(true)
		setPlayer("Carrying", nil)
		expect(#views).toBe(3)
		expect(views[3].runHome).toBe(false)
		setPlayer("Floating", true)
		setPlayer("InGarden", 2)
		setPlayer("PlotIndex", 4)
		expect(#views).toBe(6)
		stop()
	end)

	it("reads a wrong-typed attribute as its default", function()
		-- Phase not a string reads Asleep, InGarden not a number reads 0, PlotIndex not a number reads none.
		local giant = fakeSource({ Phase = 7 })
		local player = fakeSource({ Carrying = "Egg", InGarden = "x", PlotIndex = "y", Floating = "yes" })
		local views: { HuntView.View } = {}
		HuntView.watch(giant, player, function(view)
			table.insert(views, view)
		end)()
		expect(views[1]).toEqual(HuntView.read({
			phase = "Asleep",
			carrying = true,
			inGarden = 0,
			plotIndex = nil,
			floating = false,
		}))
		-- awake, with the same wrong types: outside every garden, carrying, no garden of his own, not floating
		local awake = fakeSource({ Phase = "Awake" })
		local seen: { HuntView.View } = {}
		HuntView.watch(awake, player, function(view)
			table.insert(seen, view)
		end)()
		expect(seen[1].runHome).toBe(true)
		expect(seen[1].tip).toBe("carrier")
	end)

	it("stops calling and lets go of every signal after stop", function()
		local giant, setGiant, giantLive = fakeSource({ Phase = "Asleep" })
		local player, setPlayer, playerLive = fakeSource({})
		local calls = 0
		local stop = HuntView.watch(giant, player, function()
			calls += 1
		end)
		expect(giantLive()).toBe(1)
		expect(playerLive()).toBe(4)
		stop()
		expect(giantLive()).toBe(0)
		expect(playerLive()).toBe(0)
		local before = calls
		setGiant("Phase", "Awake")
		setPlayer("Carrying", "Egg")
		expect(calls).toBe(before)
	end)
end)
