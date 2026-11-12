--!strict
-- Real-world check of every file in SoundList (Rule 85; spec 7 section 8, "A sound doesn't load"): the store's maker,
-- type and free flag for each id, and the real length of each file. Silent: the AudioPlayers have no wire, no output and
-- are never started. All ids are asked at once, so the run takes seconds, not minutes.
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(ServerStorage.DevPackages.JestGlobals)
local describe, it, expect, afterAll = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterAll

local SoundList = require(StarterPlayer.StarterPlayerScripts.Client.Audio.SoundList)

local ALLOWED_MAKERS = { Roblox = true, ProSoundEffects = true, APMOfficial = true }
local AUDIO_TYPE_ID = 3 -- Enum.AssetType.Audio.Value
local LOAD_SECONDS = 10
local LENGTH_MARGIN = 0.1 -- the plan's margin, in seconds
local TEST_TIMEOUT = 60000 -- milliseconds, as in WaysUpJump.spec.luau

type StoreInfo = { creator: string?, assetTypeId: number?, isPublicDomain: boolean? }
type FileFacts = { info: StoreInfo?, infoError: string?, timeLength: number? }

local facts: { [number]: FileFacts }? = nil
local checkFolder: Folder? = nil

-- Asks the store about one id (GetProductInfoAsync, type Asset).
local function readStore(id: number): (StoreInfo?, string?)
	local ok, result = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)
	end)
	if not ok then
		return nil, tostring(result)
	end
	local raw = result :: { [string]: any }
	local creator = raw.Creator :: { Name: string? }?
	return {
		creator = if creator then creator.Name else nil,
		assetTypeId = raw.AssetTypeId :: number?,
		isPublicDomain = raw.IsPublicDomain :: boolean?,
	},
		nil
end

-- Loads one file into a silent AudioPlayer and returns its length, or nil if it isn't ready in LOAD_SECONDS.
local function readLength(folder: Folder, id: number): number?
	local player = Instance.new("AudioPlayer")
	player.Name = tostring(id)
	player.Asset = `rbxassetid://{id}`
	player.Parent = folder
	if not player.IsReady then
		local waiting = coroutine.running()
		local resumed = false
		local function finish()
			if not resumed then
				resumed = true
				task.spawn(waiting)
			end
		end
		local connection = player:GetPropertyChangedSignal("IsReady"):Connect(function()
			if player.IsReady then
				finish()
			end
		end)
		task.delay(LOAD_SECONDS, finish)
		coroutine.yield()
		connection:Disconnect()
	end
	if player.IsReady then
		return player.TimeLength
	end
	return nil
end

-- Every different id, once, all at the same time. Cached: the first test pays the wait. The folder is gone again
-- before this returns, so test 5 can check nothing is left.
local function gather(): { [number]: FileFacts }
	if facts ~= nil then
		return facts
	end
	local folder = Instance.new("Folder")
	folder.Name = "SoundFilesCheck"
	folder.Archivable = false
	folder.Parent = ServerStorage
	checkFolder = folder

	local found: { [number]: FileFacts } = {}
	local pending = 0
	local main = coroutine.running()
	local ids: { number } = {}
	for _, row in SoundList.entries do
		if found[row.id] == nil then
			found[row.id] = {}
			table.insert(ids, row.id)
		end
	end
	for _, id in ids do
		local one = found[id]
		pending += 2
		local function oneDone()
			pending -= 1
			if pending == 0 then
				task.spawn(main)
			end
		end
		task.spawn(function()
			one.info, one.infoError = readStore(id)
			oneDone()
		end)
		task.spawn(function()
			one.timeLength = readLength(folder, id)
			oneDone()
		end)
	end
	if pending > 0 then
		coroutine.yield()
	end
	folder:Destroy()
	checkFolder = nil
	facts = found
	return found
end

local function failIfAny(problems: { string })
	if #problems > 0 then
		error(table.concat(problems, "; "), 0)
	end
end

describe("SoundList files (real store and real loading)", function()
	afterAll(function()
		if checkFolder ~= nil then
			checkFolder:Destroy()
			checkFolder = nil
		end
	end)

	it("every file says its maker is Roblox, ProSoundEffects or APMOfficial, and it is the row's maker", function()
		local all = gather()
		local problems: { string } = {}
		for _, row in SoundList.entries do
			local fact = all[row.id]
			local got = if fact.info then fact.info.creator else fact.infoError
			if got ~= row.maker or ALLOWED_MAKERS[row.maker] ~= true then
				table.insert(problems, `{row.name}: maker {row.maker} want, {tostring(got)} got`)
			end
		end
		failIfAny(problems)
	end, TEST_TIMEOUT)

	it("every file is audio (type 3) and free to take", function()
		local all = gather()
		local problems: { string } = {}
		for _, row in SoundList.entries do
			local info = all[row.id].info
			if info == nil then
				table.insert(problems, `{row.name}: no store data ({tostring(all[row.id].infoError)})`)
			elseif info.assetTypeId ~= AUDIO_TYPE_ID or info.isPublicDomain ~= true then
				table.insert(
					problems,
					`{row.name}: type {tostring(info.assetTypeId)}, free {tostring(info.isPublicDomain)}`
				)
			end
		end
		failIfAny(problems)
	end, TEST_TIMEOUT)

	it("every file loads in 10 s", function()
		local all = gather()
		local problems: { string } = {}
		for _, row in SoundList.entries do
			if all[row.id].timeLength == nil then
				table.insert(problems, `{row.name}: not ready in {LOAD_SECONDS} s`)
			end
		end
		failIfAny(problems)
	end, TEST_TIMEOUT)

	it("every file's length is within 0.1 s of designer's measurement", function()
		local all = gather()
		local problems: { string } = {}
		for _, row in SoundList.entries do
			local got = all[row.id].timeLength
			local want = row.length
			if got == nil then
				table.insert(problems, `{row.name}: {string.format("%.2f", want)} want, no length`)
			elseif math.abs(got - want) > LENGTH_MARGIN then
				table.insert(
					problems,
					`{row.name}: {string.format("%.2f", want)} want, {string.format("%.2f", got)} got`
				)
			end
		end
		failIfAny(problems)
	end, TEST_TIMEOUT)

	it("no AudioPlayer is left in ServerStorage after the checks", function()
		gather()
		local left: { string } = {}
		for _, thing in ServerStorage:GetDescendants() do
			if thing:IsA("AudioPlayer") then
				table.insert(left, thing:GetFullName())
			end
		end
		failIfAny(left)
		expect(ServerStorage:FindFirstChild("SoundFilesCheck")).toBeNil()
	end, TEST_TIMEOUT)
end)
