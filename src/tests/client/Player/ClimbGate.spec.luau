--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local ClimbGate = require(StarterPlayer.StarterPlayerScripts.Client.Player.ClimbGate)

type Call = { state: Enum.HumanoidStateType, value: boolean }

local started: { ClimbGate.ClimbGate } = {}

-- A stand-in Humanoid: it writes down every SetStateEnabled call.
local function makeHumanoid()
	local calls: { Call } = {}
	local humanoid = {
		calls = calls,
		HipHeight = 2, -- as on the real body: the feet are HipHeight + Size.Y / 2 below the root (Rule 15)
		SetStateEnabled = function(_self: any, state: Enum.HumanoidStateType, value: boolean)
			table.insert(calls, { state = state, value = value })
		end,
	}
	return humanoid
end

-- A stand-in HumanoidRootPart: a position and the 2 x 2 x 1 size the real root has. With HipHeight 2 the feet are 3 below.
local function makeRoot(position: Vector3)
	return { Position = position, Size = Vector3.new(2, 2, 1) }
end

-- A stand-in character: FindFirstChildOfClass("Humanoid") and FindFirstChild("HumanoidRootPart") work, nothing else.
local function makeCharacter(humanoid: any?, root: any?)
	return {
		FindFirstChildOfClass = function(_self: any, className: string): any?
			if className == "Humanoid" then
				return humanoid
			end
			return nil
		end,
		FindFirstChild = function(_self: any, name: string): any?
			if name == "HumanoidRootPart" then
				return root
			end
			return nil
		end,
	}
end

-- Everything a test needs: the stand-in player, the ladder boxes (change `boxes` to move them), and a way to tick.
local function setup(boxes: { { cframe: CFrame, size: Vector3 } })
	local me: { Character: any? } = { Character = nil }
	local run = { tick = nil :: (() -> ())?, stops = 0 }
	local deps = {
		localPlayer = me :: any,
		findLadders = function()
			return boxes
		end,
		eachStep = function(fn: () -> ()): () -> ()
			run.tick = fn
			return function()
				run.stops += 1
			end
		end,
	}
	local gate = ClimbGate.start(deps)
	table.insert(started, gate)
	local function tick()
		local fn = run.tick
		assert(fn ~= nil, "start never asked for a tick")
		fn()
	end
	return me, run, tick, gate
end

-- A 2 x 32 x 2 ladder box centred at the origin: faces at x = 1 and z = 1, ends at y = 16.
local function ladderBox(): { cframe: CFrame, size: Vector3 }
	return { cframe = CFrame.new(0, 0, 0), size = Vector3.new(2, 32, 2) }
end

afterEach(function()
	for _, gate in started do
		gate:destroy()
	end
	table.clear(started)
end)

describe("ClimbGate.near", function()
	it("is near within the margin of a face, not beyond it", function()
		local boxes = { ladderBox() }
		expect(ClimbGate.near(Vector3.new(1 + 1.9, 0, 0), boxes, 2)).toBe(true)
		expect(ClimbGate.near(Vector3.new(1 + 2.1, 0, 0), boxes, 2)).toBe(false)
	end)

	it("is near inside the box", function()
		expect(ClimbGate.near(Vector3.new(0.5, 3, -0.5), { ladderBox() }, 2)).toBe(true)
	end)

	it("is near 1.9 studs past the end of the box, not 2.1", function()
		local boxes = { ladderBox() }
		expect(ClimbGate.near(Vector3.new(0, 16 + 1.9, 0), boxes, 2)).toBe(true)
		expect(ClimbGate.near(Vector3.new(0, 16 + 2.1, 0), boxes, 2)).toBe(false)
	end)

	it("follows a box turned 90 degrees", function()
		-- Turned about Y, the box's local x axis points along world z.
		local turned = { cframe = CFrame.Angles(0, math.rad(90), 0), size = Vector3.new(8, 2, 2) }
		expect(ClimbGate.near(Vector3.new(0, 0, 4 + 1.9), { turned }, 2)).toBe(true)
		expect(ClimbGate.near(Vector3.new(0, 0, 4 + 2.1), { turned }, 2)).toBe(false)
		expect(ClimbGate.near(Vector3.new(4 + 1.9, 0, 0), { turned }, 2)).toBe(false)
	end)

	it("is not near with no boxes", function()
		expect(ClimbGate.near(Vector3.zero, {}, 2)).toBe(false)
	end)
end)

describe("ClimbGate.start", function()
	it("checks before every physics step: a body moved far from the box sends false on the very next step", function()
		local humanoid = makeHumanoid()
		local root = makeRoot(Vector3.new(1 + 1, 0, 0)) -- 1 stud from the box face at x = 1
		local me, _run, step = setup({ ladderBox() })
		me.Character = makeCharacter(humanoid, root)
		step() -- near: true
		root.Position = Vector3.new(1 + 7.5, 0, 0) -- 7.5 studs from the face
		step() -- the very next step
		expect(humanoid.calls).toEqual({
			{ state = Enum.HumanoidStateType.Climbing, value = true },
			{ state = Enum.HumanoidStateType.Climbing, value = false },
		})
	end)

	it("far from every ladder: the first tick sends false, ten more send nothing", function()
		local humanoid = makeHumanoid()
		local me, _run, tick = setup({ ladderBox() })
		me.Character = makeCharacter(humanoid, makeRoot(Vector3.new(50, 0, 50)))
		tick()
		expect(humanoid.calls).toEqual({ { state = Enum.HumanoidStateType.Climbing, value = false } })
		for _ = 1, 10 do
			tick()
		end
		expect(#humanoid.calls).toBe(1)
	end)

	it("into a zone sends true once, out of it sends false once", function()
		local humanoid = makeHumanoid()
		local root = makeRoot(Vector3.new(50, 0, 50))
		local me, _run, tick = setup({ ladderBox() })
		me.Character = makeCharacter(humanoid, root)
		tick() -- far: false
		root.Position = Vector3.new(2, 0, 0)
		tick()
		tick()
		root.Position = Vector3.new(50, 0, 50)
		tick()
		tick()
		expect(humanoid.calls).toEqual({
			{ state = Enum.HumanoidStateType.Climbing, value = false },
			{ state = Enum.HumanoidStateType.Climbing, value = true },
			{ state = Enum.HumanoidStateType.Climbing, value = false },
		})
	end)

	it("a respawn (a new Humanoid) gets its own first send", function()
		local first = makeHumanoid()
		local second = makeHumanoid()
		local root = makeRoot(Vector3.new(50, 0, 50))
		local me, _run, tick = setup({ ladderBox() })
		me.Character = makeCharacter(first, root)
		tick()
		me.Character = makeCharacter(second, root)
		tick()
		tick()
		expect(#first.calls).toBe(1)
		expect(second.calls).toEqual({ { state = Enum.HumanoidStateType.Climbing, value = false } })
	end)

	it("no character, or no root part: no send and no error", function()
		local humanoid = makeHumanoid()
		local me, _run, tick = setup({ ladderBox() })
		tick() -- no character
		me.Character = makeCharacter(humanoid, nil)
		tick() -- a Humanoid, no root
		me.Character = makeCharacter(nil, makeRoot(Vector3.zero))
		tick() -- a root, no Humanoid
		expect(#humanoid.calls).toBe(0)
	end)

	it("no ladders found: sends false", function()
		local humanoid = makeHumanoid()
		local me, _run, tick = setup({})
		me.Character = makeCharacter(humanoid, makeRoot(Vector3.zero))
		tick()
		expect(humanoid.calls).toEqual({ { state = Enum.HumanoidStateType.Climbing, value = false } })
	end)

	it("a body whose feet are still within reach keeps climbing at the ladder top", function()
		-- ladderBox() top is y 16. Root one stud past the reach (Config.Ladders.NearStuds); feet are 3 below the root.
		local humanoid = makeHumanoid()
		local me, _run, tick = setup({ ladderBox() })
		me.Character = makeCharacter(humanoid, makeRoot(Vector3.new(0, 16 + Config.Ladders.NearStuds + 1, 0)))
		tick()
		expect(humanoid.calls).toEqual({ { state = Enum.HumanoidStateType.Climbing, value = true } })
	end)

	it("feet below and root above both out of reach send false", function()
		local humanoid = makeHumanoid()
		local me, _run, tick = setup({ ladderBox() })
		me.Character = makeCharacter(humanoid, makeRoot(Vector3.new(0, 16 + Config.Ladders.NearStuds + 5, 0)))
		tick()
		expect(humanoid.calls).toEqual({ { state = Enum.HumanoidStateType.Climbing, value = false } })
	end)

	it("destroy stops the ticks and sends nothing more", function()
		local humanoid = makeHumanoid()
		local me, run, tick, gate = setup({ ladderBox() })
		me.Character = makeCharacter(humanoid, makeRoot(Vector3.new(50, 0, 50)))
		tick()
		gate:destroy()
		expect(run.stops).toBe(1)
		tick()
		expect(#humanoid.calls).toBe(1) -- destroy does not switch climbing back on
	end)
end)
