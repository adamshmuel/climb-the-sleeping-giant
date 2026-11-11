-- Part b of 2 (paste after nest-walk-a, joined). Group R: the trips of GROUP_R, in this order.
local GROUP_R = { 15, 32, 39, 33, 34, 35, 36, 37 }
if group == "R" then
	order = {}
	for _, no in GROUP_R do
		if trips[no] ~= nil then
			table.insert(order, no)
		end
	end
	ReplicatedStorage:SetAttribute("P4t13Count", #order)
end

local function waitBank(): boolean
	return waitUntil(function(): boolean
		return player:GetAttribute("Carrying") == nil
	end, 3)
end

-- T32: prompt not shown in 3 s: walk to the anchor's x, z for up to 3 s, then wait 3 s more. Returns grabbed, note.
local function grab(nest: Instance, prompt: ProximityPrompt?, anchor: Vector3?): (boolean, string)
	if prompt == nil then
		return false, ""
	end
	local rank = nest:GetAttribute("Rarity")
	local hum, root = body()
	local function isShown(): boolean
		return shown[prompt] == true
	end
	if not waitUntil(isShown, 3) then
		if anchor ~= nil then
			hum:MoveTo(Vector3.new(anchor.X, root.Position.Y, anchor.Z))
		end
		if not waitUntil(isShown, 3) and not waitUntil(isShown, 3) then
			return false, grabNote(hum, root, anchor)
		end
	end
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.3)
	prompt:InputHoldEnd()
	local carried = waitUntil(function(): boolean
		return player:GetAttribute("Carrying") == rank
	end, 2)
	return carried, if carried then "" else grabNote(hum, root, anchor)
end

-- `anchor` (up walk): every point can end the walk by coming within grab reach; the rest then count as done.
local function walk(points: { Point }, anchor: Vector3?, down: boolean?): (number, Vector3?)
	for index, p in points do
		local following = points[index + 1]
		local aim = if down ~= true and p.c == true and following ~= nil then toVec(following) else nil
		local ok, at, near = leg(toVec(p), p.c == true, anchor, aim, down)
		if not ok then
			return index - 1, at
		elseif near then
			return #points, nil
		end
	end
	return #points, nil
end

-- From the SpawnSpot top; the spec banks there, Banking.luau needs the real position inside the garden.
local function bank(plot: Instance, spawn: BasePart): (boolean, boolean, Vector3?)
	local ok, at = leg(spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0), false)
	if not ok then
		return false, false, at
	end
	if waitBank() then
		return true, false, nil
	end
	local volume = plot:FindFirstChild("GardenVolume") :: BasePart
	local banked = leg(Vector3.new(volume.Position.X, spawn.Position.Y, volume.Position.Z), false) and waitBank()
	return banked, banked, nil
end

local function runTrip(no: number, trip: Trip): boolean
	local tag = string.format("R%02d", no)
	local okHeld, why = held()
	if not okHeld then
		row(tag, `VOID: giant not held ({why})`)
		return false
	end
	local jumps, fall, fallFrom = 0, 0.0, nil :: number?
	local note = ""
	local hum = body()
	local watch = hum.StateChanged:Connect(function(prev: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		jumps += if new == Enum.HumanoidStateType.Jumping then 1 else 0
		if new == Enum.HumanoidStateType.Freefall then
			fallFrom = os.clock()
		elseif prev == Enum.HumanoidStateType.Freefall and fallFrom ~= nil then
			fall = math.max(fall, os.clock() - fallFrom)
			fallFrom = nil
		end
	end)
	local stopped: Vector3? = nil
	local done, grabbed, banked, viaGarden, empty = 0, false, false, false, false
	if not put(toVec(trip.st)) then
		stopped = toVec(trip.st)
	else
		remote:FireServer("start", no, trip.n, trip.g)
		task.wait(0.5)
		local nest = spots:FindFirstChild(trip.n) :: Instance
		local prompt = nest:FindFirstChildWhichIsA("ProximityPrompt", true)
		local anchor = if prompt ~= nil then anchorOf(prompt) else nil
		local n, at = walk(trip.up, anchor)
		done, stopped = n, at
		if stopped == nil and prompt ~= nil and prompt.Enabled == false then
			empty = true -- the game has no egg on this nest: no grab, no way down, no bank (not a fail)
		elseif stopped == nil then
			grabbed, note = grab(nest, prompt, anchor)
			n, at = walk(trip.dn, nil, true)
			done, stopped = done + n, at
		end
		local plot = plots:FindFirstChild(`Plot_{trip.g}`) :: Instance
		if stopped == nil and not empty then
			banked, viaGarden, stopped = bank(plot, plot:FindFirstChild("SpawnSpot") :: BasePart)
			done += if stopped == nil then 1 else 0
		end
	end
	remote:FireServer("end", no)
	watch:Disconnect()
	local peakName = `P4t13Peak_{no}`
	waitUntil(function(): boolean
		return ReplicatedStorage:GetAttribute(peakName) ~= nil
	end, 2)
	local peak = ReplicatedStorage:GetAttribute(peakName) :: number?
	local phase = ReplicatedStorage:GetAttribute(`P4t13Phase_{no}`)
	local gap = if peak ~= nil then f1(math.abs(peak - trip.s)) else "none"
	local total = if empty then #trip.up else #trip.up + #trip.dn + 1
	local bankText = if not grabbed then "n/a" elseif banked then "yes" else "no"
	local kind = if empty then "EMPTY (no egg)" else `grabbed {if grabbed then "yes" else "no"} banked {bankText}{note}`
	local text =
		`T{string.format("%02d", no)} {trip.n} {trip.w} legs {done}/{total} jumps {jumps} fall {f1(fall)} {kind}`
	text ..= if empty then "" else `{if viaGarden then " (garden)" else ""} peak {f1(peak)} gap {gap}`
	text ..= ` score {trip.s}`
	text ..= if phase ~= "Asleep" then ` phase {tostring(phase)}` else ""
	text ..= if stopped ~= nil then ` STOPPED {fmt(stopped)}` else ""
	row(tag, text)
	if grabbed and not banked then
		row(tag .. "w", `WALK STOPPED: still carrying {tostring(player:GetAttribute("Carrying"))}`)
		return false
	end
	return true
end

local function plantedFail()
	local floor = put(toVec((leftRamp or trips[order[1]]).st))
	local ok, at = leg(PLANTED, false)
	row("R90", if ok then "FAIL-PLANTED reached (unexpected)" else `FAIL-PLANTED STOPPED {fmt(at)} floor {floor}`)
end

task.spawn(function()
	local clean = true
	for _, no in order do
		local ok, ran = pcall(runTrip, no, trips[no])
		if not ok then
			row(string.format("R%02d", no), `FIRED T{no}: {tostring(ran)}`)
		end
		if not ok or not ran then
			clean = false
			break
		end
	end
	if clean and group == "smoke" then
		local ok, err = (pcall :: any)(plantedFail)
		if not ok then
			row("R90", `FIRED planted fail: {tostring(err)}`)
		end
	end
	ReplicatedStorage:SetAttribute("P4t13Running", false)
end)

return `started {group} {count}`
