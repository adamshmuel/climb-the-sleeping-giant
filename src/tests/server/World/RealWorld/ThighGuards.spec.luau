--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local realWorld = Helpers.realWorld

-- Plan "gardens-and-ways-up", Task 15d (V2 spec 7, Rule 82 "No new way onto the belly"): from each boot top no walk may
-- reach the hip crease, so an invisible wall (World.ThighGuards.ThighGuard_<Side>) stands across the thigh edge of each
-- boot top. Numbers: work/p5t15d/15d-scripts.md sections A.3 and B6 (stand-in measured in Steps 2 and 3).
describe("the real world, the thigh guards", function()
	local SIDES = { "Left", "Right" }
	-- "Left" parts are his left: stud x below 0 (docs/game-at-a-glance.md, "Sides").
	local X_NEAR = 22.3 -- studs: the guard's inner end, measured from the middle line
	local X_FAR = 33.5 -- studs: the guard's outer end
	local X_MARGIN = 0.1 -- studs: how far each end may be from the numbers above
	local Z_WALL = -55 -- studs: where the wall stands, front to back
	local Z_MARGIN = 0.3 -- studs
	local TOP_AT_LEAST = 42.5 -- studs: the guard's top is at least this high
	local BOTTOM_AT_MOST = 20.5 -- studs: the guard's bottom is at most this high

	it("each boot top's thigh edge has an invisible guard", function()
		local problems: { string } = {}
		local folder = realWorld():FindFirstChild("ThighGuards")
		if folder == nil then
			table.insert(problems, "World.ThighGuards is missing")
		end
		for _, side in SIDES do
			local name = `ThighGuard_{side}`
			local guard = if folder ~= nil then folder:FindFirstChild(name) else nil
			if guard == nil or not guard:IsA("BasePart") then
				table.insert(problems, `{name} is missing`)
				continue
			end
			local part = guard :: BasePart
			local sign = if side == "Left" then -1 else 1
			local near = part.Position.X - sign * part.Size.X / 2 -- the end nearest the middle line
			local far = part.Position.X + sign * part.Size.X / 2
			if part.Transparency ~= 1 then
				table.insert(problems, `{name} Transparency {part.Transparency}, want 1`)
			end
			if not part.CanCollide or not part.CanQuery or part.CanTouch or not part.Anchored then
				table.insert(
					problems,
					`{name} CanCollide {part.CanCollide} CanQuery {part.CanQuery} CanTouch {part.CanTouch} Anchored {part.Anchored}`
				)
			end
			if math.abs(near - sign * X_NEAR) > X_MARGIN or math.abs(far - sign * X_FAR) > X_MARGIN then
				table.insert(problems, `{name} spans x {near} to {far}, want {sign * X_NEAR} to {sign * X_FAR}`)
			end
			if math.abs(part.Position.Z - Z_WALL) > Z_MARGIN then
				table.insert(problems, `{name} z {part.Position.Z}, want {Z_WALL}`)
			end
			if part.Position.Y + part.Size.Y / 2 < TOP_AT_LEAST then
				table.insert(problems, `{name} top {part.Position.Y + part.Size.Y / 2}, want at least {TOP_AT_LEAST}`)
			end
			if part.Position.Y - part.Size.Y / 2 > BOTTOM_AT_MOST then
				table.insert(
					problems,
					`{name} bottom {part.Position.Y - part.Size.Y / 2}, want at most {BOTTOM_AT_MOST}`
				)
			end
		end
		expect(problems).toEqual({})
	end)
end)
