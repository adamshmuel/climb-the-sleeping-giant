--!strict
-- Rail post against nest rim (plan 5 Task 19c; product's ruling work/p3t13/13c-post-order.md): a post must not stand
-- inside a nest's rim. Rim = half the larger of the nest mesh's X and Z. Margin = the flat (X/Z) distance from the nest
-- centre, minus the rim, minus half the post's larger X/Z. A post counts for a nest only when its height overlaps the
-- nest model's bounding box. Service-free, so the test (PostRim.spec), the real test (Nests.spec) and the world script
-- (tools/world/21e-post-clear.luau) all read this one copy.

export type Box = { cframe: CFrame, size: Vector3 } -- the nest model's bounding box (Model:GetBoundingBox)
export type Nest = { name: string, mesh: BasePart, box: Box }

local PostRim = {}

-- Studs a moved post keeps clear of a rim. 0.1, not more: at the lap plank's end the best margin is 0.14 (plan 5 Task 19c).
PostRim.CLEAR = 0.1

local function larger(size: Vector3): number
	return math.max(size.X, size.Z)
end

local function postName(post: BasePart): string
	local parent = post.Parent
	if parent ~= nil and parent ~= game then
		return `{parent.Name}.{post.Name}`
	end
	return post.Name
end

-- The post's margin to the nest's rim (negative: inside). nil when the post's height does not overlap the nest's box.
function PostRim.margin(nestMesh: BasePart, nestBox: Box, post: BasePart): number?
	local boxLow = nestBox.cframe.Position.Y - nestBox.size.Y / 2
	local boxHigh = nestBox.cframe.Position.Y + nestBox.size.Y / 2
	local postLow = post.Position.Y - post.Size.Y / 2
	local postHigh = post.Position.Y + post.Size.Y / 2
	if postHigh < boxLow or postLow > boxHigh then
		return nil
	end
	local flat = Vector3.new(post.Position.X - nestMesh.Position.X, 0, post.Position.Z - nestMesh.Position.Z).Magnitude
	return flat - larger(nestMesh.Size) / 2 - larger(post.Size) / 2
end

-- One line per post inside a rim (margin of 0 or less), the worst margin first.
function PostRim.problems(nests: { Nest }, posts: { BasePart }): { string }
	local found: { { margin: number, line: string } } = {}
	for _, nest in nests do
		for _, post in posts do
			local margin = PostRim.margin(nest.mesh, nest.box, post)
			if margin ~= nil and margin <= 0 then
				table.insert(found, {
					margin = margin,
					line = `{postName(post)} stands inside {nest.name}'s rim: margin {string.format("%.2f", margin)}`,
				})
			end
		end
	end
	table.sort(found, function(a, b)
		return a.margin < b.margin
	end)
	local lines: { string } = {}
	for _, item in found do
		table.insert(lines, item.line)
	end
	return lines
end

return PostRim
