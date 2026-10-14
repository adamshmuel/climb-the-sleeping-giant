--!strict
-- The names of the folders and remotes the server shares with clients, in one place so a typo can't happen.
-- Loading this module creates nothing. The server calls Net.setup() once at start-up.

export type Made = {
	Remotes: Folder,
	Warning: RemoteEvent, -- fires 60 or 85 when the meter rises past that mark
	SetTiptoe: RemoteEvent, -- the client asks for Tiptoe on or off (true or false)
	GrabMissed: RemoteEvent, -- the server tells one player that someone else got the egg first (sends nothing)
	EggHome: RemoteEvent, -- the server tells everyone an egg was banked: (player, rarity, position of the new egg)
	Bounced: RemoteEvent, -- the server tells one player the flat direction (Vector3) they now face after the bounce-off
	SlamWarning: RemoteEvent, -- the server tells everyone a red circle starts: (slam number, point on the surface, landsAt on the shared server clock)
	SlamLanded: RemoteEvent, -- the server tells everyone the hand landed: (slam number, the same point)
	Caught: RemoteEvent, -- the server tells everyone a carrier was caught: (the caught Player)
	GiantState: Folder, -- attributes: Meter, Phase, ... (docs/architecture.md, section 2)
}

local Net = {}

Net.RemotesName = "Remotes"
Net.GiantStateName = "GiantState"
Net.WarningName = "Warning"
Net.SetTiptoeName = "SetTiptoe"
Net.GrabMissedName = "GrabMissed"
Net.EggHomeName = "EggHome"
Net.BouncedName = "Bounced"
Net.SlamWarningName = "SlamWarning"
Net.SlamLandedName = "SlamLanded"
Net.CaughtName = "Caught"

-- Finds the child with this name and class, or makes it. Returns the child and whether it was just made.
local function findOrMake(parent: Instance, name: string, className: string): (Instance, boolean)
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing.ClassName == className then
		return existing, false
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made, true
end

-- Makes the remotes folder (with every remote) and the GiantState folder under `parent`, or reuses what is
-- already there. The server passes ReplicatedStorage.
function Net.setup(parent: Instance): Made
	local remotes = (findOrMake(parent, Net.RemotesName, "Folder"))
	local warning = (findOrMake(remotes, Net.WarningName, "RemoteEvent"))
	local setTiptoe = (findOrMake(remotes, Net.SetTiptoeName, "RemoteEvent"))
	local grabMissed = (findOrMake(remotes, Net.GrabMissedName, "RemoteEvent"))
	local eggHome = (findOrMake(remotes, Net.EggHomeName, "RemoteEvent"))
	local bounced = (findOrMake(remotes, Net.BouncedName, "RemoteEvent"))
	local slamWarning = (findOrMake(remotes, Net.SlamWarningName, "RemoteEvent"))
	local slamLanded = (findOrMake(remotes, Net.SlamLandedName, "RemoteEvent"))
	local caught = (findOrMake(remotes, Net.CaughtName, "RemoteEvent"))
	local state, isNew = findOrMake(parent, Net.GiantStateName, "Folder")
	if isNew then
		state:SetAttribute("Meter", 0)
		state:SetAttribute("Phase", "Asleep")
	end
	return {
		Remotes = remotes :: Folder,
		Warning = warning :: RemoteEvent,
		SetTiptoe = setTiptoe :: RemoteEvent,
		GrabMissed = grabMissed :: RemoteEvent,
		EggHome = eggHome :: RemoteEvent,
		Bounced = bounced :: RemoteEvent,
		SlamWarning = slamWarning :: RemoteEvent,
		SlamLanded = slamLanded :: RemoteEvent,
		Caught = caught :: RemoteEvent,
		GiantState = state :: Folder,
	}
end

-- Waits for a child with this name, and returns it only if it is the right class of object.
local function waitForChildOfClass(parent: Instance, name: string, className: string, seconds: number): Instance?
	-- WaitForChild needs a time above 0, so with no time left it only looks.
	local child = if seconds > 0 then parent:WaitForChild(name, seconds) else parent:FindFirstChild(name)
	if child ~= nil and child.ClassName == className then
		return child
	end
	return nil
end

-- Client side: waits (at most `timeoutSeconds` in all) for the folders and the remote the server made with
-- Net.setup, and returns them. If something does not arrive, it says what is missing with `report` (default
-- `warn`) and returns nil: the caller carries on without it. It never waits forever.
function Net.waitForClient(parent: Instance, timeoutSeconds: number, report: ((message: string) -> ())?): Made?
	local say: (string) -> () = if report
		then report
		else function(message: string)
			warn(message)
		end
	local deadline = os.clock() + timeoutSeconds
	local function remaining(): number
		return math.max(0, deadline - os.clock())
	end

	local remotes = waitForChildOfClass(parent, Net.RemotesName, "Folder", remaining())
	local warning = if remotes then waitForChildOfClass(remotes, Net.WarningName, "RemoteEvent", remaining()) else nil
	local setTiptoe = if remotes
		then waitForChildOfClass(remotes, Net.SetTiptoeName, "RemoteEvent", remaining())
		else nil
	local grabMissed = if remotes
		then waitForChildOfClass(remotes, Net.GrabMissedName, "RemoteEvent", remaining())
		else nil
	local eggHome = if remotes then waitForChildOfClass(remotes, Net.EggHomeName, "RemoteEvent", remaining()) else nil
	local bounced = if remotes then waitForChildOfClass(remotes, Net.BouncedName, "RemoteEvent", remaining()) else nil
	local slamWarning = if remotes
		then waitForChildOfClass(remotes, Net.SlamWarningName, "RemoteEvent", remaining())
		else nil
	local slamLanded = if remotes
		then waitForChildOfClass(remotes, Net.SlamLandedName, "RemoteEvent", remaining())
		else nil
	local caught = if remotes then waitForChildOfClass(remotes, Net.CaughtName, "RemoteEvent", remaining()) else nil
	local state = waitForChildOfClass(parent, Net.GiantStateName, "Folder", remaining())
	if
		remotes == nil
		or warning == nil
		or setTiptoe == nil
		or grabMissed == nil
		or eggHome == nil
		or bounced == nil
		or slamWarning == nil
		or slamLanded == nil
		or caught == nil
		or state == nil
	then
		local missing: { string } = {}
		if remotes == nil then
			table.insert(missing, Net.RemotesName)
		end
		if warning == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.WarningName}`)
		end
		if setTiptoe == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.SetTiptoeName}`)
		end
		if grabMissed == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.GrabMissedName}`)
		end
		if eggHome == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.EggHomeName}`)
		end
		if bounced == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.BouncedName}`)
		end
		if slamWarning == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.SlamWarningName}`)
		end
		if slamLanded == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.SlamLandedName}`)
		end
		if caught == nil then
			table.insert(missing, `{Net.RemotesName}.{Net.CaughtName}`)
		end
		if state == nil then
			table.insert(missing, Net.GiantStateName)
		end
		say(`[Net] Did not find {table.concat(missing, ", ")} within {timeoutSeconds} s. Carrying on without it.`)
		return nil
	end
	return {
		Remotes = remotes :: Folder,
		Warning = warning :: RemoteEvent,
		SetTiptoe = setTiptoe :: RemoteEvent,
		GrabMissed = grabMissed :: RemoteEvent,
		EggHome = eggHome :: RemoteEvent,
		Bounced = bounced :: RemoteEvent,
		SlamWarning = slamWarning :: RemoteEvent,
		SlamLanded = slamLanded :: RemoteEvent,
		Caught = caught :: RemoteEvent,
		GiantState = state :: Folder,
	}
end

return Net
