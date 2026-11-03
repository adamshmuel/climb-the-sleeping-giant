--!strict
-- Which cap tie (if any) a spot is on (Task 61h; spec 5, Rule 8: Steps make noise). A climb on a cap tie counts as
-- "from the head" at any height, so the tracker asks this while a player is climbing. Pure: it reads the tie parts
-- once, and later answers from their frames only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Side = "Left" | "Right"
export type Box = { cframe: CFrame, size: Vector3, side: Side }

local CapTieSpots = {}

local TIES: { { name: string, side: Side } } = {
	{ name = "CapTieLeft", side = "Left" },
	{ name = "CapTieRight", side = "Right" },
}

-- Every part of each cap tie that exists. A missing tie (or no walk surfaces at all) is skipped.
function CapTieSpots.boxes(walkSurfaces: Instance?): { Box }
	local boxes: { Box } = {}
	if walkSurfaces == nil then
		return boxes
	end
	for _, tie in TIES do
		local model = walkSurfaces:FindFirstChild(tie.name)
		if model ~= nil then
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(boxes, { cframe = descendant.CFrame, size = descendant.Size, side = tie.side })
				end
			end
		end
	end
	return boxes
end

-- The side of the tie this spot is within `Config.Noise.CapTieMargin` studs of, measured in each part's own frame.
function CapTieSpots.sideAt(boxes: { Box }, position: Vector3): Side?
	local margin = Config.Noise.CapTieMargin
	for _, box in boxes do
		local local3 = box.cframe:PointToObjectSpace(position)
		local half = box.size / 2 + Vector3.new(margin, margin, margin)
		if math.abs(local3.X) <= half.X and math.abs(local3.Y) <= half.Y and math.abs(local3.Z) <= half.Z then
			return box.side
		end
	end
	return nil
end

return CapTieSpots
