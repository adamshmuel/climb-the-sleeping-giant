--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

-- Stuck safety Task 61a (spec section 5: "Cap tie width" and "Landing at each tie's top"; Rule 101, Ladders hold you;
-- Rule 20, One collision source). The left cap tie hangs on the route designer measured (work/ear-ladders/tie-route-table.md)
-- and product's ruling 2a: the invisible guard plate CapSideLeft_28 is gone (kept in ServerStorage.WorldBackups.CapTies).
-- 61b adds the right tie to this file. All numbers are studs; left is minus x.
describe("the real world, the left cap tie", function()
	local Workspace = game:GetService("Workspace")
	local ServerStorage = game:GetService("ServerStorage")

	local TIE_NAME = "CapTieLeft"
	local TIE_Z = 32 -- the tie's centre line along z
	local STRAP_WIDTH = 2.7 -- along z
	local STRAP_THICK = 0.6 -- along x
	local ROUTE: { { number } } = { -- { height y, strap centre |x| } from the route table
		{ 60, 36.7 },
		{ 90, 36.7 },
		{ 95, 36.3 },
		{ 100, 35.3 },
		{ 105, 33.2 },
		{ 110, 29.9 },
	}
	local BOTTOM_Y, TOP_Y = 60, 110
	local END_NUDGE = 0.05 -- the end heights are read this far inside the strap, so a ray never grazes a cut end
	local END_INSIDE = 0.5 -- end rows are read this far inside the end: the top piece's square cut reaches 0.17 below its end
	local ROUTE_SLACK = 0.15
	local HEAD_GAP = 0.25 -- the strap never touches the head; straight pieces between the 5-stud rows pass up to 0.11 closer than the table's 0.5

	local function tableX(y: number): number -- the route table's straight line at height y
		for i = 1, #ROUTE - 1 do
			local a, b = ROUTE[i], ROUTE[i + 1]
			if y >= a[1] and y <= b[1] then
				return a[2] + (b[2] - a[2]) * (y - a[1]) / (b[1] - a[1])
			end
		end
		return ROUTE[#ROUTE][2]
	end
	local TRUSS_Z_OFFSET = 0.35 -- the truss pair stands this far each side of the tie's centre line
	local UP_OUTER_X, UP_TOP_Y = -37.10, 84.38 -- the upright pair's outer face and its top
	local LEAN_TILT = 4.60 -- degrees toward his head
	local LEAN_LOW_Y, LEAN_LOW_X, LEAN_HIGH_Y, LEAN_HIGH_X = 84.5, -37.10, 100, -35.85
	local STRIP_EXTRA, STRIP_FROM_Y, RAILS_TO_Y = 0.3, 100, 110
	local RAIL_INNER = 1.35 -- the rails' inner faces stand this far each side of the centre line (z 30.65 and 33.35)
	local KNOT_GAP = 2
	local PLATE_CLEARANCE = 1.5
	local LANDING_SIZE = 6
	local FOLD_OFF_MAX = 0.5 -- every bottom edge of the fold is at most this far off the cap
	local FOLD_LOW_MIN, FOLD_LOW_MAX = 0.18, 0.32 -- the low edge rests this far above the cap (0.2 to 0.3, a little slack)
	local WEDGE_FROM_X, WEDGE_STEPS = -35.8, 8 -- rays every 0.1 from just inside the truss top's outer edge to x -35.0
	local SEAM_X0, SEAM_X1, SEAM_Z0, SEAM_Z1, SEAM_STEP = -37, -25, 26.5, 37.5, 0.25
	local SEAM_MAX_STEP = 0.5
	local FOLD_SIDE_MAX_STEP = 1.5 -- the fold's sides step down onto the cap by this much at most (walk up, no jump)
	local WALK_NORMAL_Y = 0.342 -- the 70 degree walk limit
	local POMPOM_SIZE = 3.2
	local POMPOM_AT = Vector3.new(-36.7, 58.4, TIE_Z)
	local FLOOR_AT = Vector3.new(-38.7, 56.4, TIE_Z) -- 2 studs out from the tie's foot

	local function walkSurfaces(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		return (world :: any).WalkSurfaces :: Instance
	end

	local function findTie(): Instance
		local tie = walkSurfaces():FindFirstChild(TIE_NAME)
		expect(tie).never.toBeNil()
		return tie :: Instance
	end

	local function partsNamed(tie: Instance, prefix: string): { BasePart }
		local found: { BasePart } = {}
		for _, child in tie:GetChildren() do
			if child:IsA("BasePart") and string.sub(child.Name, 1, #prefix) == prefix then
				table.insert(found, child)
			end
		end
		return found
	end

	-- Rays that see what a player's body sees: collidable parts only, never the guard plates, the mockups or the tie.
	local function worldParams(tie: Instance?): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		local skip: { Instance } = { walkSurfaces():FindFirstChild("SteepGuards") :: Instance }
		for _, child in Workspace:GetChildren() do
			if string.sub(child.Name, 1, 7) == "Mockup_" then
				table.insert(skip, child)
			end
		end
		if tie ~= nil then
			table.insert(skip, tie)
		end
		params.FilterDescendantsInstances = skip
		return params
	end

	-- Where a part's local side face (side -1 or 1 along its X) crosses the line at height y, z = TIE_Z: the x, or nil when
	-- the line misses the face. Read from the part's CFrame and Size, so it works on parts that rays can't see (CanQuery false).
	local function faceX(part: BasePart, side: number, y: number): number?
		local cf = part.CFrame
		local half = part.Size / 2
		if math.abs(TIE_Z - cf.Position.Z) > half.Z or math.abs(cf.YVector.Y) < 0.001 then
			return nil
		end
		local localX = side * half.X
		local localY = (y - cf.Position.Y - localX * cf.XVector.Y) / cf.YVector.Y
		if math.abs(localY) > half.Y then
			return nil
		end
		return cf.Position.X + localX * cf.XVector.X + localY * cf.YVector.X
	end

	-- The strap's two faces at height y along the line z = TIE_Z: { outer x, inner x } (nil when the strap isn't there).
	local function strapFaces(strap: { BasePart }, y: number): (number?, number?)
		local outer: number? = nil
		local inner: number? = nil
		for _, part in strap do
			for _, side in { -1, 1 } do
				local x = faceX(part, side, y)
				if x ~= nil then
					outer = if outer == nil then x else math.min(outer, x)
					inner = if inner == nil then x else math.max(inner, x)
				end
			end
		end
		return outer, inner
	end

	-- The head's left surface |x| at height y (a ray in from the left, ignoring guards, mockups and the tie).
	local function headSurface(tie: Instance, y: number): number?
		local hit = Workspace:Raycast(Vector3.new(-80, y, TIE_Z), Vector3.new(80, 0, 0), worldParams(tie))
		if hit == nil then
			return nil
		end
		return -hit.Position.X
	end

	local function strapCentre(strap: { BasePart }, y: number): number?
		local outer, inner = strapFaces(strap, y)
		if outer == nil or inner == nil then
			return nil
		end
		return (outer + inner) / 2
	end

	-- The nearest point of a part's box to a world point, as a distance (0 when the point is inside the box).
	local function distanceToBox(part: BasePart, point: Vector3): number
		local local_ = part.CFrame:PointToObjectSpace(point)
		local half = part.Size / 2
		local outside = Vector3.new(
			math.max(math.abs(local_.X) - half.X, 0),
			math.max(math.abs(local_.Y) - half.Y, 0),
			math.max(math.abs(local_.Z) - half.Z, 0)
		)
		return outside.Magnitude
	end

	it("the left tie hangs on the measured route, 2.7 wide and 0.6 thick", function()
		local tie = findTie()
		local strap = partsNamed(tie, "Strap_")
		expect(#strap > 0).toBe(true)
		local problems: { string } = {}
		for _, part in strap do
			if math.abs(part.Size.Z - STRAP_WIDTH) > 0.05 or math.abs(part.Size.X - STRAP_THICK) > 0.05 then
				table.insert(
					problems,
					`{part.Name} is {part.Size.X} x {part.Size.Z} (needs {STRAP_THICK} x {STRAP_WIDTH})`
				)
			end
			if math.abs(part.Position.Z - TIE_Z) > 0.05 then
				table.insert(problems, `{part.Name} centre z is {part.Position.Z} (needs {TIE_Z})`)
			end
		end
		for _, row in ROUTE do
			local y = if row[1] == BOTTOM_Y
				then BOTTOM_Y + END_INSIDE
				elseif row[1] == TOP_Y then TOP_Y - END_INSIDE
				else row[1]
			local wanted = tableX(y)
			local centre = strapCentre(strap, y)
			if centre == nil then
				table.insert(problems, `no strap at y {y}`)
			elseif math.abs(-centre - wanted) > ROUTE_SLACK then
				table.insert(problems, `strap centre |x| at y {y} is {-centre} (table {wanted})`)
			end
		end
		expect(problems).toEqual({})
	end)

	it("no part of the left tie leans over the climber", function()
		local tie = findTie()
		local strap = partsNamed(tie, "Strap_")
		expect(#strap > 0).toBe(true)
		local problems: { string } = {}
		local innerAt: { [number]: number } = {}
		local surfaceAt: { [number]: number } = {}
		local lastCentre: number? = nil
		for y = BOTTOM_Y, TOP_Y do
			local sample = if y == BOTTOM_Y then y + END_NUDGE elseif y == TOP_Y then y - END_NUDGE else y
			local outer, inner = strapFaces(strap, sample)
			local surface = headSurface(tie, y)
			if outer == nil or inner == nil or surface == nil then
				table.insert(problems, `y {y}: strap or head surface not found`)
			else
				innerAt[y] = -inner
				surfaceAt[y] = surface
				local centre = -(outer + inner) / 2
				if lastCentre ~= nil and centre > lastCentre + 0.01 then
					table.insert(problems, `y {y}: strap |x| grows going up ({lastCentre} to {centre})`)
				end
				lastCentre = centre
			end
		end
		local highest = 0 -- the largest head |x| at this height and every height above
		for y = TOP_Y, BOTTOM_Y, -1 do
			highest = math.max(highest, surfaceAt[y] or 0)
			local inner = innerAt[y]
			if inner ~= nil and inner < highest + HEAD_GAP then
				table.insert(
					problems,
					`y {y}: inner face {inner} is under {highest + HEAD_GAP} (head {highest} + {HEAD_GAP})`
				)
			end
		end
		expect(problems).toEqual({})
	end)

	it("the knots are the strap's width and 2 studs apart, foot to top", function()
		local tie = findTie()
		local strap = partsNamed(tie, "Strap_")
		local knots = partsNamed(tie, "Climb_")
		expect(#knots > 1).toBe(true)
		table.sort(knots, function(a: BasePart, b: BasePart)
			return a.Position.Y < b.Position.Y
		end)
		local problems: { string } = {}
		for index, knot in knots do
			if math.abs(knot.Size.Z - STRAP_WIDTH) > 0.05 then
				table.insert(problems, `{knot.Name} is {knot.Size.Z} wide (needs {STRAP_WIDTH})`)
			end
			if math.abs(knot.Position.Z - TIE_Z) + knot.Size.Z / 2 > STRAP_WIDTH / 2 + 0.05 then
				table.insert(problems, `{knot.Name} sticks out of the strap's width`)
			end
			local centre = strapCentre(strap, math.clamp(knot.Position.Y, BOTTOM_Y + END_NUDGE, TOP_Y - END_NUDGE))
			if centre == nil or math.abs(knot.Position.X - centre) > STRAP_THICK / 2 then
				table.insert(problems, `{knot.Name} is off the strap line (x {knot.Position.X}, strap {centre})`)
			end
			if index > 1 and math.abs(knot.Position.Y - knots[index - 1].Position.Y - KNOT_GAP) > 0.1 then
				table.insert(
					problems,
					`{knot.Name} is {knot.Position.Y - knots[index - 1].Position.Y} above the one below`
				)
			end
		end
		if knots[1].Position.Y < BOTTOM_Y or knots[1].Position.Y > BOTTOM_Y + KNOT_GAP then
			table.insert(
				problems,
				`the lowest knot is at y {knots[1].Position.Y} (needs {BOTTOM_Y} to {BOTTOM_Y + KNOT_GAP})`
			)
		end
		local top = knots[#knots].Position.Y
		if top > TOP_Y or top < TOP_Y - KNOT_GAP then
			table.insert(problems, `the highest knot is at y {top} (needs {TOP_Y - KNOT_GAP} to {TOP_Y})`)
		end
		expect(problems).toEqual({})
	end)

	it("the pom-pom sits on the pillow at the tie's foot, with a floor 2 studs out", function()
		local tie = findTie()
		local pomPom = tie:FindFirstChild("PomPom") :: BasePart?
		expect(pomPom).never.toBeNil()
		local part = pomPom :: BasePart
		local problems: { string } = {}
		for _, size in { part.Size.X, part.Size.Y, part.Size.Z } do
			if math.abs(size - POMPOM_SIZE) > 0.1 then
				table.insert(problems, `PomPom is {part.Size} (needs {POMPOM_SIZE} each way)`)
				break
			end
		end
		if (part.Position - POMPOM_AT).Magnitude > 0.2 then
			table.insert(problems, `PomPom is at {part.Position} (needs {POMPOM_AT})`)
		end
		local hit = Workspace:Raycast(Vector3.new(FLOOR_AT.X, 150, TIE_Z), Vector3.new(0, -250, 0), worldParams(tie))
		if hit == nil or hit.Instance:FindFirstAncestor("Pillow") == nil then
			table.insert(
				problems,
				`the floor 2 studs out is not the pillow ({if hit then hit.Instance:GetFullName() else "nothing"})`
			)
		elseif math.abs(hit.Position.Y - FLOOR_AT.Y) > 0.3 then
			table.insert(problems, `the floor 2 studs out is at y {hit.Position.Y} (needs {FLOOR_AT.Y})`)
		end
		expect(problems).toEqual({})
	end)

	it("the landing fold is 6 by 6, lies on the cap, and every edge is at most 0.5 studs off it", function()
		local tie = findTie()
		local landing = tie:FindFirstChild("Landing") :: BasePart?
		expect(landing).never.toBeNil()
		local part = landing :: BasePart
		local problems: { string } = {}
		if math.abs(part.Size.X - LANDING_SIZE) > 0.05 or math.abs(part.Size.Z - LANDING_SIZE) > 0.05 then
			table.insert(problems, `Landing is {part.Size.X} x {part.Size.Z} (needs {LANDING_SIZE} x {LANDING_SIZE})`)
		end
		-- Points every 0.5 studs along the four bottom edges. A ray down from each, with the tie left out, finds the cap.
		local params = worldParams(tie)
		local half = LANDING_SIZE / 2
		local bottom = -part.Size.Y / 2
		local lowU = if part.CFrame.RightVector.Y > 0 then -half else half -- the outer (low) edge
		local worst, worstAt = 0, ""
		local lowTotal, lowCount = 0, 0
		local function read(u: number, v: number)
			local point = part.CFrame:PointToWorldSpace(Vector3.new(u, bottom, v))
			local hit = Workspace:Raycast(Vector3.new(point.X, 200, point.Z), Vector3.new(0, -250, 0), params)
			if hit == nil then
				table.insert(problems, `no cap under the bottom edge at x {point.X}, z {point.Z}`)
				return
			end
			local off = point.Y - hit.Position.Y
			if math.abs(off) > worst then
				worst, worstAt = math.abs(off), `x {point.X}, z {point.Z}`
			end
			if u == lowU then
				lowTotal += off
				lowCount += 1
			end
		end
		for step = 0, 2 * LANDING_SIZE do
			local along = -half + step * 0.5
			read(along, -half)
			read(along, half)
			read(-half, along)
			read(half, along)
		end
		if worst > FOLD_OFF_MAX then
			table.insert(problems, `an edge is {worst} studs off the cap at {worstAt} (needs at most {FOLD_OFF_MAX})`)
		end
		local lowMean = lowTotal / math.max(lowCount, 1)
		if lowMean < FOLD_LOW_MIN or lowMean > FOLD_LOW_MAX then
			table.insert(
				problems,
				`the low edge is {lowMean} above the cap on average (needs {FOLD_LOW_MIN} to {FOLD_LOW_MAX})`
			)
		end
		expect(problems).toEqual({})
	end)

	it("steps where the tie meets the cap are at most 0.5, and at most 1.5 down the fold's sides", function()
		-- Rays down on a 0.25-stud grid, wide enough to read a walk across the fold from the cap on each side. Two
		-- neighbouring hits on different parts, both standable (normal y at least 0.342, the 70 degree walk limit), differ
		-- by at most 0.5. The one exception is a step between the fold (Landing) and the cap beside it: the fold's sides
		-- step down onto the cap by up to 1.5, low enough to walk up with no jump (spec section 5, "Landing at each tie's
		-- top"; Rule 15: The climb needs no jump). The fold's underside fit is graded by the test above. The rails are walls on purpose, so a pair that has a rail in it is left out.
		-- The step is measured at the seam: each part's surface plane is extended to the midpoint of the two hits and the
		-- two heights are compared there. Raw heights 0.25 apart also differ by the slope, so two parts meeting smoothly on
		-- a steep face would read as a step (Lesson 255: compare two sides at the same spot).
		local tie = findTie()
		local params = worldParams(nil)
		local countX = math.floor((SEAM_X1 - SEAM_X0) / SEAM_STEP + 0.5)
		local countZ = math.floor((SEAM_Z1 - SEAM_Z0) / SEAM_STEP + 0.5)
		local grid: { { RaycastResult? } } = {}
		for i = 0, countX do
			grid[i] = {}
			for j = 0, countZ do
				local origin = Vector3.new(SEAM_X0 + i * SEAM_STEP, 200, SEAM_Z0 + j * SEAM_STEP)
				grid[i][j] = Workspace:Raycast(origin, Vector3.new(0, -250, 0), params)
			end
		end
		local function planeY(hit: RaycastResult, x: number, z: number): number
			local n = hit.Normal
			return hit.Position.Y - (n.X * (x - hit.Position.X) + n.Z * (z - hit.Position.Z)) / n.Y
		end
		type Pair = { count: number, largest: number, x0: number, x1: number, z0: number, z1: number }
		local steps: { string } = {}
		local pairs_: { [string]: Pair } = {}
		local total = 0
		local function compare(a: RaycastResult?, b: RaycastResult?)
			if a == nil or b == nil or a.Instance == b.Instance then
				return
			end
			if a.Normal.Y < WALK_NORMAL_Y or b.Normal.Y < WALK_NORMAL_Y then
				return
			end
			if string.sub(a.Instance.Name, 1, 5) == "Rail_" or string.sub(b.Instance.Name, 1, 5) == "Rail_" then
				return
			end
			local mx = (a.Position.X + b.Position.X) / 2
			local mz = (a.Position.Z + b.Position.Z) / 2
			local step = math.abs(planeY(a, mx, mz) - planeY(b, mx, mz))
			-- Fold side: the fold against a part outside the tie (the cap). The fold against the tie's own parts stays at 0.5.
			local isFoldSide = (a.Instance.Name == "Landing" and not b.Instance:IsDescendantOf(tie))
				or (b.Instance.Name == "Landing" and not a.Instance:IsDescendantOf(tie))
			if step > (if isFoldSide then FOLD_SIDE_MAX_STEP else SEAM_MAX_STEP) then
				total += 1
				local nameA, nameB = a.Instance.Name, b.Instance.Name
				local key = if nameA < nameB then `{nameA} | {nameB}` else `{nameB} | {nameA}`
				local pair = pairs_[key]
				if pair == nil then
					pairs_[key] = { count = 1, largest = step, x0 = mx, x1 = mx, z0 = mz, z1 = mz }
				else
					pair.count += 1
					pair.largest = math.max(pair.largest, step)
					pair.x0, pair.x1 = math.min(pair.x0, mx), math.max(pair.x1, mx)
					pair.z0, pair.z1 = math.min(pair.z0, mz), math.max(pair.z1, mz)
				end
				if #steps < 8 then
					table.insert(
						steps,
						string.format(
							"%.2f at x %.2f z %.2f: %s %.2f vs %s %.2f",
							step,
							mx,
							mz,
							nameA,
							a.Position.Y,
							nameB,
							b.Position.Y
						)
					)
				end
			end
		end
		for i = 0, countX do
			for j = 0, countZ do
				if i < countX then
					compare(grid[i][j], grid[i + 1][j])
				end
				if j < countZ then
					compare(grid[i][j], grid[i][j + 1])
				end
			end
		end
		if total > 0 then
			local lines: { string } = {}
			for key, pair in pairs_ do
				table.insert(
					lines,
					string.format(
						"%s: %d steps, largest %.2f, x %.2f to %.2f, z %.2f to %.2f",
						key,
						pair.count,
						pair.largest,
						pair.x0,
						pair.x1,
						pair.z0,
						pair.z1
					)
				)
			end
			table.sort(lines)
			table.insert(
				steps,
				1,
				`{total} steps over their limit ({SEAM_MAX_STEP} studs, or {FOLD_SIDE_MAX_STEP} down the fold's sides; pairs, then the first 8 steps)`
			)
			for i, line in lines do
				table.insert(steps, i + 1, line)
			end
		end
		expect(steps).toEqual({})
	end)

	it("the guard plate CapSideLeft_28 is gone and kept in the backup, its neighbours stay", function()
		local problems: { string } = {}
		local guards = walkSurfaces():FindFirstChild("SteepGuards") :: Instance
		if guards:FindFirstChild("CapSideLeft_28") ~= nil then
			table.insert(problems, "CapSideLeft_28 is still in SteepGuards")
		end
		local backups = ServerStorage:FindFirstChild("WorldBackups")
		local backup = if backups then backups:FindFirstChild("CapTies") else nil
		if backup == nil or backup:FindFirstChild("CapSideLeft_28") == nil then
			table.insert(problems, "CapSideLeft_28 is not in ServerStorage.WorldBackups.CapTies")
		end
		local stays: { [string]: Vector3 } = {
			CapSideLeft_20 = Vector3.new(-40.8, 97.9, 24.0),
			CapSideLeft_36 = Vector3.new(-42.2, 97.9, 40.0),
		}
		for name, spot in stays do
			local plate = guards:FindFirstChild(name) :: BasePart?
			if plate == nil then
				table.insert(problems, `{name} is gone from SteepGuards`)
			elseif (plate.Position - spot).Magnitude > 0.05 then
				table.insert(problems, `{name} moved to {plate.Position} (was {spot})`)
			end
		end
		expect(problems).toEqual({})
	end)

	it("no guard plate stands within 1.5 studs of the left strap", function()
		local tie = findTie()
		local strap = partsNamed(tie, "Strap_")
		expect(#strap > 0).toBe(true)
		local guards = (walkSurfaces():FindFirstChild("SteepGuards") :: Instance):GetChildren()
		local problems: { string } = {}
		local reported: { [string]: boolean } = {}
		for _, part in strap do
			-- sample the strap's box: 3 across its thickness, every 0.5 along its length, 7 across its width
			local steps = math.max(math.ceil(part.Size.Y / 0.5), 1)
			for ix = -1, 1 do
				for iy = 0, steps do
					for iz = -3, 3 do
						local offset =
							Vector3.new(ix * part.Size.X / 2, (iy / steps - 0.5) * part.Size.Y, iz * part.Size.Z / 6)
						local point = part.CFrame:PointToWorldSpace(offset)
						for _, guard in guards do
							if
								guard:IsA("BasePart")
								and not reported[guard.Name]
								and distanceToBox(guard, point) < PLATE_CLEARANCE
							then
								reported[guard.Name] = true
								table.insert(problems, `{guard.Name} is within {PLATE_CLEARANCE} studs of {part.Name}`)
							end
						end
					end
				end
			end
		end
		expect(problems).toEqual({})
	end)

	-- A hidden climbing piece: invisible, no shadow, anchored and solid (strips also findable and touchable).
	local function checkHidden(part: BasePart, problems: { string }, findable: boolean)
		if part.Transparency ~= 1 or part.CastShadow or not part.Anchored then
			table.insert(
				problems,
				`{part.Name} is not hidden (Transparency {part.Transparency}, CastShadow {part.CastShadow})`
			)
		end
		if not part.CanCollide or (findable and not (part.CanQuery and part.CanTouch)) then
			table.insert(problems, `{part.Name} is not solid{if findable then ", findable and touchable" else ""}`)
		end
	end

	-- A pair of trusses: 2 TrussParts, 2 wide in x and z, at z 31.65 and 32.35, hidden and solid.
	local function checkTrussPair(pair: { BasePart }, label: string, problems: { string })
		if #pair ~= 2 then
			table.insert(problems, `{label}: {#pair} trusses (needs 2)`)
			return
		end
		table.sort(pair, function(a: BasePart, b: BasePart)
			return a.Position.Z < b.Position.Z
		end)
		for index, part in pair do
			local wantedZ = TIE_Z + (if index == 1 then -TRUSS_Z_OFFSET else TRUSS_Z_OFFSET)
			if not part:IsA("TrussPart") then
				table.insert(problems, `{part.Name} is a {part.ClassName} (needs a TrussPart)`)
			end
			if math.abs(part.Size.X - 2) > 0.05 or math.abs(part.Size.Z - 2) > 0.05 then
				table.insert(problems, `{part.Name} is {part.Size.X} x {part.Size.Z} across (needs 2 x 2)`)
			end
			if math.abs(part.Position.Z - wantedZ) > 0.05 then
				table.insert(problems, `{part.Name} centre z is {part.Position.Z} (needs {wantedZ})`)
			end
			checkHidden(part, problems, false)
		end
	end

	it("the strap, knots, stripes, trim and pom-pom are look-only, and the landing stays solid", function()
		local tie = findTie()
		local problems: { string } = {}
		for _, prefix in { "Strap_", "Climb_", "Stripe_", "Trim_", "PomPom" } do
			local parts = partsNamed(tie, prefix)
			if #parts == 0 then
				table.insert(problems, `no {prefix} parts in the tie`)
			end
			for _, part in parts do
				if part.CanCollide or part.CanQuery or part.CanTouch then
					table.insert(
						problems,
						`{part.Name} is not look-only (CanCollide {part.CanCollide}, CanQuery {part.CanQuery}, CanTouch {part.CanTouch})`
					)
				end
			end
		end
		local landing = tie:FindFirstChild("Landing") :: BasePart?
		if landing == nil or not landing.CanCollide then
			table.insert(problems, "Landing is missing or not solid")
		end
		expect(problems).toEqual({})
	end)

	it("the upright truss pair runs from the pillow to y 84.4, outer face at x -37.10", function()
		local tie = findTie()
		local pair = partsNamed(tie, "ClimbTrussUp_")
		local problems: { string } = {}
		checkTrussPair(pair, "upright trusses", problems)
		for _, part in pair do
			local outerFace = faceX(part, -1, part.Position.Y)
			if outerFace == nil or math.abs(outerFace - UP_OUTER_X) > 0.05 then
				table.insert(problems, `{part.Name} outer face x is {outerFace} (needs {UP_OUTER_X})`)
			end
			local top = part.Position.Y + part.Size.Y / 2
			local bottom = part.Position.Y - part.Size.Y / 2
			if math.abs(top - UP_TOP_Y) > 0.05 then
				table.insert(problems, `{part.Name} top is y {top} (needs {UP_TOP_Y})`)
			end
			local start = Vector3.new(part.Position.X, bottom + 3, part.Position.Z)
			local floor = Workspace:Raycast(start, Vector3.new(0, -10, 0), worldParams(tie))
			if floor == nil then
				table.insert(problems, `{part.Name}: no floor found under it`)
			elseif bottom > floor.Position.Y + 0.05 then
				table.insert(problems, `{part.Name} bottom y {bottom} is above the pillow floor {floor.Position.Y}`)
			end
		end
		expect(problems).toEqual({})
	end)

	it("the leaning truss pair runs from y 84.5 to y 100 at 4.6 degrees toward his head", function()
		local tie = findTie()
		local pair = partsNamed(tie, "ClimbTrussLean_")
		local problems: { string } = {}
		checkTrussPair(pair, "leaning trusses", problems)
		for _, part in pair do
			local up = part.CFrame.YVector
			local tilt = math.deg(math.atan2(up.X, up.Y)) -- plus means leaning toward x 0 (his head) for the left tie
			if math.abs(tilt - LEAN_TILT) > 0.1 then
				table.insert(problems, `{part.Name} leans {tilt} degrees (needs {LEAN_TILT} toward his head)`)
			end
			for _, end_ in { { LEAN_LOW_Y, LEAN_LOW_X }, { LEAN_HIGH_Y, LEAN_HIGH_X } } do
				local outerFace = faceX(part, -1, end_[1])
				if outerFace == nil or math.abs(outerFace - end_[2]) > 0.05 then
					table.insert(problems, `{part.Name} outer face x at y {end_[1]} is {outerFace} (needs {end_[2]})`)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it(
		"the walk strip copies the strap's top two pieces, 0.3 longer, the strap ends under the fold, and the top knots sit on its outer face",
		function()
			local tie = findTie()
			local problems: { string } = {}
			local strips: { BasePart } = {}
			for _, number in { "04", "05" } do
				local strap = tie:FindFirstChild(`Strap_{number}`) :: BasePart?
				local strip = tie:FindFirstChild(`WalkStrip_{number}`) :: BasePart?
				if strap == nil or strip == nil then
					table.insert(problems, `Strap_{number} or WalkStrip_{number} is missing`)
				else
					table.insert(strips, strip)
					if
						strip.CFrame.Position:FuzzyEq(strap.CFrame.Position, 0.05) == false
						or strip.CFrame.XVector:FuzzyEq(strap.CFrame.XVector, 0.001) == false
						or strip.CFrame.YVector:FuzzyEq(strap.CFrame.YVector, 0.001) == false
					then
						table.insert(problems, `WalkStrip_{number} is not at Strap_{number}'s CFrame`)
					end
					if
						math.abs(strip.Size.X - strap.Size.X) > 0.05
						or math.abs(strip.Size.Z - strap.Size.Z) > 0.05
						or math.abs(strip.Size.Y - strap.Size.Y - STRIP_EXTRA) > 0.05
					then
						table.insert(problems, `WalkStrip_{number} is {strip.Size} (needs {strap.Size} + 0.3 long)`)
					end
					checkHidden(strip, problems, true)
				end
			end
			for _, extra in { "Strap_06", "WalkStrip_06" } do
				if tie:FindFirstChild(extra) ~= nil then
					table.insert(problems, `{extra} is built (the strap ends under the fold)`)
				end
			end
			local topStrap = tie:FindFirstChild("Strap_05") :: BasePart?
			local fold = tie:FindFirstChild("Landing") :: BasePart?
			if topStrap ~= nil and fold ~= nil then
				local halfLength = topStrap.Size.Y / 2
				local up = topStrap.CFrame.YVector
				local topEnd = topStrap.Position + up * (if up.Y > 0 then halfLength else -halfLength)
				local lowEdgeX = 0 -- the fold's bottom outer corner, as |x|
				for _, cornerX in { -1, 1 } do
					for _, cornerZ in { -1, 1 } do
						local corner = fold.CFrame:PointToWorldSpace(
							Vector3.new(cornerX * fold.Size.X / 2, -fold.Size.Y / 2, cornerZ * fold.Size.Z / 2)
						)
						lowEdgeX = math.max(lowEdgeX, math.abs(corner.X))
					end
				end
				local past = lowEdgeX - math.abs(topEnd.X)
				if past < 0 or past > 0.3 then
					table.insert(
						problems,
						`Strap_05's top end is {past} studs past the fold's low edge (needs 0 to 0.3; end |x| {math.abs(
							topEnd.X
						)}, edge |x| {lowEdgeX})`
					)
				end
			end
			for _, knot in partsNamed(tie, "Climb_") do
				if knot.Position.Y > STRIP_FROM_Y then
					local wanted: number? = nil
					for _, strip in strips do
						wanted = faceX(strip, -1, knot.Position.Y)
						if wanted ~= nil then
							break
						end
					end
					local knotOuter = knot.Position.X - knot.Size.X / 2
					if wanted == nil or math.abs(knotOuter - wanted) > 0.2 then
						table.insert(
							problems,
							`{knot.Name} outer x {knotOuter} is not on the strip's outer face {wanted}`
						)
					end
				end
			end
			expect(problems).toEqual({})
		end
	)

	it("a rail stands each side of the strip from y 100 to y 110, none on the top piece", function()
		local tie = findTie()
		local problems: { string } = {}
		local rails = partsNamed(tie, "Rail_")
		if #rails ~= 4 then
			table.insert(problems, `{#rails} rails (needs 4)`)
		end
		for _, number in { "04", "05" } do
			local strip = tie:FindFirstChild(`WalkStrip_{number}`) :: BasePart?
			local railInnerZ: { [string]: number } = { A = TIE_Z - RAIL_INNER, B = TIE_Z + RAIL_INNER }
			for letter, innerZ in railInnerZ do
				local rail = tie:FindFirstChild(`Rail_{number}_{letter}`) :: BasePart?
				if rail == nil or strip == nil then
					table.insert(problems, `Rail_{number}_{letter} or WalkStrip_{number} is missing`)
				else
					local face = if letter == "A"
						then rail.Position.Z + rail.Size.Z / 2
						else rail.Position.Z - rail.Size.Z / 2
					if math.abs(face - innerZ) > 0.05 then
						table.insert(problems, `Rail_{number}_{letter} inner face z is {face} (needs {innerZ})`)
					end
					if
						math.abs(rail.Size.Y - strip.Size.Y) > 0.05
						or rail.Position.Y < STRIP_FROM_Y
						or rail.Position.Y > RAILS_TO_Y
					then
						table.insert(problems, `Rail_{number}_{letter} is {rail.Size.Y} long at y {rail.Position.Y}`)
					end
					checkHidden(rail, problems, false)
				end
			end
		end
		if tie:FindFirstChild("Rail_06_A") ~= nil or tie:FindFirstChild("Rail_06_B") ~= nil then
			table.insert(problems, "there is a rail on WalkStrip_06")
		end
		expect(problems).toEqual({})
	end)

	it("between the rails, the ground from the truss top to the strip face rises with no shelf", function()
		local tie = findTie()
		local problems: { string } = {}
		local wedge = tie:FindFirstChild("ShelfWedge") :: BasePart?
		if wedge == nil then
			table.insert(problems, "ShelfWedge is missing")
		else
			if not wedge:IsA("WedgePart") then
				table.insert(problems, `ShelfWedge is a {wedge.ClassName} (needs a WedgePart)`)
			end
			checkHidden(wedge, problems, true)
		end
		local params = worldParams(nil)
		for _, z in { 31, 32, 33 } do
			local hits: { number } = {}
			for index = 0, WEDGE_STEPS do
				local x = WEDGE_FROM_X + index * 0.1
				local hit = Workspace:Raycast(Vector3.new(x, 104, z), Vector3.new(0, -10, 0), params)
				if hit == nil then
					table.insert(problems, `no ground at x {x}, z {z}`)
					break
				end
				table.insert(hits, hit.Position.Y)
			end
			for index = 2, #hits do
				local x = WEDGE_FROM_X + (index - 1) * 0.1
				if hits[index] < hits[index - 1] - 0.001 or hits[index] - hits[index - 1] > 0.5 then
					table.insert(problems, `z {z}: the ground goes {hits[index - 1]} to {hits[index]} at x {x}`)
				end
				if index > 4 and hits[index] - hits[index - 3] < 0.1 then
					table.insert(
						problems,
						`z {z}: a shelf, only {hits[index] - hits[index - 3]} of rise over 0.3 studs ending at x {x}`
					)
				end
				if index > 6 and hits[index] - hits[index - 5] < 0.2 then
					table.insert(
						problems,
						`z {z}: only {hits[index] - hits[index - 5]} of rise over 0.5 studs ending at x {x}`
					)
				end
			end
		end
		expect(problems).toEqual({})
	end)
end)
