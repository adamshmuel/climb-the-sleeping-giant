--!strict
-- Plan 4 Task 13b: nest-ladder (SERVER; an Edit dry run is allowed). Paste after nest-legs says `done`.
-- A boot-ladder trip (way "Left boot ladder" / "Right boot ladder") starts on the grass at the ladder's foot: the
-- lowest Rung's x and z, feet y from a ray down (the walk map's foot spot sits against the boot, behind the ladder).
-- Rewrites `st` in each such StringValue of P4t13Legs (ServerStorage in Edit, ReplicatedStorage in Play).
local CHECK_ONLY = false

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LADDER: { [string]: string } =
	{ ["Left boot ladder"] = "BootLadder_Left", ["Right boot ladder"] = "BootLadder_Right" }
local box: Instance = if RunService:IsRunning() then ReplicatedStorage else ServerStorage
local legs = box:FindFirstChild("P4t13Legs")
local surfaces = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("WalkSurfaces")
if CHECK_ONLY or legs == nil or surfaces == nil then
	return `nest-ladder: nothing changed (CHECK_ONLY {tostring(CHECK_ONLY)}, legs {tostring(legs ~= nil)}, WalkSurfaces {tostring(
		surfaces ~= nil
	)})`
end

local function footOf(way: string): Vector3?
	local ladder = surfaces:FindFirstChild(LADDER[way])
	local look = if ladder ~= nil then ladder:FindFirstChild("Look") else nil
	local lowest: BasePart? = nil
	for _, child in if look ~= nil then look:GetChildren() else {} do
		if
			child.Name == "Rung"
			and child:IsA("BasePart")
			and (lowest == nil or child.Position.Y < lowest.Position.Y)
		then
			lowest = child
		end
	end
	if lowest == nil or ladder == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ladder }
	local hit = Workspace:Raycast(lowest.Position + Vector3.yAxis * 0.5, Vector3.yAxis * -10, params)
	return if hit ~= nil then Vector3.new(lowest.Position.X, hit.Position.Y, lowest.Position.Z) else nil
end

local lines: { string } = {}
for _, value in legs:GetChildren() do
	local trip = if value:IsA("StringValue") then HttpService:JSONDecode(value.Value) else nil
	if value:IsA("StringValue") and trip ~= nil and LADDER[trip.w] ~= nil then
		local foot = footOf(trip.w)
		if foot == nil then
			error(`FIRED nest-ladder: {value.Name} {trip.w} has no Rung or no ground below it`, 0)
		end
		trip.st = { x = foot.X, y = foot.Y, z = foot.Z, c = false }
		value.Value = HttpService:JSONEncode(trip)
		table.insert(lines, `{value.Name} {trip.w} ({string.format("%.1f, %.1f, %.1f", foot.X, foot.Y, foot.Z)})`)
	end
end
return string.sub(`nest-ladder: {#lines} trips moved: {table.concat(lines, "; ")}`, 1, 1000)
