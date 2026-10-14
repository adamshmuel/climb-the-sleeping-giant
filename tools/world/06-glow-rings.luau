--!strict
-- World prep, task 20: the glow ring under a waiting Common egg gets designer's look (spec Rule 3, "Eggs wait in
-- three zones", and the "Empty egg spot" row of spec section 6).
-- Why: designer's look check in Play. Each of the 8 meadow rings was a solid-looking white plate: 8.95 studs wide,
-- #FFF4C8, Transparency 0.35. Now a ring is 6.5 studs across and 0.2 thick, warm gold #FFE08A, Neon, and 60% see-through
-- (Transparency 0.6) while an egg waits. The server fades it to 0.85 on an empty spot (SpotModels), and back to 0.6.
-- Only Size, Color, Transparency and Material change: the ring keeps its centre and its rotation, and nothing else is
-- touched. The boot and belly spots have no ring.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- It checks first, so a second run changes nothing and says "already done". It returns a short plain-text report.
-- Nothing is deleted. The place file must be saved by Adam afterwards.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local NEW_SIZE = Vector3.new(0.2, 6.5, 6.5) -- X is the thickness of the cylinder, Y and Z its width
local NEW_COLOR = Color3.fromHex("FFE08A")
local NEW_TRANSPARENCY = 0.6 -- the same number as SpotModels.WAITING_RING_TRANSPARENCY
local NEW_MATERIAL = Enum.Material.Neon
local SAME_LIMIT = 0.001 -- a value closer than this to the new one counts as already set

local function isDone(ring: BasePart): boolean
	return (ring.Size - NEW_SIZE).Magnitude < SAME_LIMIT
		and ring.Color:ToHex() == NEW_COLOR:ToHex()
		and math.abs(ring.Transparency - NEW_TRANSPARENCY) < SAME_LIMIT
		and ring.Material == NEW_MATERIAL
end

local function run(): string
	local world = Workspace:FindFirstChild("World")
	local spots = if world then world:FindFirstChild("EggSpots") else nil
	if spots == nil then
		error("Workspace.World.EggSpots is missing (run 04-egg-spots first)")
	end

	-- Check everything first, so a problem stops the script before anything changes.
	local toChange: { BasePart } = {}
	local alreadyDone = 0
	for _, spot in spots:GetChildren() do
		local ring = spot:FindFirstChild("GlowRing")
		if ring ~= nil then
			if not ring:IsA("BasePart") then
				error(`{ring:GetFullName()} is a {ring.ClassName}, not a part`)
			end
			if isDone(ring) then
				alreadyDone += 1
			else
				table.insert(toChange, ring)
			end
		end
	end

	if #toChange == 0 then
		if alreadyDone == 0 then
			error("no GlowRing found on any egg spot")
		end
		return "already done"
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("06-glow-rings: before")
	end)
	for _, ring in toChange do
		-- Setting Size keeps the part's CFrame, so the centre and the rotation stay as they were.
		ring.Size = NEW_SIZE
		ring.Color = NEW_COLOR
		ring.Transparency = NEW_TRANSPARENCY
		ring.Material = NEW_MATERIAL
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("06-glow-rings: after")
	end)

	return string.format(
		"restyled %d glow rings (%d were already done): size (0.2, 6.5, 6.5), #FFE08A, Transparency 0.6, Neon",
		#toChange,
		alreadyDone
	)
end

local ok, message = pcall(run)
if not ok then
	return "STOPPED WITH AN ERROR: " .. tostring(message)
end
return message
