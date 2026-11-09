--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local StuckWatch = require(ServerScriptService.Server.Players.StuckWatch)

local USER = 1
local HERE = Vector3.new(10, 50, 10)

-- A player who is pressing to move, on the giant, free to move, standing still. Fields are set directly to override.
local function input(): StuckWatch.Input
	return { pressing = true, position = HERE, onGiant = true, blocked = false, falling = false, held = false }
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

	it("moving 2 studs or more starts the watch again", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		local moved = input()
		moved.position = HERE + Vector3.new(2, 0, 0)
		expect(watch:update(USER, moved, 2)).toBe(false)
		-- 3 seconds since the first look, but only 2 since the body moved.
		expect(watch:update(USER, moved, 4)).toBe(false)
		expect(watch:update(USER, moved, 5)).toBe(true)
	end)

	it("moving less than 2 studs doesn't start the watch again", function()
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		local shaken = input()
		shaken.position = HERE + Vector3.new(1.9, 0, 0)
		expect(watch:update(USER, shaken, 3)).toBe(true)
	end)

	it("a body that bobs 1.2 studs while pressing is still rescued at 3 s", function()
		-- A bob in place is stuck (Rule 28; KR): 1.2 studs is under the 2-stud stuck distance, so the clock keeps running.
		local watch = StuckWatch.new()
		watch:update(USER, input(), 0)
		local bobbed = input()
		bobbed.position = HERE + Vector3.new(0, 1.2, 0)
		expect(watch:update(USER, bobbed, 2.5)).toBe(false)
		expect(watch:update(USER, input(), 2.8)).toBe(false)
		expect(watch:update(USER, input(), 3)).toBe(true)
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
		falling.falling = true
		watch:update(USER, falling, 0)
		expect(watch:update(USER, falling, 10)).toBe(false)
		-- The watch starts when the block ends, not before.
		expect(watch:update(USER, input(), 11)).toBe(false)
		expect(watch:update(USER, input(), 13.9)).toBe(false)
		expect(watch:update(USER, input(), 14)).toBe(true)
	end)

	it("a pressing body that flips to falling for under 0.25 s is still rescued at 3 s", function()
		local watch = StuckWatch.new()
		local falling = input()
		falling.falling = true
		expect(watch:update(USER, input(), 0)).toBe(false)
		expect(watch:update(USER, falling, 1.0)).toBe(false)
		expect(watch:update(USER, falling, 1.1)).toBe(false)
		expect(watch:update(USER, input(), 1.2)).toBe(false)
		expect(watch:update(USER, input(), 2.95)).toBe(false)
		-- Never rescues while falling, even past 3 seconds.
		expect(watch:update(USER, falling, 3.0)).toBe(false)
		expect(watch:update(USER, input(), 3.1)).toBe(true)
	end)

	it("a fall of 0.25 s or longer starts the stuck time over", function()
		local watch = StuckWatch.new()
		local falling = input()
		falling.falling = true
		watch:update(USER, input(), 0)
		for _, at in { 1.0, 1.1, 1.2, 1.3 } do
			expect(watch:update(USER, falling, at)).toBe(false)
		end
		expect(watch:update(USER, input(), 1.4)).toBe(false)
		expect(watch:update(USER, input(), 3.0)).toBe(false)
		expect(watch:update(USER, input(), 4.3)).toBe(false)
		expect(watch:update(USER, input(), 4.4)).toBe(true)
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
