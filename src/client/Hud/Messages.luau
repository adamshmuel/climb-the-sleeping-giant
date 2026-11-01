--!strict
-- The short messages at the bottom centre of the screen, in the place the mockups give them (core-hud.html, .pill
-- and hud.html, .hint):
--  * the carry pill, shown for as long as the server says the player carries an egg (spec Rule 4 and the
--    "Carrying" row of section 6);
--  * the tip "Follow the glowing footprints!" (the "Spawn" row of section 6), from the start until the player's
--    first grab of the session: the first time Carrying becomes a rarity. After that it never comes back, not even
--    after a respawn;
--  * the tip "Someone else got it!" for 2 seconds after a grab was missed (the "Someone else got the egg" row).
--    Before the first grab, the footprints tip comes back when the 2 seconds are over.
--  * the tip "Stand still or tiptoe!" for 3 seconds at the 85% warning (spec Rule 10), also while carrying: it takes
--    the carry pill's place, and the pill comes back after.
-- All of them stand in the same place, so only one shows at a time. The 85% warning wins over everything. Then the
-- carry pill wins: a player who carries an egg has an egg, and that matters more than a grab they missed. (The other
-- messages, the cards and the wake banner, come in later tasks.)
-- The green card "Safe! [Rarity] egg is home" is the third message. It stands under the sleep meter (on HudTop, so it
-- lines up with it) for 3 seconds after this player's own egg comes home, from the EggHome remote (spec Rule 5 and the
-- "Egg safe at home" row of section 6). Another player's egg shows nothing.
-- The red wake banner ("[Name] woke the Giant!", spec Rule 12) is the fourth. When GiantState's Phase turns Awake it shows
-- to every player for 3 seconds, with the second line "Run home with your egg!" on computers (on phones it is one line).
-- [Name] is the display name the server wrote into GiantState.WokenBy; the words follow it if it changes while the
-- banner shows. It stands low and right of centre on every screen (on phones it is one line), clear of his face. While
-- he is awake, a carrier's pill says "Dodge the red circles!", and the 85% tip ends when he wakes.
-- The cream "Caught!" card is the fifth. When the server fires Caught for this player (a hand slam sent them home, spec
-- Rule 13 and the "Caught" row of section 6), it shows for 3 seconds at the bottom of the Hud screen, left of centre on a
-- computer and in the middle on a phone: the 💫, "Caught!" and the second line "The egg went back. You lost nothing
-- else." It is its own frame, not the pill's or the tips' place, because a caught player carries nothing. On a phone
-- the tip plate hides while the card shows and comes back after it. Another
-- player's catch shows nothing here (everyone sees the star puff, which lives in Fx/Celebrations).
-- It only shows what the server says: it reads the player's Carrying attribute and GiantState, and listens for
-- GrabMissed and EggHome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local MessageParts = require(script.Parent.MessageParts)

local Messages = {}

Messages.footprintsText = "👣 Follow the glowing footprints!"
Messages.missedText = "Someone else got it!"
Messages.missedSeconds = 2
-- The tip at the 85% warning (spec Rule 10 and the "85% warning" row of section 6): it wins over everything else in
-- the bottom centre, even the carry pill, for 3 seconds.
Messages.standStillText = "🤫 Stand still or tiptoe!"
Messages.standStillSeconds = 3
local WARNING_MARK = 85

-- The red wake banner's words, and the carry pill's words while he is awake.
Messages.runHomeText = "Run home with your egg!"
Messages.dodgeText = "Dodge the red circles!"

-- The banner's first line for the player the server names. Nobody named (an empty name, or something that isn't text):
-- the line doesn't name anyone.
function Messages.wokeText(name: any): string
	if type(name) == "string" and name ~= "" then
		return `{name} woke the Giant!`
	end
	return "The Giant woke up!"
end

-- The Caught! card (spec section 6, "Caught"): the words, the second line and how long it shows.
Messages.caughtTitle = "Caught!"
Messages.caughtLine = "The egg went back. You lost nothing else."
Messages.caughtSeconds = 3

-- The words in the carry pill for an egg of this rarity.
function Messages.carryText(rarity: string): string
	return `{rarity} egg! Get it home`
end

-- The words on the green card for an egg of this rarity.
function Messages.safeText(rarity: string): string
	return `Safe! {rarity} egg is home`
end

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

-- The GrabMissed remote, as far as this module uses it.
export type GrabMissedLike = { OnClientEvent: SignalLike }

-- The EggHome remote, as far as this module uses it: it fires (player, rarity, position of the new egg).
export type EggHomeLike = { OnClientEvent: SignalLike }

-- The Warning remote, as far as this module uses it: it fires the mark (60 or 85), and at a free save (85, Net.FreeSaveKind).
export type WarningLike = { OnClientEvent: SignalLike }

-- The Caught remote, as far as this module uses it: it fires the player who was caught.
export type CaughtLike = { OnClientEvent: SignalLike }

export type PlayerLike = {
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
}

-- The screen size: `get` reads it, and `connect` calls `callback` whenever it may have changed and returns a
-- function that stops that.
export type ViewportLike = {
	get: () -> Vector2,
	connect: (callback: () -> ()) -> () -> (),
}

export type Deps = {
	parent: Instance, -- the player's screen (PlayerGui): Hud goes in it
	player: PlayerLike, -- the local player: their Carrying attribute is the server's answer
	grabMissed: GrabMissedLike, -- the GrabMissed remote
	eggHome: EggHomeLike, -- the EggHome remote
	warning: WarningLike, -- the Warning remote
	caught: CaughtLike, -- the Caught remote
	giantState: Instance, -- ReplicatedStorage.GiantState: its Phase says when he wakes and WokenBy who woke him
	viewport: ViewportLike,
	-- Runs `callback` after `seconds` and returns a function that cancels it. Left out, the real clock is used.
	after: ((seconds: number, callback: () -> ()) -> () -> ())?,
}

-- What start gives back: `stop` takes the messages off again and cleans everything up.
export type Handle = {
	stop: () -> (),
	-- True while the phone grab pill is pinned to the bottom centre: the tips hide, and a timed tip that comes due
	-- then waits (starts its clock) until the pill is let go.
	setPillPinned: (pinned: boolean) -> (),
}

-- The real clock: runs the callback after `seconds` and can cancel it.
function Messages.realAfter(seconds: number, callback: () -> ()): () -> ()
	local done = false
	local thread = task.delay(seconds, function()
		done = true
		callback()
	end)
	return function()
		if not done then
			done = true
			task.cancel(thread)
		end
	end
end

-- Puts the messages on the player's screen. Returns a handle: `stop` takes them off again and cleans up
-- everything it made (every connection, every timer and the pieces themselves).
function Messages.start(deps: Deps): Handle
	local hud = Ui.hud(deps.parent)
	for _, name in { "CarryPill", "Tip", "WakeBanner", "CaughtCard" } do
		local leftOver = hud:FindFirstChild(name)
		if leftOver then
			leftOver:Destroy() -- never two of each
		end
	end

	local hudTop = Ui.hudTop(deps.parent)
	local leftOverCard = hudTop:FindFirstChild("SafeCard")
	if leftOverCard then
		leftOverCard:Destroy() -- never two cards
	end

	local trove = Trove.new()
	local parts = MessageParts.build(hud, hudTop, {
		footprintsText = Messages.footprintsText,
		runHomeText = Messages.runHomeText,
		caughtTitle = Messages.caughtTitle,
		caughtLine = Messages.caughtLine,
	})
	trove:Add(parts.pill)
	trove:Add(parts.tip)
	trove:Add(parts.card)
	trove:Add(parts.banner)
	trove:Add(parts.caughtCard)
	local after = deps.after or Messages.realAfter

	local cancelMissed: (() -> ())? = nil
	local pillPinned = false
	-- A timed tip that came due while the pill was pinned starts its clock from these when the pill is let go.
	local startMissed: (() -> ())? = nil
	local startWarning: (() -> ())? = nil
	local stopped = false
	-- Set for good at the first grab of the session. Until then, the tip tells the player to follow the footprints.
	local grabbedOnce = false
	-- True for the 2 seconds after a missed grab.
	local missedShowing = false

	-- Stops the 2-second timer of the missed tip, if one is running.
	local function stopMissedTimer()
		startMissed = nil
		if cancelMissed then
			cancelMissed()
			cancelMissed = nil
		end
		missedShowing = false
	end
	trove:Add(stopMissedTimer)

	-- True for the 3 seconds after an 85% warning. The tip then takes the carry pill's place.
	local warningShowing = false
	local cancelWarning: (() -> ())? = nil

	local function stopWarningTimer()
		startWarning = nil
		if cancelWarning then
			cancelWarning()
			cancelWarning = nil
		end
		warningShowing = false
	end
	trove:Add(stopWarningTimer)

	-- True while Phase is Awake. A player who joins while he is awake sees no banner, but the pill's words are right.
	local awake = deps.giantState:GetAttribute("Phase") == "Awake"
	local bannerShowing = false
	local cancelBanner: (() -> ())? = nil

	local function hideBanner()
		if cancelBanner then
			cancelBanner()
			cancelBanner = nil
		end
		bannerShowing = false
		parts.banner.Visible = false
	end
	trove:Add(hideBanner)

	local function updateBannerWords()
		parts.bannerText.Text = Messages.wokeText(deps.giantState:GetAttribute("WokenBy"))
	end

	-- Shows the banner for Config.Wake.BannerSeconds. A banner that is already showing starts its seconds again.
	local function showBanner()
		hideBanner()
		updateBannerWords()
		bannerShowing = true
		parts.banner.Visible = true
		cancelBanner = after(Config.Wake.BannerSeconds, function()
			cancelBanner = nil
			bannerShowing = false
			parts.banner.Visible = false
		end)
	end

	local cancelCaught: (() -> ())? = nil
	-- True while the Caught! card shows. On a phone the tip plate hides then, so only one message shows.
	local caughtShowing = false
	local phone = false

	local function hideCaught()
		if cancelCaught then
			cancelCaught()
			cancelCaught = nil
		end
		caughtShowing = false
		parts.caughtCard.Visible = false
	end
	trove:Add(hideCaught)

	local cancelCard: (() -> ())? = nil

	local function hideCard()
		if cancelCard then
			cancelCard()
			cancelCard = nil
		end
		parts.card.Visible = false
	end
	trove:Add(hideCard)

	-- The rarity the server says the player carries, or nil if they carry nothing (or something unknown).
	local function carriedRarity(): string?
		local value = deps.player:GetAttribute("Carrying")
		if type(value) == "string" and Theme.rarity[value] ~= nil then
			return value
		end
		return nil
	end

	-- Shows the tip that fits now, or none. The 85% warning wins over everything; then the carry pill; then a missed
	-- grab; then the footprints tip, until the first grab.
	local function renderTip()
		local words: string? = nil
		if warningShowing then
			words = Messages.standStillText
		elseif carriedRarity() == nil then
			if missedShowing then
				words = Messages.missedText
			elseif not grabbedOnce then
				words = Messages.footprintsText
			end
		end
		if words ~= nil then
			parts.tipText.Text = words
		end
		parts.tip.Visible = words ~= nil and not (caughtShowing and phone) and not pillPinned
	end

	local function renderCarry()
		local rarity = carriedRarity()
		if rarity == nil then
			parts.pill.Visible = false
			renderTip()
			return
		end
		local look = Theme.rarity[rarity]
		-- While he is awake, the carrier is told what to do, instead of where to go.
		parts.text.Text = if awake then Messages.dodgeText else Messages.carryText(rarity)
		parts.eggGradient.Color = MessageParts.eggColors(look)
		parts.pill.Visible = not warningShowing -- the warning tip takes its place for 3 seconds
		grabbedOnce = true
		stopMissedTimer()
		renderTip() -- they stand in the same place, and the carry pill wins
	end

	-- The 85% warning: the tip shows for 3 seconds, also for a player who carries an egg (the pill comes back after).
	-- A second 85 starts the 3 seconds again, and so does the replay at a free save (85, Net.FreeSaveKind). Any other
	-- mark shows nothing, and neither does any other second value.
	local function onWarning(mark: any, kind: any)
		-- A late 85 that arrives after he woke shows nothing: the warnings are over.
		if stopped or mark ~= WARNING_MARK or awake then
			return
		end
		if kind ~= nil and kind ~= Net.FreeSaveKind then
			return
		end
		stopWarningTimer()
		warningShowing = true
		renderCarry()
		local function begin()
			startWarning = nil
			cancelWarning = after(Messages.standStillSeconds, function()
				cancelWarning = nil
				warningShowing = false
				renderCarry()
			end)
		end
		if pillPinned then
			startWarning = begin
		else
			begin()
		end
	end

	local function onGrabMissed()
		if stopped or carriedRarity() ~= nil then
			return
		end
		stopMissedTimer() -- a second miss starts the 2 seconds again
		missedShowing = true
		renderTip()
		local function begin()
			startMissed = nil
			cancelMissed = after(Messages.missedSeconds, function()
				cancelMissed = nil
				missedShowing = false
				renderTip()
			end)
		end
		if pillPinned then
			startMissed = begin
		else
			begin()
		end
	end

	local function setPillPinned(pinned: boolean)
		if stopped or pinned == pillPinned then
			return
		end
		pillPinned = pinned
		if not pinned then
			local missed, warning = startMissed, startWarning
			if missed then
				missed()
			end
			if warning then
				warning()
			end
		end
		renderTip()
	end

	-- An egg came home. Only this player's own egg shows the card; a second one while it shows replaces the words and
	-- starts the 3 seconds again.
	local function onEggHome(player: any, rarity: any, _position: any)
		if stopped or player ~= deps.player then
			return
		end
		if type(rarity) ~= "string" or Theme.rarity[rarity] == nil then
			return
		end
		hideCard()
		parts.cardText.Text = Messages.safeText(rarity)
		parts.cardEggGradient.Color = MessageParts.eggColors(Theme.rarity[rarity])
		parts.card.Visible = true
		cancelCard = after(Config.Home.CardSeconds, function()
			cancelCard = nil
			parts.card.Visible = false
		end)
	end

	-- A hand slam caught a player. Only this player's own catch shows the card; a second one while it shows starts the
	-- 3 seconds again.
	local function onCaught(player: any)
		if stopped or player ~= deps.player then
			return
		end
		hideCaught()
		caughtShowing = true
		parts.caughtCard.Visible = true
		renderTip()
		cancelCaught = after(Messages.caughtSeconds, function()
			cancelCaught = nil
			caughtShowing = false
			parts.caughtCard.Visible = false
			renderTip()
		end)
	end

	-- Phase turned Awake or left it. The banner shows to everyone when he wakes; the 85% tip ends then, and the carry
	-- pill's words change either way.
	local function onPhaseChanged()
		if stopped then
			return
		end
		local nowAwake = deps.giantState:GetAttribute("Phase") == "Awake"
		if nowAwake == awake then
			return
		end
		awake = nowAwake
		if nowAwake then
			stopWarningTimer()
			showBanner()
		end
		renderCarry()
	end

	-- Phase can reach a device before WokenBy: the words follow it while the banner shows.
	local function onWokenByChanged()
		if not stopped and bannerShowing then
			updateBannerWords()
		end
	end

	local function relayout()
		local layout = Layout.forScreen(deps.viewport.get())
		phone = layout.phone
		MessageParts.applyLayout(parts, layout.pill, layout.tip, layout.card)
		MessageParts.applyBanner(parts, layout.banner)
		MessageParts.applyCaught(parts, layout.caught)
	end

	relayout()
	renderCarry()
	trove:Add(deps.giantState:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged))
	trove:Add(deps.giantState:GetAttributeChangedSignal("WokenBy"):Connect(onWokenByChanged))
	trove:Add(deps.player:GetAttributeChangedSignal("Carrying"):Connect(renderCarry))
	trove:Add(deps.grabMissed.OnClientEvent:Connect(onGrabMissed))
	trove:Add(deps.eggHome.OnClientEvent:Connect(onEggHome))
	trove:Add(deps.warning.OnClientEvent:Connect(onWarning))
	trove:Add(deps.caught.OnClientEvent:Connect(onCaught))
	trove:Add(deps.viewport.connect(relayout))

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			trove:Destroy()
		end,
		setPillPinned = setPillPinned,
	}
end

return Messages
