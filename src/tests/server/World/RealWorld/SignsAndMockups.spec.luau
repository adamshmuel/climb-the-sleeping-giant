--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

-- The two name faces on each garden's gate sign. They are thin, almost invisible parts with a SurfaceGui and a
-- TextLabel. The board is not its own part: it is part of the gate's one mesh (SafeGate.body.body_geom), so the
-- board has to be found with rays. They are placed by tools/world/11-sign-faces.luau.
describe("the real world, the garden sign faces", function()
	local FACE_WIDTH = 4.4
	local FACE_HEIGHT = 1.6
	local FACE_THICKNESS = 0.05
	local GAP = 0.35 -- studs from the board's furthest point on the face's side to the face's middle
	local GAP_TOLERANCE = 0.02
	local GRID_STEP = 0.2
	local RAY_START = 15 -- studs out from the face before the ray travels back toward the board
	-- Where the front face's middle sits across the gate mesh and up it (the mesh's own X and Y), the same for all 8
	-- gardens. Only the depth is allowed to change.
	local MIDDLE_ACROSS = -0.0058
	local MIDDLE_UP = 4.225

	local function gardens(): { { number: number, gate: Model, mesh: MeshPart, front: Part, back: Part } }
		local world = game:GetService("Workspace"):FindFirstChild("World")
		expect(world).never.toBeNil()
		local plots = (world :: Instance):FindFirstChild("Plots")
		expect(plots).never.toBeNil()
		local found = {}
		for number = 1, 8 do
			local plot = (plots :: Instance):FindFirstChild(`Plot_{number}`)
			expect(plot).never.toBeNil()
			local gate = (plot :: Instance):FindFirstChild("SafeGate")
			expect(gate).never.toBeNil()
			local mesh = (gate :: Instance):FindFirstChild("body")
			expect(mesh).never.toBeNil()
			local geometry = (mesh :: Instance):FindFirstChild("body_geom")
			expect(geometry).never.toBeNil()
			local front = (gate :: Instance):FindFirstChild("SignFace")
			local back = (gate :: Instance):FindFirstChild("SignFaceBack")
			expect(front).never.toBeNil()
			expect(back).never.toBeNil()
			table.insert(found, {
				number = number,
				gate = gate :: Model,
				mesh = geometry :: MeshPart,
				front = front :: Part,
				back = back :: Part,
			})
		end
		return found
	end

	-- How far (in studs) a face's middle is out from the mesh's furthest point on the face's own side. The rays start
	-- RAY_START studs out from the face and travel straight at the mesh, on a grid over the face's rectangle. Each ray
	-- keeps the first hit (the one nearest the face's side). The furthest point is the largest depth of those hits.
	local function gapToBoard(face: BasePart, mesh: MeshPart): number
		local out = face.CFrame.LookVector
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { mesh }
		local columns = math.round(face.Size.X / GRID_STEP)
		local rows = math.round(face.Size.Y / GRID_STEP)
		local furthest = -math.huge
		local hits = 0
		for column = 0, columns do
			for row = 0, rows do
				local across = -face.Size.X / 2 + column * face.Size.X / columns
				local up = -face.Size.Y / 2 + row * face.Size.Y / rows
				local from = face.CFrame:PointToWorldSpace(Vector3.new(across, up, 0)) + out * RAY_START
				local hit = game:GetService("Workspace"):Raycast(from, -out * (RAY_START * 2), params)
				if hit then
					hits += 1
					furthest = math.max(furthest, hit.Position:Dot(out))
				end
			end
		end
		expect(hits > 0).toBe(true)
		return face.Position:Dot(out) - furthest
	end

	it("makes both faces 4.4 by 1.6 studs and keeps them thin", function()
		for _, garden in gardens() do
			for _, face in { garden.front, garden.back } do
				local size = face.Size
				local text = `garden {garden.number} {face.Name} {size.X}, {size.Y}, {size.Z}`
				local fits = math.abs(size.X - FACE_WIDTH) < 0.001
					and math.abs(size.Y - FACE_HEIGHT) < 0.001
					and math.abs(size.Z - FACE_THICKNESS) < 0.001
				expect(`{text} {fits}`).toBe(`{text} true`)
			end
		end
	end)

	it("keeps the front face's middle across the board and up and down, and its facing", function()
		for _, garden in gardens() do
			local local_ = garden.mesh.CFrame:PointToObjectSpace(garden.front.Position)
			local text = `garden {garden.number} front across {local_.X} up {local_.Y}`
			local kept = math.abs(local_.X - MIDDLE_ACROSS) < 0.01 and math.abs(local_.Y - MIDDLE_UP) < 0.01
			expect(`{text} {kept}`).toBe(`{text} true`)
			-- Faces out of the front of the gate, the same way as the mesh.
			expect(garden.front.CFrame.LookVector:Dot(garden.mesh.CFrame.LookVector) > 0.9999).toBe(true)
		end
	end)

	it("keeps the back face behind the front face, with the same middle, facing the other way", function()
		for _, garden in gardens() do
			local inFront = garden.front.CFrame:PointToObjectSpace(garden.back.Position)
			local text = `garden {garden.number} back in the front face's space {inFront.X}, {inFront.Y}`
			expect(`{text} {math.abs(inFront.X) < 0.01 and math.abs(inFront.Y) < 0.01}`).toBe(`{text} true`)
			expect(garden.front.CFrame.LookVector:Dot(garden.back.CFrame.LookVector) < -0.9999).toBe(true)
			expect((garden.front.CFrame.UpVector - garden.back.CFrame.UpVector).Magnitude < 0.001).toBe(true)
			-- Behind the front face means a positive object-space Z (the face looks out of its own negative Z).
			expect(inFront.Z > 1).toBe(true)
		end
	end)

	it("puts each face 0.35 studs out from the board's furthest point on its own side", function()
		for _, garden in gardens() do
			for _, face in { garden.front, garden.back } do
				local gap = gapToBoard(face, garden.mesh)
				local text = `garden {garden.number} {face.Name} is {string.format("%.3f", gap)} studs out`
				expect(`{text} {math.abs(gap - GAP) <= GAP_TOLERANCE}`).toBe(`{text} true`)
			end
		end
	end)

	it("sees a face that is moved 0.1 studs out of place", function()
		-- A scratch copy (never put in the world): first set right by the ray rule, then moved 0.1 studs.
		local garden = gardens()[1]
		for _, face in { garden.front, garden.back } do
			local scratch = face:Clone()
			scratch.Size = Vector3.new(FACE_WIDTH, FACE_HEIGHT, FACE_THICKNESS)
			scratch.CFrame = scratch.CFrame * CFrame.new(0, 0, gapToBoard(scratch, garden.mesh) - GAP)
			expect(math.abs(gapToBoard(scratch, garden.mesh) - GAP) <= GAP_TOLERANCE).toBe(true)
			local right = scratch.CFrame
			scratch.CFrame = right * CFrame.new(0, 0, -0.1) -- 0.1 studs further out
			expect(math.abs(gapToBoard(scratch, garden.mesh) - GAP) <= GAP_TOLERANCE).toBe(false)
			scratch.CFrame = right * CFrame.new(0, 0, 0.1) -- 0.1 studs further in
			expect(math.abs(gapToBoard(scratch, garden.mesh) - GAP) <= GAP_TOLERANCE).toBe(false)
			scratch:Destroy()
		end
	end)

	it("sizes each canvas to the face, so the words are not stretched", function()
		for _, garden in gardens() do
			for _, face in { garden.front, garden.back } do
				local surface = face:FindFirstChild("SurfaceGui")
				expect(surface).never.toBeNil()
				local gui = surface :: SurfaceGui
				local text = `garden {garden.number} {face.Name} canvas {gui.CanvasSize.X}, {gui.CanvasSize.Y}`
				local right = math.abs(gui.CanvasSize.X - face.Size.X * gui.PixelsPerStud) < 0.5
					and math.abs(gui.CanvasSize.Y - face.Size.Y * gui.PixelsPerStud) < 0.5
				expect(`{text} {right}`).toBe(`{text} true`)
				expect(gui.Face).toBe(Enum.NormalId.Front)
				expect(gui.SizingMode).toBe(Enum.SurfaceGuiSizingMode.FixedSize)
				local label = gui:FindFirstChild("TextLabel")
				expect(label).never.toBeNil()
				local textLabel = label :: TextLabel
				expect(textLabel.TextScaled).toBe(true)
				expect(textLabel.TextWrapped).toBe(true)
				expect(textLabel.Size).toEqual(UDim2.fromScale(1, 1))
			end
		end
	end)
end)

-- Designer's mockup folders (Workspace.Mockup_*) are not part of the game. tools/world/11a-mockups-hands-off.luau
-- makes every part in them not solid, not found by ray or box checks and not touchable, after saving each part's own
-- three values as attributes so nothing designer set is lost.
describe("the real world, the mockup folders", function()
	local function mockupParts(): { BasePart }
		local found: { BasePart } = {}
		for _, child in game:GetService("Workspace"):GetChildren() do
			if string.sub(child.Name, 1, 7) == "Mockup_" then
				if child:IsA("BasePart") then
					table.insert(found, child)
				end
				for _, descendant in child:GetDescendants() do
					if descendant:IsA("BasePart") then
						table.insert(found, descendant)
					end
				end
			end
		end
		return found
	end

	-- A short list of full names, so a failure names the parts (and does not print thousands of lines).
	local function names(parts: { BasePart }): { string }
		local list: { string } = {}
		for index, part in parts do
			if index > 10 then
				table.insert(list, `... and {#parts - 10} more`)
				break
			end
			table.insert(list, part:GetFullName())
		end
		return list
	end

	it("nothing in a mockup folder is solid, found by ground checks or touchable", function()
		local on: { BasePart } = {}
		for _, part in mockupParts() do
			if part.CanCollide or part.CanQuery or part.CanTouch then
				table.insert(on, part)
			end
		end
		expect(names(on)).toEqual({})
	end)

	it("every part in a mockup folder kept its own three values as attributes", function()
		local missing: { BasePart } = {}
		for _, part in mockupParts() do
			for _, attribute in { "MockupCanCollide", "MockupCanQuery", "MockupCanTouch" } do
				if typeof(part:GetAttribute(attribute)) ~= "boolean" then
					table.insert(missing, part)
					break
				end
			end
		end
		expect(names(missing)).toEqual({})
	end)
end)

-- Nothing in designer's mockup folders (Workspace.Mockup_*) may show in Play: they are mockup pieces, not the game.
-- tools/world/11b-mockups-out-of-sight.luau makes every part, decal and texture fully see-through, switches off every
-- label, screen and effect, and hides the name of every avatar, after saving each old value as an attribute
-- (MockupTransparency, MockupEnabled or MockupDisplayDistanceType), so designer can show a mockup again for a shot.
describe("the real world, the mockup folders are out of sight", function()
	local SWITCHED_CLASSES = {
		"BillboardGui",
		"SurfaceGui",
		"Beam",
		"Trail",
		"ParticleEmitter",
		"PointLight",
		"SpotLight",
		"SurfaceLight",
		"Fire",
		"Smoke",
		"Sparkles",
		"Highlight",
	}

	local function isSwitched(instance: Instance): boolean
		for _, className in SWITCHED_CLASSES do
			if instance:IsA(className) then
				return true
			end
		end
		return false
	end

	-- A title, the count and the first 3 full names, so a failure names the objects (and does not print thousands).
	local function describeList(title: string, found: { string }): { string }
		local list: { string } = {}
		if #found == 0 then
			return list
		end
		table.insert(list, `{title}: {#found}`)
		for index, path in found do
			if index > 3 then
				break
			end
			table.insert(list, `  {path}`)
		end
		return list
	end

	it("nothing in a mockup folder shows in Play", function()
		local visible: { string } = {}
		local switchedOn: { string } = {}
		local namesShown: { string } = {}
		local missingSaved: { string } = {}
		for _, folder in game:GetService("Workspace"):GetChildren() do
			if string.sub(folder.Name, 1, 7) ~= "Mockup_" then
				continue
			end
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
					local thing = descendant :: BasePart
					if thing.Transparency ~= 1 then
						table.insert(visible, descendant:GetFullName())
					elseif typeof(descendant:GetAttribute("MockupTransparency")) ~= "number" then
						table.insert(missingSaved, descendant:GetFullName())
					end
				elseif isSwitched(descendant) then
					if (descendant :: any).Enabled then
						table.insert(switchedOn, descendant:GetFullName())
					elseif typeof(descendant:GetAttribute("MockupEnabled")) ~= "boolean" then
						table.insert(missingSaved, descendant:GetFullName())
					end
				elseif descendant:IsA("Humanoid") then
					if descendant.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
						table.insert(namesShown, descendant:GetFullName())
					elseif typeof(descendant:GetAttribute("MockupDisplayDistanceType")) ~= "string" then
						table.insert(missingSaved, descendant:GetFullName())
					end
				end
			end
		end
		local problems: { string } = {}
		for _, line in describeList("parts, decals and textures still visible", visible) do
			table.insert(problems, line)
		end
		for _, line in describeList("labels, screens and effects still on", switchedOn) do
			table.insert(problems, line)
		end
		for _, line in describeList("avatars still showing a name or health bar", namesShown) do
			table.insert(problems, line)
		end
		for _, line in describeList("hidden without a saved value", missingSaved) do
			table.insert(problems, line)
		end
		expect(problems).toEqual({})
	end)
end)

-- Mockup avatars (models with a Humanoid, used to show a player's size in mockup shots) must not stand in the world.
-- A character's body parts are solid again in Play, even with CanCollide off in Edit, so an invisible avatar on a
-- spawn spot or a way up blocks or lifts a real player. tools/world/11c-mockup-avatars-away.luau moves each one to
-- ServerStorage.ArtLibrary.MockupAvatars.<its mockup folder>, so designer can bring one back for a shot.
describe("the real world, no mockup avatar stands in a player's way", function()
	local Workspace = game:GetService("Workspace")

	it("no mockup avatar is left in the Workspace", function()
		local left: { string } = {}
		for _, folder in Workspace:GetChildren() do
			if string.sub(folder.Name, 1, 7) ~= "Mockup_" then
				continue
			end
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("Humanoid") then
					table.insert(left, descendant:GetFullName())
				end
			end
		end
		table.sort(left)
		expect(left).toEqual({})
	end)

	it(
		"the six mockup avatars wait in ServerStorage.ArtLibrary.MockupAvatars, each in its mockup folder's name",
		function()
			local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
			expect(library).never.toBeNil()
			local avatars = (library :: Instance):FindFirstChild("MockupAvatars")
			expect(avatars).never.toBeNil()
			local found: { string } = {}
			for _, descendant in (avatars :: Instance):GetDescendants() do
				if descendant:IsA("Humanoid") then
					table.insert(found, (descendant.Parent :: Instance):GetFullName())
				end
			end
			table.sort(found)
			local base = "ServerStorage.ArtLibrary.MockupAvatars."
			expect(found).toEqual({
				base .. "Mockup_EggRanks.Avatar",
				base .. "Mockup_LadderSlam.Avatar",
				base .. "Mockup_Nests.Avatar",
				base .. "Mockup_Rescue.Avatar",
				base .. "Mockup_WakeUp.Avatar",
				base .. "Mockup_WaysUp.Avatar",
			})
		end
	)

	it("a moved avatar keeps its Mockup attributes", function()
		local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		expect(library).never.toBeNil()
		local avatars = (library :: Instance):FindFirstChild("MockupAvatars")
		expect(avatars).never.toBeNil()
		local without: { string } = {}
		for _, descendant in (avatars :: Instance):GetDescendants() do
			local lacksSaved = false
			if descendant:IsA("BasePart") then
				lacksSaved = typeof(descendant:GetAttribute("MockupTransparency")) ~= "number"
			elseif descendant:IsA("Humanoid") then
				lacksSaved = typeof(descendant:GetAttribute("MockupDisplayDistanceType")) ~= "string"
			end
			if lacksSaved then
				table.insert(without, descendant:GetFullName())
			end
		end
		table.sort(without)
		expect(without).toEqual({})
	end)

	-- Task 6c: tools/world/36-mockups-to-library.luau moves the ways-up mockups out of the Workspace. Every lookup is a
	-- direct child, because ArtLibrary.MockupAvatars also holds a folder called Mockup_WaysUp (the avatar only).
	it("the ways-up mockups wait in ServerStorage.ArtLibrary, none left in the world", function()
		local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		expect(library).never.toBeNil()

		local function folderIn(parent: Instance?, name: string): Folder?
			local child = if parent then parent:FindFirstChild(name) else nil
			if child and child:IsA("Folder") then
				return child
			end
			return nil
		end

		local problems: { string } = {}
		local libraryNests = folderIn(library, "Mockup_Nests")
		if not folderIn(library, "Mockup_WaysUp") then
			table.insert(problems, "missing ArtLibrary.Mockup_WaysUp")
		end
		if not folderIn(libraryNests, "LapBuild_Designer") then
			table.insert(problems, "missing ArtLibrary.Mockup_Nests.LapBuild_Designer")
		end
		local rampBuild = folderIn(libraryNests, "RampBuild_CodeLead")
		if not rampBuild then
			table.insert(problems, "missing ArtLibrary.Mockup_Nests.RampBuild_CodeLead")
		elseif typeof(rampBuild:GetAttribute("LeftStations")) ~= "string" then
			table.insert(problems, "RampBuild_CodeLead lost its LeftStations attribute")
		end

		local worldNests = Workspace:FindFirstChild("Mockup_Nests")
		if Workspace:FindFirstChild("Mockup_WaysUp") then
			table.insert(problems, "still in Workspace: Mockup_WaysUp")
		end
		if worldNests and worldNests:FindFirstChild("LapBuild_Designer") then
			table.insert(problems, "still in Workspace: Mockup_Nests.LapBuild_Designer")
		end
		if worldNests and worldNests:FindFirstChild("RampBuild_CodeLead") then
			table.insert(problems, "still in Workspace: Mockup_Nests.RampBuild_CodeLead")
		end
		expect(problems).toEqual({})
	end)

	-- Plan 5 Task 16b: tools/world/36-mockups-to-library.luau moves the rest of Mockup_Nests (Art and the others) to the library.
	it("the nests mockup waits in ServerStorage.ArtLibrary, none left in the world", function()
		local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		expect(library).never.toBeNil()
		local inLibrary = (library :: Instance):FindFirstChild("Mockup_Nests")
		local inWorld = Workspace:FindFirstChild("Mockup_Nests")
		local art = if inLibrary then inLibrary:FindFirstChild("Art") else nil
		expect({
			inLibrary = inLibrary ~= nil and inLibrary:IsA("Folder"),
			hasArt = art ~= nil,
			inWorld = inWorld ~= nil,
		}).toEqual({ inLibrary = true, hasArt = true, inWorld = false })
	end)

	-- Plan 4 Task 2: tools/world/28-rank-eggs.luau turns the Epic and Legendary mockup eggs into templates and sends the
	-- rest of Mockup_EggRanks to the library. ArtLibrary.MockupAvatars holds another Mockup_EggRanks (the avatar only),
	-- so the lookup is a direct child.
	it("the egg-ranks mockup waits in ServerStorage.ArtLibrary, none left in the world", function()
		local library = game:GetService("ServerStorage"):FindFirstChild("ArtLibrary")
		expect(library).never.toBeNil()
		local inLibrary = (library :: Instance):FindFirstChild("Mockup_EggRanks")
		local inWorld = Workspace:FindFirstChild("Mockup_EggRanks")
		expect({ inLibrary = inLibrary ~= nil and inLibrary:IsA("Folder"), inWorld = inWorld ~= nil }).toEqual({
			inLibrary = true,
			inWorld = false,
		})
	end)
end)

-- The 85% warning's world pieces (V2 new-player safety, Task 7). tools/world/12-warning85.luau moves designer's tested
-- snort nose and bubble out of Workspace.Mockup_Warning85 into World.GiantFX, gives them their saved values back and
-- sends the rest of the mockup to ServerStorage.ArtLibrary. The tested values are in docs/design/v2/style-guide.md,
-- "The 85% warning: tested values (2026-10-19)".
describe("the real world, the 85% warning pieces", function()
	local Workspace = game:GetService("Workspace")

	local function giantFx(): Instance
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local fx = (world :: Instance):FindFirstChild("GiantFX")
		expect(fx).never.toBeNil()
		return fx :: Instance
	end

	-- The names of every Mockup* attribute left on an instance, as a list, so a failure names them.
	local function mockupAttributes(instance: Instance): { string }
		local found: { string } = {}
		for name in instance:GetAttributes() do
			if string.sub(name, 1, 6) == "Mockup" then
				table.insert(found, name)
			end
		end
		table.sort(found)
		return found
	end

	local function sequenceText(keypoints: { NumberSequenceKeypoint }): string
		local parts: { string } = {}
		for _, keypoint in keypoints do
			table.insert(parts, `{string.format("%.2f", keypoint.Time)}:{string.format("%.2f", keypoint.Value)}`)
		end
		return table.concat(parts, ",")
	end

	it("the snort nose sits at his nose tip, 2 by 0.4 by 2, untouchable, with the tested puff", function()
		local nose = giantFx():FindFirstChild("SnortNose")
		expect(nose).never.toBeNil()
		local part = nose :: BasePart
		expect(part:IsA("BasePart")).toBe(true)
		expect((part.Position - Vector3.new(0, 89, -14)).Magnitude < 0.01).toBe(true)
		expect((part.Size - Vector3.new(2, 0.4, 2)).Magnitude < 0.01).toBe(true)
		expect(part.CanCollide).toBe(false)
		expect(part.CanQuery).toBe(false)
		expect(part.CanTouch).toBe(false)
		expect(part.Transparency).toBe(1)
		expect(part.Anchored).toBe(true)
		-- the top face points out and up from his face
		expect((part.CFrame.UpVector - Vector3.new(0, 0.5, -0.87)).Magnitude < 0.01).toBe(true)
		expect(mockupAttributes(part)).toEqual({})

		local puff = part:FindFirstChild("SnortPuff")
		expect(puff).never.toBeNil()
		local emitter = puff :: ParticleEmitter
		expect(emitter:IsA("ParticleEmitter")).toBe(true)
		expect(mockupAttributes(emitter)).toEqual({})
		expect(emitter.Enabled).toBe(false)
		expect(emitter.Rate).toBe(0)
		expect(emitter.EmissionDirection).toBe(Enum.NormalId.Top)
		expect(emitter.Texture).toBe("rbxasset://textures/particles/smoke_main.dds")
		local colour = emitter.Color.Keypoints[1].Value
		expect(math.abs(colour.R - 0.921569) < 0.001 and math.abs(colour.G - 0.960784) < 0.001 and colour.B == 1).toBe(
			true
		)
		expect(sequenceText(emitter.Size.Keypoints)).toBe("0.00:6.00,1.00:20.00")
		expect(emitter.Speed).toEqual(NumberRange.new(18, 24))
		expect(emitter.SpreadAngle).toEqual(Vector2.new(25, 25))
		expect(emitter.Drag).toBe(2)
		expect(emitter.Lifetime).toEqual(NumberRange.new(1.2, 1.8))
		expect(sequenceText(emitter.Transparency.Keypoints)).toBe("0.00:0.10,0.60:0.40,1.00:1.00")
		expect(math.abs(emitter.LightEmission - 0.3) < 0.001).toBe(true)
		expect(math.abs(emitter.LightInfluence - 0.6) < 0.001).toBe(true)
	end)

	it("the 85% bubble waits, off, in the Z Z Z emitter, with its words and its tail", function()
		local snore = giantFx():FindFirstChild("SnoreEmitter")
		expect(snore).never.toBeNil()
		local bubble = (snore :: Instance):FindFirstChild("Warning85Bubble")
		expect(bubble).never.toBeNil()
		local gui = bubble :: BillboardGui
		expect(gui:IsA("BillboardGui")).toBe(true)
		expect(gui.Enabled).toBe(false)
		expect(mockupAttributes(gui)).toEqual({})
		local frame = gui:FindFirstChild("Frame")
		expect(frame).never.toBeNil()
		local words = (frame :: Instance):FindFirstChild("TextLabel")
		expect(words).never.toBeNil()
		expect((words :: TextLabel).Text).toBe("Mmm... my eggs...")
		local tail = gui:FindFirstChild("Tail")
		expect(tail).never.toBeNil()
		expect((tail :: Instance):IsA("Frame")).toBe(true)
		-- no Mockup* attribute left on any piece of the bubble
		for _, piece in gui:GetDescendants() do
			expect(`{piece:GetFullName()} {table.concat(mockupAttributes(piece), ",")}`).toBe(`{piece:GetFullName()} `)
		end
		-- it draws at the Z Z Z spot (the emitter), never at a part that left for the library
		expect(gui.Adornee).toBeNil()
	end)

	it("nothing named MumbleAnchor is left in the Workspace: the old bubble went to the library", function()
		local left: { string } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == "MumbleAnchor" then
				table.insert(left, descendant:GetFullName())
			end
		end
		expect(left).toEqual({})
	end)

	it("the 85% bubble has no stale Note attribute left", function()
		local snore = giantFx():FindFirstChild("SnoreEmitter")
		expect(snore).never.toBeNil()
		local bubble = (snore :: Instance):FindFirstChild("Warning85Bubble")
		expect(bubble).never.toBeNil()
		expect((bubble :: Instance):GetAttribute("Note")).toBeNil()
	end)

	it("nothing named Mockup_Warning85 is left in the Workspace", function()
		local left: { string } = {}
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == "Mockup_Warning85" then
				table.insert(left, descendant:GetFullName())
			end
		end
		expect(left).toEqual({})
	end)

	it("every part of his eyelids is not solid and not found by checks, so nobody can stand on a lid", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local giant = (world :: Instance):FindFirstChild("Giant")
		expect(giant).never.toBeNil()
		local eyes = (giant :: Instance):FindFirstChild("SleepEyes")
		expect(eyes).never.toBeNil()
		local solid: { string } = {}
		local count = 0
		for _, descendant in (eyes :: Instance):GetDescendants() do
			if descendant:IsA("BasePart") then
				count += 1
				if descendant.CanCollide or descendant.CanQuery then
					table.insert(solid, descendant:GetFullName())
				end
			end
		end
		expect(count > 0).toBe(true)
		expect(solid).toEqual({})
	end)
end)
