--!strict
-- Stuck safety Task 41, test 6: "the pillow gives no way up". A plain helper (Jest only runs files ending in .spec).
-- It works on any map shaped like the walk map (spots and links), so a made-up map can prove it notices a step.
-- Meaning, as in step 1's measure: a way up exists only if a player can get from the ground (without stepping on the
-- giant) onto the pillow's top, by walking or by a jump. Only then are the links that leave the top, and the jumps from
-- any top spot, checked: none may reach the nightcap, his head, his beard or a nest.

local ServerScriptService = game:GetService("ServerScriptService")
local WaysUpCheck = require(ServerScriptService.Server.World.WaysUpCheck)

export type Spot = { id: number, position: Vector3, standsOn: Instance? }
export type Link = { to: number, kind: string }
export type MapLike = { spots: { Spot }, links: { [number]: { Link } } }
export type Rules = {
	isGround: (Spot) -> boolean,
	isBlocked: (Spot) -> boolean,
	isTop: (Spot) -> boolean,
	isTarget: (Spot) -> boolean,
	canJump: (Vector3, Vector3) -> boolean,
}

local MAX_LINES = 5
local YIELD_EVERY = 40

local PillowWayUp = {}

local function at(position: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
end

-- One copy of the jump logic: it lives in WaysUpCheck (plan 5 Task 18a Step 2).
PillowWayUp.jumpReaches = WaysUpCheck.jumpReaches
PillowWayUp.apexBetween = WaysUpCheck.apexBetween

function PillowWayUp.problems(map: MapLike, rules: Rules): { string }
	local found: { string } = {}
	local tops: { Spot } = {}
	local targets: { Spot } = {}
	local reached: { [number]: boolean } = {}
	local queue: { number } = {}
	for _, spot in map.spots do
		if rules.isTop(spot) then
			table.insert(tops, spot)
		end
		if rules.isTarget(spot) then
			table.insert(targets, spot)
		end
		if rules.isGround(spot) then
			reached[spot.id] = true
			table.insert(queue, spot.id)
		end
	end
	if #tops == 0 then
		return found
	end
	local head = 0
	while head < #queue do
		head += 1
		local outgoing: { Link } = map.links[queue[head]] or {}
		for _, link in outgoing do
			local next = map.spots[link.to]
			if not reached[link.to] and not rules.isBlocked(next) then
				reached[link.to] = true
				table.insert(queue, link.to)
			end
		end
		if head % 400 == 0 then
			task.wait()
		end
	end
	local topReached = false
	for _, spot in tops do
		if reached[spot.id] then
			topReached = true
			break
		end
	end
	if not topReached then
		local seen = 0
		for id in reached do
			for _, spot in tops do
				if rules.canJump(map.spots[id].position, spot.position) then
					topReached = true
					break
				end
			end
			seen += 1
			if topReached then
				break
			elseif seen % YIELD_EVERY == 0 then
				task.wait()
			end
		end
	end
	if not topReached then
		return found
	end
	local count = 0
	local function add(line: string)
		count += 1
		if count <= MAX_LINES then
			table.insert(found, line)
		end
	end
	for index, spot in tops do
		local outgoing: { Link } = map.links[spot.id] or {}
		for _, link in outgoing do
			local to = map.spots[link.to]
			if rules.isTarget(to) then
				add(`a {link.kind} link leads from the pillow's top {at(spot.position)} to {at(to.position)}`)
			end
		end
		for _, target in targets do
			if rules.canJump(spot.position, target.position) then
				add(`a jump leads from the pillow's top {at(spot.position)} to {at(target.position)}`)
			end
		end
		if index % YIELD_EVERY == 0 then
			task.wait()
		end
	end
	if count > MAX_LINES then
		table.insert(found, `... {count} ways in all`)
	end
	return found
end

return PillowWayUp
