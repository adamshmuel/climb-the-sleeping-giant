--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local StuckWatch = require(ServerScriptService.Server.Players.StuckWatch)

local USER = 1
local HERE = Vector3.new(10, 50, 10)

-- A player who is pressing to move, on the giant, free to move, standing still. Fields are set directly to override.
local function input(): StuckWatch.Input
	return { pressing = true, position = HERE, onGiant = true, blocked = false, held = false }
end

describe("StuckWatch.update", function()
	it("pressing and not moving for 3 seconds on the giant rescues", function()
		local watch = StuckWatch.new()
		expect(watch:update(USER, input(), 0)).toBe(false)
		expect(watch:update(USER, input(), 3)).toBe(true)
	end)

	it("2.9 seconds doesn't rescue", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		expect(watch:update(USER, input(), 2.9)).toBe(false)
	end)

	it("moving 1 stud or more starts the watch again", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		local moved = input()
		moved.position = HERE + Vector3.new(1, 0, 0)
		expect(watch:update(USER, moved, 2)).toBe(false)
		-- 3 seconds since the first look, but only 2 since the body moved.
		expect(watch:update(USER, moved, 4)).toBe(false)
		expect(watch:update(USER, moved, 5)).toBe(true)
	end)

	it("moving less than 1 stud doesn't start the watch again", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		local shaken = input()
		shaken.position = HERE + Vector3.new(0.9, 0, 0)
		expect(watch:update(USER, shaken, 3)).toBe(true)
	end)

	it("not pressing never rescues", function()
		local watch = StuckWatch.new()
		local idle = input()
		idle.pressing = false
		watch:update(USER, idle, 0)
		expect(watch:update(USER, idle, 10)).toBe(false)
	end)

	it("a held player who keeps pressing isn't rescued again", function()
		local watch = StuckWatch.new()
		local held = input()
		held.held = true
		watch:update(USER, held, 0)
		expect(watch:update(USER, held, 10)).toBe(false)
		-- The watch starts when the hold ends, not before.
		expect(watch:update(USER, input(), 11)).toBe(false)
		expect(watch:update(USER, input(), 13.9)).toBe(false)
		expect(watch:update(USER, input(), 14)).toBe(true)
	end)

	it("falling blocks the rescue", function()
		local watch = StuckWatch.new()
		local falling = input()
		falling.blocked = true
		watch:update(USER, falling, 0)
		expect(watch:update(USER, falling, 10)).toBe(false)
		-- The watch starts when the block ends, not before.
		expect(watch:update(USER, input(), 11)).toBe(false)
		expect(watch:update(USER, input(), 13.9)).toBe(false)
		expect(watch:update(USER, input(), 14)).toBe(true)
	end)

	it("floating down blocks the rescue", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		local floating = input()
		floating.blocked = true
		expect(watch:update(USER, floating, 5)).toBe(false)
		expect(watch:update(USER, input(), 6)).toBe(false)
	end)

	it("a red circle that hasn't landed blocks the rescue", function()
		local watch = StuckWatch.new()
		local inCircle = input()
		inCircle.blocked = true
		for second = 0, 6 do
			expect(watch:update(USER, inCircle, second)).toBe(false)
		end
	end)

	it("off the giant never rescues", function()
		local watch = StuckWatch.new()
		local meadow = input()
		meadow.onGiant = false
		watch:update(USER, meadow, 0)
		expect(watch:update(USER, meadow, 10)).toBe(false)
	end)

	it("a ladder climber who presses and doesn't move is rescued", function()
		-- Climbing is not a block: the input is the same as for walking.
		local watch = StuckWatch.new()
		local climbing = input()
		watch:update(USER, climbing, 0)
		watch:update(USER, climbing, 1.5)
		expect(watch:update(USER, climbing, 3.5)).toBe(true)
	end)

	it("after a rescue the watch starts again", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		expect(watch:update(USER, input(), 3)).toBe(true)
		expect(watch:update(USER, input(), 4)).toBe(false)
		expect(watch:update(USER, input(), 5.9)).toBe(false)
		expect(watch:update(USER, input(), 6)).toBe(true)
	end)

	it("keeps each player's watch apart", function()
		local watch = StuckWatch.new()
		watch:update(1, input(), 0)
		watch:update(2, input(), 2)
		expect(watch:update(1, input(), 3)).toBe(true)
		expect(watch:update(2, input(), 3)).toBe(false)
	end)
end)

describe("StuckWatch.forget", function()
	it("forgets a player", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		watch:forget(USER)
		-- The watch starts again here, so 3 seconds after the first look is not enough.
		expect(watch:update(USER, input(), 3)).toBe(false)
		expect(watch:update(USER, input(), 6)).toBe(true)
	end)
end)
