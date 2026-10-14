--!strict
-- The words over the egg spots (spec Rule 3, "Eggs wait in three zones", and the "Egg labels" and "Empty egg spot"
-- rows of section 6), drawn on this player's own screen:
--   * an egg waits: its rarity name ("Common", "Uncommon", "Rare") in the rarity's colour, just above the egg;
--   * the egg was taken: the refill countdown ("0:42") in white, on the spot, counting down live;
--   * nothing is known yet: nothing.
-- Each label is a BillboardGui sized in studs, so it shrinks with distance like a sign in the world. Up close it
-- would grow without end, so the text label inside it is never bigger than 130 x 36 px and its text is never bigger
-- than 30 px. It is hidden past 75 studs, and the giant can hide it (it is not drawn on top of the world).
-- The server only writes each spot's attributes (Waiting, RefillAt on the shared server clock); see SpotModels.
--
-- Two screen rules keep the words readable (style guide rows "Egg labels never stack" and "Egg labels never sit under
-- the meter"). About ten times a second, every rarity label that is drawn gets a rectangle on this screen (the drawn
-- words). A rarity label fades out over 0.15 s, and back in over 0.15 s once it is clear, when:
--   * its words overlap the words of a nearer rarity label that is showing (only the nearest egg's label shows);
--   * its words touch the sleep meter's box, or reach past the top edge of the screen.
-- The eggs themselves are never touched, and countdowns over empty spots always show and take no part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Theme = require(script.Parent.Parent.Hud.Theme)
local Ui = require(script.Parent.Parent.Hud.Ui)

local SpotLabels = {}

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

-- A rectangle on the screen, in pixels from the screen's top left corner (x and y are its top left corner).
export type Rect = { x: number, y: number, width: number, height: number }

-- One rarity label for the "never stack" rule: an id, where its words are on the screen, and how far it is from the camera.
export type Candidate = { id: number, rect: Rect, distance: number }

-- The three sizes on the screen (pixels) that place the words of a drawn label.
export type Sizes = {
	billboard: Vector2, -- the whole label sign (BillboardGui.AbsoluteSize)
	box: Vector2, -- the text label inside it (TextLabel.AbsoluteSize): capped at 130 x 36, at the sign's bottom
	words: Vector2, -- the drawn words (TextLabel.TextBounds)
}
export type SizesReader = (gui: BillboardGui, text: TextLabel) -> Sizes?

-- The part of the camera this module reads, so tests can pass a stand-in. The real Camera fits.
export type CameraLike = {
	CFrame: CFrame,
	WorldToViewportPoint: (self: any, point: Vector3) -> (Vector3, boolean),
}

-- What the screen knows. `words`: the rectangle of a label's words and its distance from the camera, or nothing when
-- the label is behind the camera, past the label's range or not drawn yet. `meter`: the sleep meter's box, or nothing.
export type View = {
	words: (gui: BillboardGui, text: TextLabel, centre: Vector3) -> (Rect?, number?),
	meter: () -> Rect?,
}

export type Deps = {
	parent: Instance, -- the player's screen (PlayerGui): the labels go on its WorldPrompts layer
	root: Instance, -- holds the egg spots (Workspace.World.EggSpots)
	now: () -> number, -- the shared server clock in seconds (Workspace:GetServerTimeNow)
	step: SignalLike, -- once per frame, for the countdowns (RunService.RenderStepped)
	view: View?, -- the screen, for the two screen rules; without it labels are never hidden
}

-- The label's size, as in the egg templates' own label: studs, plus a few pixels so it never gets unreadably small.
local WIDTH_STUDS = 3
local WIDTH_PIXELS = 40
local HEIGHT_STUDS = 0.9
local HEIGHT_PIXELS = 12
-- The limits from spec section 6 ("Egg labels"): on screen, in pixels, and in studs.
local MAX_LABEL_SIZE = Vector2.new(130, 36)
local MAX_TEXT_SIZE = 30
local MIN_TEXT_SIZE = 12
local MAX_DISTANCE = 75
local OUTLINE_THICKNESS = 3

-- Seconds between two looks at the screen: often enough that a label hides about as fast as the camera moves, rare
-- enough to cost nothing (style guide: "checked about 10 times a second").
local CHECK_SECONDS = 0.1
-- Seconds a label takes to fade out, and to fade back in (style guide: 0.15 s each way).
local FADE_SECONDS = 0.15
-- A clock reading this close to the next check counts as there, so 0.1 s of frames never waits for one more frame
-- because of a rounding speck.
local CLOCK_TOLERANCE = 1e-6
-- A fade this close to clear or to fully hidden counts as there, so rounding never leaves a speck of see-through behind.
local SNAP = 1e-6

-- How far the bottom of the words sits above the egg's top, and above the top of the Base of an empty spot (studs).
local GAP_ABOVE_EGG = 1
local GAP_ABOVE_BASE = 1.5
-- The egg's height until its model is there to measure (the templates: Common 5.5, Uncommon 6.2, Rare 7.0 studs).
local DEFAULT_EGG_HEIGHT = 5.5

local EGG_NAME = "Egg"
local BASE_NAME = "Base"

-- What the label says. `waiting`: the spot's Waiting attribute (nil when it is not set). `refillAt`: the time the egg
-- comes back, on the same clock as `now`. A part of a second is rounded up, so the countdown never shows 0:00 before
-- the egg is back.
function SpotLabels.text(waiting: boolean?, rarity: string, refillAt: number?, now: number): string?
	if waiting == true then
		return rarity
	end
	if waiting == false and refillAt ~= nil then
		return Format.countdown(math.ceil(refillAt - now))
	end
	return nil
end

-- True when the two rectangles share some area. Rectangles that only touch edge to edge don't overlap.
local function overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
end

-- True when the rectangles share some area or touch, because a word half under the meter looks broken.
local function touches(a: Rect, b: Rect): boolean
	return a.x <= b.x + b.width and b.x <= a.x + a.width and a.y <= b.y + b.height and b.y <= a.y + a.height
end

-- Which rarity labels show. Each label is hidden when its rectangle touches the meter's box (`meter`, nil when there is
-- none) or reaches past the top edge of the screen (y below 0). Of the others, the nearest to the camera comes first,
-- and a label shows unless it overlaps one that already shows. A label hidden by the meter or the top edge takes no
-- part, so it never hides another. Equal distances go by id, so the answer never depends on the order of the list.
-- Returns, for every id given, true when it shows and false when it hides.
function SpotLabels.pickShown(candidates: { Candidate }, meter: Rect?): { [number]: boolean }
	local answer: { [number]: boolean } = {}
	local ranked: { Candidate } = {}
	for _, candidate in candidates do
		if candidate.rect.y < 0 or (meter ~= nil and touches(candidate.rect, meter)) then
			answer[candidate.id] = false
		else
			table.insert(ranked, candidate)
		end
	end
	table.sort(ranked, function(a: Candidate, b: Candidate)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.id < b.id
	end)
	local showing: { Rect } = {}
	for _, candidate in ranked do
		local clear = true
		for _, other in showing do
			if overlaps(candidate.rect, other) then
				clear = false
				break
			end
		end
		answer[candidate.id] = clear
		if clear then
			table.insert(showing, candidate.rect)
		end
	end
	return answer
end

-- Where the drawn words are on the screen. `centre`: where the middle of the label's sign is (projected from the world).
-- The text label sits at the bottom of the sign (capped smaller than the sign up close), and the words sit in the middle
-- of the text label and are never bigger than it.
function SpotLabels.wordsRect(centre: Vector2, billboard: Vector2, box: Vector2, words: Vector2): Rect
	local width = math.min(words.X, box.X)
	local height = math.min(words.Y, box.Y)
	local boxBottom = centre.Y + billboard.Y / 2
	local boxMiddleY = boxBottom - box.Y / 2
	return {
		x = centre.X - width / 2,
		y = boxMiddleY - height / 2,
		width = width,
		height = height,
	}
end

-- The sizes of a label that is being drawn, or nothing before its first frame (Roblox reports 0 x 0 until then).
local function drawnSizes(gui: BillboardGui, text: TextLabel): Sizes?
	local billboard = gui.AbsoluteSize
	local box = text.AbsoluteSize
	if billboard.X <= 0 or billboard.Y <= 0 or box.X <= 0 or box.Y <= 0 then
		return nil
	end
	return { billboard = billboard, box = box, words = text.TextBounds }
end

-- The real screen: `getCamera` gives the camera (nil when there is none), `getMeter` the meter's box in screen pixels
-- (nil when there is none). `readSizes` is for tests; the real one reads what Roblox is drawing.
function SpotLabels.screenView(getCamera: () -> CameraLike?, getMeter: () -> Rect?, readSizes: SizesReader?): View
	local read: SizesReader = drawnSizes
	if readSizes ~= nil then
		read = readSizes
	end
	return {
		words = function(gui: BillboardGui, text: TextLabel, centre: Vector3): (Rect?, number?)
			local camera = getCamera()
			if camera == nil then
				return nil, nil
			end
			local point = camera:WorldToViewportPoint(centre)
			if point.Z <= 0 then
				return nil, nil
			end
			local distance = (camera.CFrame.Position - centre).Magnitude
			if distance > MAX_DISTANCE then
				return nil, nil
			end
			local sizes = read(gui, text)
			if sizes == nil then
				return nil, nil
			end
			return SpotLabels.wordsRect(Vector2.new(point.X, point.Y), sizes.billboard, sizes.box, sizes.words),
				distance
		end,
		meter = getMeter,
	}
end

-- One spot's label and what it needs to follow the spot.
type Entry = {
	id: number,
	spot: Model,
	gui: BillboardGui,
	text: TextLabel,
	outline: UIStroke,
	fade: number, -- 0 clear to 1 fully see-through (rarity labels only; a countdown stays at 0)
	hide: boolean, -- where the fade is heading: true when the last check said this label must hide
	faded: number, -- the value last written to the words and the outline
	refillAt: number?, -- set while the label counts down
	shown: string?, -- the words on the label now, so the text is only set when it changes
	cleanup: () -> (),
}

-- Builds an empty label (hidden until a spot gives it words).
local function buildLabel(layer: ScreenGui): (BillboardGui, TextLabel, UIStroke)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpotLabel"
	gui.Size = UDim2.new(WIDTH_STUDS, WIDTH_PIXELS, HEIGHT_STUDS, HEIGHT_PIXELS)
	gui.MaxDistance = MAX_DISTANCE
	gui.AlwaysOnTop = false -- the giant can hide it
	gui.LightInfluence = 0
	gui.Active = false
	gui.Enabled = false

	-- The words sit at the bottom of the billboard, so a label that is cut down to its pixel limit up close keeps its
	-- bottom edge where it was.
	local text = Ui.text("Text", gui, "", 1, Theme.white)
	text.TextScaled = true
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.fromScale(0.5, 1)
	text.Size = UDim2.fromScale(1, 1)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = MAX_LABEL_SIZE
	sizeLimit.Parent = text
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = MAX_TEXT_SIZE
	textLimit.MinTextSize = MIN_TEXT_SIZE
	textLimit.Parent = text
	local outline = Ui.outline(text, Theme.ink, OUTLINE_THICKNESS)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	gui.Parent = layer
	return gui, text, outline
end

-- The value to write into StudsOffsetWorldSpace so the label's middle ends up where it belongs. The label's bottom edge
-- is GAP_ABOVE_EGG straight up from the top of the egg (which leans with the spot), or GAP_ABOVE_BASE straight up
-- from the top of an empty spot's Base. Roblox's docs say the offset is read along the world's axes, but it is read
-- along the Adornee's own axes (measured in Play on the tilted belly spots). So the offset is worked out in world
-- directions first, then turned into the Base's directions, and Roblox's turn puts the label back on the intended spot.
local function offsetFor(spot: Model, base: BasePart, waiting: boolean): Vector3
	local baseTop = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	local bottom: Vector3
	if waiting then
		local egg = spot:FindFirstChild(EGG_NAME)
		local height = if egg ~= nil and egg:IsA("Model") then egg:GetExtentsSize().Y else DEFAULT_EGG_HEIGHT
		bottom = baseTop:PointToWorldSpace(Vector3.new(0, height, 0)) + Vector3.new(0, GAP_ABOVE_EGG, 0)
	else
		bottom = baseTop.Position + Vector3.new(0, GAP_ABOVE_BASE, 0)
	end
	local worldOffset = bottom + Vector3.new(0, HEIGHT_STUDS / 2, 0) - base.Position
	return base.CFrame:VectorToObjectSpace(worldOffset)
end

-- Draws a label over every egg spot under `deps.root`, and returns a function that removes them all.
function SpotLabels.start(deps: Deps): () -> ()
	local layer = Ui.worldLayer(deps.parent)
	local trove = Trove.new()
	local stopped = false
	local entries: { [Instance]: Entry } = {}
	local nextId = 0
	local lastTime = deps.now()
	local lastCheck: number? = nil

	-- Puts the fade on the words and the outline, only when it changes.
	local function writeFade(entry: Entry, value: number)
		if entry.faded ~= value then
			entry.faded = value
			entry.text.TextTransparency = value
			entry.outline.Transparency = value
		end
	end

	-- A label that is not a rarity label (a countdown, or nothing) shows normally at once.
	local function clearFade(entry: Entry)
		entry.fade = 0
		entry.hide = false
		writeFade(entry, 0)
	end

	local function setText(entry: Entry, words: string)
		if entry.shown ~= words then
			entry.shown = words
			entry.text.Text = words
		end
	end

	-- Reads the spot's attributes and shows, moves and colours its label to match.
	local function refresh(entry: Entry)
		local spot = entry.spot
		local waitingValue: any = spot:GetAttribute("Waiting")
		local refillValue: any = spot:GetAttribute("RefillAt")
		local rarityValue: any = spot:GetAttribute("Rarity")
		local waiting: boolean? = if type(waitingValue) == "boolean" then waitingValue else nil
		local refillAt: number? = if type(refillValue) == "number" then refillValue else nil
		local rarity: string = if type(rarityValue) == "string" then rarityValue else ""

		local foundBase = spot:FindFirstChild(BASE_NAME)
		local base: BasePart? = if foundBase ~= nil and foundBase:IsA("BasePart") then foundBase else nil
		-- Adornee may be empty (the Base is not there yet), which Roblox's type list does not show.
		entry.gui.Adornee = base :: any
		local words = SpotLabels.text(waiting, rarity, refillAt, deps.now())
		if words == nil or waiting == nil or base == nil then
			entry.refillAt = nil
			entry.gui.Enabled = false
			clearFade(entry)
			return
		end
		if not waiting then
			clearFade(entry)
		end

		entry.gui.StudsOffsetWorldSpace = offsetFor(spot, base, waiting)
		local look = Theme.rarity[rarity]
		entry.text.TextColor3 = if waiting and look ~= nil then look.main else Theme.white
		-- Only an empty spot counts down; the frames leave a waiting label alone.
		entry.refillAt = if waiting then nil else refillAt
		setText(entry, words)
		entry.gui.Enabled = true
	end

	local function track(spot: Instance)
		if stopped or not spot:IsA("Model") or entries[spot] ~= nil then
			return
		end
		local gui, text, outline = buildLabel(layer)
		local spotTrove = Trove.new()
		nextId += 1
		local entry: Entry = {
			id = nextId,
			spot = spot,
			gui = gui,
			text = text,
			outline = outline,
			fade = 0,
			hide = false,
			faded = 0,
			refillAt = nil,
			shown = nil,
			cleanup = function()
				spotTrove:Destroy()
			end,
		}
		entries[spot] = entry
		spotTrove:Add(gui)
		spotTrove:Add(spot.AttributeChanged:Connect(function()
			refresh(entry)
		end))
		-- The Base, and the egg model with its parts, can arrive after the attributes.
		spotTrove:Add(spot.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == BASE_NAME or descendant.Name == EGG_NAME or descendant:IsA("BasePart") then
				refresh(entry)
			end
		end))
		spotTrove:Add(spot.ChildRemoved:Connect(function(child: Instance)
			if child.Name == BASE_NAME or child.Name == EGG_NAME then
				refresh(entry)
			end
		end))
		refresh(entry)
	end

	local function untrack(spot: Instance)
		local entry = entries[spot]
		if entry ~= nil then
			entries[spot] = nil
			entry.cleanup()
		end
	end

	-- Looks at the screen: works out which rarity labels must hide, and sets where each fade is heading.
	local function check(view: View)
		local candidates: { Candidate } = {}
		for _, entry in entries do
			-- Adornee may be empty (the Base is not there yet), which Roblox's type list does not show.
			local adornee: Instance? = entry.gui.Adornee
			if entry.gui.Enabled and entry.refillAt == nil and adornee ~= nil and adornee:IsA("BasePart") then
				-- Roblox reads StudsOffsetWorldSpace along the Base's own axes, so this turns the written offset back
				-- into the world. It is the same point the label was placed at: straight above its egg (or countdown).
				local drawnAt = adornee.Position + adornee.CFrame:VectorToWorldSpace(entry.gui.StudsOffsetWorldSpace)
				local words, distance = view.words(entry.gui, entry.text, drawnAt)
				if words ~= nil and distance ~= nil then
					table.insert(candidates, { id = entry.id, rect = words, distance = distance })
				end
			end
		end
		local shown = SpotLabels.pickShown(candidates, view.meter())
		for _, entry in entries do
			entry.hide = shown[entry.id] == false
		end
	end

	-- Moves every rarity label's fade toward where its last check sent it, at 0.15 s from clear to hidden.
	local function fadeLabels(seconds: number)
		local amount = seconds / FADE_SECONDS
		for _, entry in entries do
			if entry.refillAt == nil then
				if entry.hide then
					entry.fade = math.min(1, entry.fade + amount)
				else
					entry.fade = math.max(0, entry.fade - amount)
				end
				if entry.fade < SNAP then
					entry.fade = 0
				elseif entry.fade > 1 - SNAP then
					entry.fade = 1
				end
				writeFade(entry, entry.fade)
			end
		end
	end

	-- The countdowns follow the clock on every frame; the words are set only when the second changes. The two screen
	-- rules are checked every CHECK_SECONDS, and the fades move on every frame.
	local function onStep()
		local now = deps.now()
		for _, entry in entries do
			local refillAt = entry.refillAt
			if refillAt ~= nil then
				local words = SpotLabels.text(false, "", refillAt, now)
				if words ~= nil then
					setText(entry, words)
				end
			end
		end
		local view = deps.view
		if view == nil then
			return
		end
		local seconds = math.max(0, now - lastTime)
		lastTime = now
		if lastCheck == nil or now - lastCheck >= CHECK_SECONDS - CLOCK_TOLERANCE then
			lastCheck = now
			check(view)
		end
		fadeLabels(seconds)
	end

	for _, child in deps.root:GetChildren() do
		track(child)
	end
	trove:Add(deps.root.ChildAdded:Connect(track))
	trove:Add(deps.root.ChildRemoved:Connect(untrack))
	trove:Add(deps.step:Connect(onStep))
	trove:Add(function()
		for spot in entries do
			untrack(spot)
		end
	end)

	return function()
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end
end

return SpotLabels
