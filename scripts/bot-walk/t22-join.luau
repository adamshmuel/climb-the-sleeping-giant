--!strict
-- Plan 5 Task 22, Part 22-2, Step 1 (work/p5t22/22-scripts.md, "t22-join") (no hold: Edit only). Read-only: casts down rays every
-- 0.25 studs along the long side of CuffWalk.Join_Left and Join_Right (plus 1 stud past each end), on 3 lines across the width
-- (x -0.6, 0, +0.6 of the part), and prints the biggest height drop between two neighbouring rays. Pass: under about 1.6 studs.
-- The number goes to designer either way.
local CHECK_ONLY = false

local Workspace = game:GetService("Workspace")

local STEP, MARGIN, LIMIT, LIFT, REACH = 0.25, 1, 1.6, 3, 12
local LINES = { -0.6, 0, 0.6 }

type Worst = { drop: number, at: number, from: string, to: string, misses: number, rays: number }

local function measure(join: BasePart): Worst
	local params = RaycastParams.new()
	local worst: Worst = { drop = 0, at = 0, from = "-", to = "-", misses = 0, rays = 0 }
	local half = join.Size.Z / 2 + MARGIN
	for _, lx in LINES do
		local previous: RaycastResult? = nil
		local steps = math.floor(half * 2 / STEP + 0.5)
		for i = 0, steps do
			local lz = -half + i * STEP
			local point = join.CFrame:PointToWorldSpace(Vector3.new(lx, 0, lz))
			local hit = Workspace:Raycast(point + Vector3.new(0, LIFT, 0), Vector3.new(0, -REACH, 0), params)
			worst.rays += 1
			if hit == nil then
				worst.misses += 1
			elseif previous ~= nil then
				local drop = math.abs(hit.Position.Y - previous.Position.Y)
				if drop > worst.drop then
					worst = {
						drop = drop,
						at = lz,
						from = previous.Instance.Name,
						to = hit.Instance.Name,
						misses = worst.misses,
						rays = worst.rays,
					}
				end
			end
			previous = hit
		end
	end
	return worst
end

local function job(): string
	if CHECK_ONLY then
		return "check only: nothing read"
	end
	local world = Workspace:FindFirstChild("World")
	local walk = if world ~= nil then world:FindFirstChild("CuffWalk") else nil
	local lines: { string } = {}
	local found = 0
	for _, name in { "Join_Left", "Join_Right" } do
		local join = if walk ~= nil then walk:FindFirstChild(name) else nil
		if join ~= nil and join:IsA("BasePart") then
			found += 1
			local w = measure(join)
			table.insert(
				lines,
				`{name}: biggest drop {string.format("%.2f", w.drop)} at local z {string.format("%.2f", w.at)} ({w.from} -> {w.to}), misses {w.misses} of {w.rays}, {if w.drop
						< LIMIT
					then "PASS"
					else "OVER"} {LIMIT}`
			)
		end
	end
	table.insert(lines, `found {found} of 2`)
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

return job()
