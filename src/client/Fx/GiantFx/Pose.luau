--!strict
-- The waking pose and the eyelids: the head tip, the right arm raise and swing, the eye swap and the lid flutter.

local Shared = require(script.Parent.Shared)
local Motion = require(script.Parent.Motion)
local Find = require(script.Parent.Find)
local Ride = require(script.Parent.Ride)

local SHOULDER_ATTRIBUTE = Shared.SHOULDER_ATTRIBUTE
local RAISE_ATTRIBUTE = Shared.RAISE_ATTRIBUTE

-- The pieces that tip forward with the head.
local HEAD_PIECE_NAMES = { "head_with_beard", "nightcap" }
-- The attributes on the giant that say where and how far the pieces turn.
local HEAD_PIVOT_ATTRIBUTE = "Awake_HeadPivot"
local HEAD_TILT_ATTRIBUTE = "Awake_HeadTiltDeg"

-- The part attribute that marks the awake eyes that show when he wakes.
local SHOWN_WHEN_AWAKE = "ShownWhenAwake"

local Pose = {}

function Pose.new(state: Shared.State, find: Find.Finders, ride: Ride.Rider)
	-- The pivot a model had before any motion of this module, saved the first time.
	local function startPivotOf(model: Model): CFrame
		local saved: CFrame? = state.startPivots[model]
		if saved == nil then
			saved = model:GetPivot()
			state.startPivots[model] = saved :: CFrame
			state.startMiddles[model] = (model:GetBoundingBox()).Position
		end
		return saved :: CFrame
	end

	-- Places the lids `seconds` into a flutter: each lifted by its own FlutterLift, measured from where it started,
	-- with the white slice showing while it is up. At 0 or after the flutter it is exactly at the start.
	local function placeLids(seconds: number)
		for _, lid in find.lids() do
			local start = startPivotOf(lid)
			local own: any = lid:GetAttribute("FlutterLift")
			local lift = Motion.flutterLift(seconds, if type(own) == "number" then own else 0)
			lid:PivotTo(if lift == 0 then start else start + Vector3.new(0, lift, 0))
			local sliver = lid:FindFirstChild("Sliver")
			if sliver ~= nil and sliver:IsA("BasePart") then
				if state.startSliver[sliver] == nil then
					state.startSliver[sliver] = sliver.Transparency
				end
				sliver.Transparency = if lift > 0 then 0 else state.startSliver[sliver]
			end
		end
	end

	-- The seconds into the pose at `now`.
	local function poseAgeAt(now: number): number
		return math.clamp(state.poseAge + state.poseDirection * (now - state.poseClock), 0, Shared.poseSeconds)
	end

	-- Everything that tips with the head: the head, the nightcap, both lids and the awake eyes.
	local function headPieces(): { Model }
		local found: { Model } = {}
		for _, name in HEAD_PIECE_NAMES do
			local piece = find.child(find.giant(), name)
			if piece ~= nil and piece:IsA("Model") then
				table.insert(found, piece)
			end
		end
		for _, lid in find.lids() do
			table.insert(found, lid)
		end
		local eyes = find.child(find.giant(), "AwakeEyes")
		if eyes ~= nil and eyes:IsA("Model") then
			table.insert(found, eyes)
		end
		return found
	end

	-- The arm's direction in the full raise: from the shoulder to the middle of the arm's bounding box, measured when the
	-- arm's start pivot was saved. The slam swing turns this direction toward the target.
	local function raisedDirection(rightArm: Model, shoulder: Vector3, raise: Vector3): Vector3?
		startPivotOf(rightArm)
		local middle: Vector3? = state.startMiddles[rightArm]
		if middle == nil then
			return nil
		end
		return Motion.armRaise(shoulder, raise, 1):PointToWorldSpace(middle) - shoulder
	end

	-- Puts the right arm `share` of the way into the waking pose (0 is at rest, 1 is the full raise), swung toward the
	-- slam that is in progress, if any, at `now`. The swing is scaled by `share`, so as the pose goes back to rest the
	-- swing goes with it. At share 0 the arm is exactly on its start pivot. Whatever rides the arm (Ride) moves with
	-- it. If the giant's numbers are missing, the arm stays where it is.
	local function placeRightArm(share: number, now: number)
		local model = find.giant()
		local rightArm = find.arm()
		if model == nil or rightArm == nil then
			return
		end
		local shoulder: any = model:GetAttribute(SHOULDER_ATTRIBUTE)
		local raise: any = model:GetAttribute(RAISE_ATTRIBUTE)
		local start = startPivotOf(rightArm)
		if share <= 0 or typeof(shoulder) ~= "Vector3" or typeof(raise) ~= "Vector3" then
			rightArm:PivotTo(start)
			ride.place(nil)
			return
		end
		local raised = Motion.armRaise(shoulder, raise, share)
		local swing = if state.slamAt ~= nil then Motion.slamShare(now - state.slamAt) else 0
		local target = state.slamPoint
		local from = raisedDirection(rightArm, shoulder, raise)
		local placed = raised * start
		if swing > 0 and target ~= nil and from ~= nil then
			placed = Motion.slamTurn(shoulder, from, target, swing * share) * placed
		end
		rightArm:PivotTo(placed)
		-- Whatever rides the arm moves by exactly what the arm moved (Rule 100).
		ride.place(placed * start:Inverse())
	end

	-- Puts the head pieces and the right arm `age` seconds into the pose, each from its start pivot. At 0 they are
	-- exactly on their start pivots. A piece whose numbers are missing on the giant stays where it is.
	local function placePose(age: number, now: number)
		local model = find.giant()
		if model == nil then
			return
		end
		local share = Motion.poseShare(age)
		local pivot: any = model:GetAttribute(HEAD_PIVOT_ATTRIBUTE)
		local tilt: any = model:GetAttribute(HEAD_TILT_ATTRIBUTE)
		local headTurn: CFrame? = nil
		if share > 0 and typeof(pivot) == "Vector3" and type(tilt) == "number" then
			headTurn = Motion.headTurn(pivot, tilt, share)
		end
		for _, piece in headPieces() do
			local start = startPivotOf(piece)
			piece:PivotTo(if headTurn ~= nil then headTurn * start else start)
		end
		placeRightArm(share, now)
	end

	-- Swaps the eyes: awake eyes (the parts marked ShownWhenAwake) show and the sleeping eyes hide, or the other way
	-- round. Each part's own transparency is saved the first time, and comes back when the eyes swap back.
	local function setEyes(awakeLook: boolean)
		local sleeping = find.child(find.giant(), "SleepEyes")
		if sleeping ~= nil then
			for _, part in sleeping:GetDescendants() do
				if part:IsA("BasePart") then
					if state.startLook[part] == nil then
						state.startLook[part] = part.Transparency
					end
					part.Transparency = if awakeLook then 1 else state.startLook[part]
				end
			end
		end
		local waking = find.child(find.giant(), "AwakeEyes")
		if waking ~= nil then
			for _, part in waking:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute(SHOWN_WHEN_AWAKE) == true then
					if state.startLook[part] == nil then
						state.startLook[part] = part.Transparency
					end
					part.Transparency = if awakeLook then 0 else state.startLook[part]
				end
			end
		end
	end

	-- Puts every eye part back to the transparency it had before the eyes were swapped.
	local function restoreEyes()
		for part, look in state.startLook do
			part.Transparency = look
		end
		table.clear(state.startLook)
	end

	return {
		placeLids = placeLids,
		poseAgeAt = poseAgeAt,
		raisedDirection = raisedDirection,
		placeRightArm = placeRightArm,
		placePose = placePose,
		setEyes = setEyes,
		restoreEyes = restoreEyes,
	}
end

return Pose
