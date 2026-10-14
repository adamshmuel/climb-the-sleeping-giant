--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Floater = require(ServerScriptService.Server.Players.Floater)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)

-- The fake character is a Model that is never parented anywhere, so nothing is put in Workspace.
-- The root is 2 x 2 x 1 and the Humanoid's HipHeight is 2, so a player standing on a spot has the root's centre
-- 2 + 1 = 3 studs above the spot's top.
local REST_ABOVE_SPOT = 3
-- The numbers the Floater builds in (docs/architecture.md: "How a bounced player floats down").
local FLOAT_HEIGHT = 12
local FLOAT_SPEED = 8
local FLOAT_END_ABOVE = 2.5
-- How long the push takes to reach FLOAT_END_ABOVE: the server lets go by the clock too, so ping doesn't matter.
local EXPECTED_SECONDS = (FLOAT_HEIGHT - FLOAT_END_ABOVE) / FLOAT_SPEED -- 1.1875
-- The centre of his face (Giant.SleepEyes) is about here in the place.
local FACE_POINT = Vector3.new(0.95, 95.3, 0.01)

local SPOT: WorldIndex.LandingSpot = { index = 1, position = Vector3.new(30, 5, -20) }
local OTHER_SPOT: WorldIndex.LandingSpot = { index = 2, position = Vector3.new(-40, 2, 10) }
local REST_HEIGHT = SPOT.position.Y + REST_ABOVE_SPOT

-- Everything a test makes is destroyed afterwards.
local madeInstances: { Instance } = {}
local floaters: { Floater.Floater } = {}

afterEach(function()
	for _, floater in floaters do
		floater:destroy()
	end
	table.clear(floaters)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

type FakePlayer = {
	UserId: number,
	Character: Model?,
	root: BasePart?,
	egg: BasePart?,
	attributeWrites: number, -- how many times anything called SetAttribute on the player
	SetAttribute: (self: any, name: string, value: any) -> (),
}

type Options = { noRoot: boolean?, noHumanoid: boolean?, noCharacter: boolean? }

-- A player with a character: root (2 x 2 x 1) at `position`, a Humanoid with HipHeight 2, and a "CarriedEgg" part
-- welded to the root, like the egg on a carrier's back.
local function newPlayer(userId: number, position: Vector3, options: Options?): FakePlayer
	local player: FakePlayer = {
		UserId = userId,
		Character = nil,
		root = nil,
		egg = nil,
		attributeWrites = 0,
		SetAttribute = function(self: any, _name: string, _value: any)
			self.attributeWrites += 1
		end,
	}
	if options ~= nil and options.noCharacter == true then
		return player
	end
	local character = Instance.new("Model")
	character.Name = `Character{userId}`
	table.insert(madeInstances, character)
	if options == nil or options.noHumanoid ~= true then
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 2
		humanoid.Parent = character
	end
	if options == nil or options.noRoot ~= true then
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = CFrame.new(position)
		root.Parent = character
		character.PrimaryPart = root
		local egg = Instance.new("Part")
		egg.Name = "CarriedEgg"
		egg.Size = Vector3.new(1, 1.5, 1)
		egg.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 1.5))
		egg.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = egg
		weld.Parent = egg
		player.root = root
		player.egg = egg
	end
	character:SetAttribute("Carrying", "Rare")
	character:SetAttribute("Tiptoe", true)
	player.Character = character
	return player
end

type Harness = {
	floater: Floater.Floater,
	playerRemoving: any,
	clock: number,
}

local function newHarness(facePoint: Vector3?): Harness
	local harness: Harness = {
		floater = nil :: any,
		playerRemoving = newSignal(),
		clock = 500,
	}
	harness.floater = Floater.start({
		players = { PlayerRemoving = harness.playerRemoving } :: any,
		facePoint = facePoint or FACE_POINT,
		now = function()
			return harness.clock
		end,
	})
	table.insert(floaters, harness.floater)
	return harness
end

local function countOf(character: Model, className: string): number
	local count = 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA(className) then
			count += 1
		end
	end
	return count
end

local function rootOf(player: FakePlayer): BasePart
	return player.root :: BasePart
end

-- Puts the root straight above its spot at a height above the standing height, as if it floated that far down.
local function setRootAbove(player: FakePlayer, spot: WorldIndex.LandingSpot, aboveRest: number)
	local root = rootOf(player)
	root.CFrame = CFrame.new(spot.position.X, spot.position.Y + REST_ABOVE_SPOT + aboveRest, spot.position.Z)
end

describe("Floater.float", function()
	it("puts the root above the landing spot, 12 studs above standing height", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		local position = rootOf(player).Position
		expect(position.X).toBeCloseTo(30, 3)
		expect(position.Y).toBeCloseTo(REST_HEIGHT + FLOAT_HEIGHT, 3)
		expect(position.Z).toBeCloseTo(-20, 3)
	end)

	it("turns the character flat toward his face, whichever way it faced and however it was tipped", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local root = rootOf(player)
		-- Standing at the spot (-50, 1.9, -54) of the place, facing away from him (+Z), tipped 30 degrees forward.
		local spot: WorldIndex.LandingSpot = { index = 6, position = Vector3.new(-50, 1.9, -54) }
		root.CFrame = CFrame.lookAt(Vector3.new(0, 80, 0), Vector3.new(0, 80, 10)) * CFrame.Angles(math.rad(30), 0, 0)
		harness.floater:float(player, spot)
		local expected = Vector3.new(FACE_POINT.X - spot.position.X, 0, FACE_POINT.Z - spot.position.Z).Unit
		local look = root.CFrame.LookVector
		expect(root.CFrame.UpVector.Y).toBeCloseTo(1, 3)
		expect(look.Y).toBeCloseTo(0, 3)
		expect(look.X).toBeCloseTo(expected.X, 3)
		expect(look.Z).toBeCloseTo(expected.Z, 3)
	end)

	it("returns the flat look it turned the player to", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local spot: WorldIndex.LandingSpot = { index = 6, position = Vector3.new(-50, 1.9, -54) }
		local look = harness.floater:float(player, spot)
		local expected = Vector3.new(FACE_POINT.X - spot.position.X, 0, FACE_POINT.Z - spot.position.Z).Unit
		expect(look).never.toBeNil()
		local flat = look :: Vector3
		expect(flat.Magnitude).toBeCloseTo(1, 3)
		expect(flat.X).toBeCloseTo(expected.X, 3)
		expect(flat.Y).toBeCloseTo(0, 3)
		expect(flat.Z).toBeCloseTo(expected.Z, 3)
		expect(flat.X).toBeCloseTo(rootOf(player).CFrame.LookVector.X, 3)
		expect(flat.Z).toBeCloseTo(rootOf(player).CFrame.LookVector.Z, 3)
	end)

	it("faces -Z when the spot is right under his face", function()
		local harness = newHarness(Vector3.new(30, 95, -20))
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local look = harness.floater:float(player, SPOT)
		expect(look).toEqual(Vector3.new(0, 0, -1))
		expect(rootOf(player).CFrame.LookVector.Z).toBeCloseTo(-1, 3)
		expect(rootOf(player).CFrame.LookVector.Y).toBeCloseTo(0, 3)
	end)

	it("moves the whole character, so the welded egg stays on and in the character", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local root = rootOf(player)
		local egg = player.egg :: BasePart
		local before = root.CFrame:ToObjectSpace(egg.CFrame)
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		local after = root.CFrame:ToObjectSpace(egg.CFrame)
		expect(after.Position.X).toBeCloseTo(before.Position.X, 3)
		expect(after.Position.Y).toBeCloseTo(before.Position.Y, 3)
		expect(after.Position.Z).toBeCloseTo(before.Position.Z, 3)
		expect(egg.Parent).toBe(player.Character)
		expect(egg:FindFirstChildOfClass("WeldConstraint")).never.toBe(nil)
	end)

	it("leaves every attribute alone, so Carrying and Tiptoe stay as they were", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local character = player.Character :: Model
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		harness.floater:step()
		expect(player.attributeWrites).toBe(0)
		expect(character:GetAttribute("Carrying")).toBe("Rare")
		expect(character:GetAttribute("Tiptoe")).toBe(true)
	end)

	it("stops any speed the player already had", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local root = rootOf(player)
		root.AssemblyLinearVelocity = Vector3.new(5, -60, 3)
		root.AssemblyAngularVelocity = Vector3.new(1, 2, 3)
		harness.floater:float(player, SPOT)
		expect(root.AssemblyLinearVelocity).toEqual(Vector3.zero)
		expect(root.AssemblyAngularVelocity).toEqual(Vector3.zero)
	end)

	it("adds exactly one LinearVelocity: world, vector mode, 8 studs a second down, no force limit", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local character = player.Character :: Model
		harness.floater:float(player, SPOT)
		expect(countOf(character, "LinearVelocity")).toBe(1)
		local velocity = character:FindFirstChildWhichIsA("LinearVelocity", true) :: LinearVelocity
		expect(velocity.RelativeTo).toBe(Enum.ActuatorRelativeTo.World)
		expect(velocity.VelocityConstraintMode).toBe(Enum.VelocityConstraintMode.Vector)
		expect(velocity.VectorVelocity).toEqual(Vector3.new(0, -FLOAT_SPEED, 0))
		expect(velocity.ForceLimitsEnabled).toBe(false)
		local attachment = velocity.Attachment0 :: Attachment
		expect(attachment).never.toBe(nil)
		expect(attachment.Parent).toBe(player.root)
		expect(harness.floater:isFloating(1)).toBe(true)
	end)

	it("a second float for the same player leaves one LinearVelocity and one attachment, at the new spot", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local character = player.Character :: Model
		harness.floater:float(player, SPOT)
		harness.floater:float(player, OTHER_SPOT)
		expect(countOf(character, "LinearVelocity")).toBe(1)
		expect(countOf(character, "Attachment")).toBe(1)
		expect(rootOf(player).Position.X).toBeCloseTo(-40, 3)
		expect(rootOf(player).Position.Z).toBeCloseTo(10, 3)
	end)

	it("does nothing, and does not fail, for a player with no character", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.zero, { noCharacter = true })
		expect(harness.floater:float(player, SPOT)).toBeNil()
		expect(harness.floater:isFloating(1)).toBe(false)
	end)

	it("does nothing for a character with no HumanoidRootPart", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.zero, { noRoot = true })
		expect(harness.floater:float(player, SPOT)).toBeNil()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(countOf(player.Character :: Model, "LinearVelocity")).toBe(0)
	end)

	it("does nothing for a character with no Humanoid", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0), { noHumanoid = true })
		expect(harness.floater:float(player, SPOT)).toBeNil()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(countOf(player.Character :: Model, "LinearVelocity")).toBe(0)
		expect(rootOf(player).Position.Y).toBeCloseTo(80, 3)
	end)
end)

describe("Floater.float after destroy", function()
	it("does nothing and returns nil once the floater is destroyed", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:destroy()
		expect(harness.floater:float(player, SPOT)).toBeNil()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(rootOf(player).Position.Y).toBeCloseTo(80, 3)
	end)
end)

describe("Floater.step", function()
	it("keeps a player floating while the root is still high", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		harness.floater:step()
		setRootAbove(player, SPOT, 5)
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(true)
		expect(countOf(player.Character :: Model, "LinearVelocity")).toBe(1)
	end)

	it("lets go when the root is 0.5 studs above standing height", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		setRootAbove(player, SPOT, 0.5)
		harness.floater:step()
		expect(countOf(player.Character :: Model, "LinearVelocity")).toBe(0)
		expect(countOf(player.Character :: Model, "Attachment")).toBe(0)
		expect(harness.floater:isFloating(1)).toBe(false)
	end)

	it("lets go exactly 2.5 studs above standing height, but not 3", function()
		local harness = newHarness()
		local near = newPlayer(1, Vector3.new(0, 80, 0))
		local far = newPlayer(2, Vector3.new(0, 80, 0))
		harness.floater:float(near, SPOT)
		harness.floater:float(far, SPOT)
		setRootAbove(near, SPOT, FLOAT_END_ABOVE)
		setRootAbove(far, SPOT, FLOAT_END_ABOVE + 0.5)
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(harness.floater:isFloating(2)).toBe(true)
	end)

	it("lets go when the expected time is up, even if the server still sees the root high", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		-- The root has not moved (the server sees the player late), so only the clock can end the float.
		harness.clock += 1.18
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(true)
		harness.clock += 0.01
		harness.floater:step()
		expect(EXPECTED_SECONDS).toBeCloseTo(1.1875, 6)
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(countOf(player.Character :: Model, "LinearVelocity")).toBe(0)
		expect(countOf(player.Character :: Model, "Attachment")).toBe(0)
	end)

	it("counts the expected time from each float's own start", function()
		local harness = newHarness()
		local first = newPlayer(1, Vector3.new(0, 80, 0))
		local second = newPlayer(2, Vector3.new(0, 80, 0))
		harness.floater:float(first, SPOT)
		harness.clock += 0.5
		harness.floater:float(second, OTHER_SPOT)
		harness.clock += 0.8
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(harness.floater:isFloating(2)).toBe(true)
	end)

	it("forgets a player whose character was replaced, without an error", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		local oldCharacter = player.Character :: Model
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		local replacement = newPlayer(1, Vector3.new(0, 10, 0))
		player.Character = replacement.Character
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(countOf(oldCharacter, "LinearVelocity")).toBe(0)
		expect(countOf(replacement.Character :: Model, "LinearVelocity")).toBe(0)
	end)

	it("forgets a player whose character was destroyed, without an error", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		-- Roblox clears Player.Character when the character is destroyed.
		local character = player.Character :: Model
		player.Character = nil
		character:Destroy()
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
	end)

	it("forgets a player whose root was taken out of the character", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		rootOf(player).Parent = nil
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
	end)

	it("does nothing, and does not fail, when nobody is floating", function()
		local harness = newHarness()
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
	end)
end)

-- The last 2.5-stud drop takes about 0.16 s; the Floater counts touchdown this much after the push lets go.
local TOUCHDOWN_DROP_SECONDS = 0.25

describe("Floater.landedAgo", function()
	it("is nil for a player who never floated", function()
		local harness = newHarness()
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("is nil while the player is still floating", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		harness.floater:step()
		harness.clock += 0.5
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("counts from 0.25 s after a release by time", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		harness.clock += 1.19
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
		local releasedAt = harness.clock
		harness.clock = releasedAt + 1
		local ago = harness.floater:landedAgo(1)
		expect(ago).never.toBeNil()
		expect(ago :: number).toBeCloseTo(1 - TOUCHDOWN_DROP_SECONDS, 6)
	end)

	it("counts from 0.25 s after a release by height", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		setRootAbove(player, SPOT, 0.5)
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
		harness.clock += 2
		local ago = harness.floater:landedAgo(1)
		expect(ago).never.toBeNil()
		expect(ago :: number).toBeCloseTo(2 - TOUCHDOWN_DROP_SECONDS, 6)
	end)

	it("is negative just after the release, because touchdown is a little later", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		setRootAbove(player, SPOT, 0.5)
		harness.floater:step()
		local ago = harness.floater:landedAgo(1)
		expect(ago).never.toBeNil()
		expect(ago :: number).toBeCloseTo(-TOUCHDOWN_DROP_SECONDS, 6)
	end)

	it("is nil when the float ended because the character was replaced", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		local replacement = newPlayer(1, Vector3.new(0, 10, 0))
		player.Character = replacement.Character
		harness.clock += 5 -- the time is also up, but the character being gone is what ended it
		harness.floater:step()
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("is nil when the float ended because the character was destroyed", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		local character = player.Character :: Model
		player.Character = nil
		character:Destroy()
		harness.floater:step()
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("is nil after the player leaves", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		setRootAbove(player, SPOT, 0.5)
		harness.floater:step()
		expect(harness.floater:landedAgo(1)).never.toBeNil()
		harness.playerRemoving:Fire(player)
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("is nil again from the moment a new float starts", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		setRootAbove(player, SPOT, 0.5)
		harness.floater:step()
		expect(harness.floater:landedAgo(1)).never.toBeNil()
		harness.floater:float(player, OTHER_SPOT)
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("is nil when a second float replaces a float that had not ended", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		harness.floater:float(player, OTHER_SPOT)
		harness.clock += 3
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)

	it("keeps each player's own touchdown", function()
		local harness = newHarness()
		local first = newPlayer(1, Vector3.new(0, 80, 0))
		local second = newPlayer(2, Vector3.new(0, 80, 0))
		harness.floater:float(first, SPOT)
		setRootAbove(first, SPOT, 0.5)
		harness.floater:step()
		harness.clock += 1
		harness.floater:float(second, OTHER_SPOT)
		setRootAbove(second, OTHER_SPOT, 0.5)
		harness.floater:step()
		harness.clock += 1
		expect(harness.floater:landedAgo(1) :: number).toBeCloseTo(2 - TOUCHDOWN_DROP_SECONDS, 6)
		expect(harness.floater:landedAgo(2) :: number).toBeCloseTo(1 - TOUCHDOWN_DROP_SECONDS, 6)
	end)

	it("destroy clears it", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		setRootAbove(player, SPOT, 0.5)
		harness.floater:step()
		expect(harness.floater:landedAgo(1)).never.toBeNil()
		harness.floater:destroy()
		expect(harness.floater:landedAgo(1)).toBeNil()
	end)
end)

describe("Floater clean-up", function()
	it("forgets a player who leaves", function()
		local harness = newHarness()
		local player = newPlayer(1, Vector3.new(0, 80, 0))
		harness.floater:float(player, SPOT)
		expect(harness.floater:isFloating(1)).toBe(true)
		harness.playerRemoving:Fire(player)
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(countOf(player.Character :: Model, "LinearVelocity")).toBe(0)
	end)

	it("keeps the other players floating when one leaves", function()
		local harness = newHarness()
		local leaving = newPlayer(1, Vector3.new(0, 80, 0))
		local staying = newPlayer(2, Vector3.new(0, 80, 0))
		harness.floater:float(leaving, SPOT)
		harness.floater:float(staying, OTHER_SPOT)
		harness.playerRemoving:Fire(leaving)
		expect(harness.floater:isFloating(2)).toBe(true)
	end)

	it("destroy removes every LinearVelocity and attachment it made, and disconnects", function()
		local harness = newHarness()
		local first = newPlayer(1, Vector3.new(0, 80, 0))
		local second = newPlayer(2, Vector3.new(0, 80, 0))
		harness.floater:float(first, SPOT)
		harness.floater:float(second, OTHER_SPOT)
		expect(harness.playerRemoving:count()).toBe(1)
		harness.floater:destroy()
		expect(countOf(first.Character :: Model, "LinearVelocity")).toBe(0)
		expect(countOf(first.Character :: Model, "Attachment")).toBe(0)
		expect(countOf(second.Character :: Model, "LinearVelocity")).toBe(0)
		expect(countOf(second.Character :: Model, "Attachment")).toBe(0)
		expect(harness.floater:isFloating(1)).toBe(false)
		expect(harness.floater:isFloating(2)).toBe(false)
		expect(harness.playerRemoving:count()).toBe(0)
	end)

	it("destroy can be called twice", function()
		local harness = newHarness()
		harness.floater:destroy()
		harness.floater:destroy()
		expect(harness.playerRemoving:count()).toBe(0)
	end)
end)
