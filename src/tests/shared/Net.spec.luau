--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Net = require(ReplicatedStorage.Shared.Net)

-- Every fake parent made by a test is destroyed afterwards, so the real place is never changed.
local madeParents: { Instance } = {}
local function newParent(): Instance
	local parent = Instance.new("Folder")
	table.insert(madeParents, parent)
	return parent
end

afterEach(function()
	for _, instance in madeParents do
		instance:Destroy()
	end
	table.clear(madeParents)
end)

describe("Net.setup", function()
	it("creates the Warning remote inside a Remotes folder", function()
		local parent = newParent()
		Net.setup(parent)
		local remotes = parent:FindFirstChild("Remotes")
		expect(remotes).never.toBeNil()
		expect((remotes :: Instance):IsA("Folder")).toBe(true)
		local warning = (remotes :: Instance):FindFirstChild("Warning")
		expect(warning).never.toBeNil()
		expect((warning :: Instance):IsA("RemoteEvent")).toBe(true)
	end)

	it("creates the SetTiptoe remote inside the Remotes folder", function()
		local parent = newParent()
		Net.setup(parent)
		local setTiptoe = (parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("SetTiptoe")
		expect(setTiptoe).never.toBeNil()
		expect((setTiptoe :: Instance):IsA("RemoteEvent")).toBe(true)
	end)

	it("creates the GrabMissed remote inside the Remotes folder", function()
		local parent = newParent()
		Net.setup(parent)
		local grabMissed = (parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("GrabMissed")
		expect(grabMissed).never.toBeNil()
		expect((grabMissed :: Instance):IsA("RemoteEvent")).toBe(true)
	end)

	it("creates the EggHome remote inside the Remotes folder", function()
		local parent = newParent()
		Net.setup(parent)
		local eggHome = (parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("EggHome")
		expect(eggHome).never.toBeNil()
		expect((eggHome :: Instance):IsA("RemoteEvent")).toBe(true)
	end)

	it("creates the Bounced remote inside the Remotes folder", function()
		local parent = newParent()
		Net.setup(parent)
		local bounced = (parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("Bounced")
		expect(bounced).never.toBeNil()
		expect((bounced :: Instance):IsA("RemoteEvent")).toBe(true)
	end)

	it("creates the SlamWarning, SlamLanded and Caught remotes inside the Remotes folder", function()
		local parent = newParent()
		Net.setup(parent)
		local remotes = parent:FindFirstChild("Remotes") :: Instance
		for _, name in { "SlamWarning", "SlamLanded", "Caught" } do
			local remote = remotes:FindFirstChild(name)
			expect(remote).never.toBeNil()
			expect((remote :: Instance):IsA("RemoteEvent")).toBe(true)
		end
	end)

	it("creates GiantState with Meter 0 and Phase Asleep", function()
		local parent = newParent()
		Net.setup(parent)
		local state = parent:FindFirstChild("GiantState")
		expect(state).never.toBeNil()
		expect((state :: Instance):IsA("Folder")).toBe(true)
		expect((state :: Instance):GetAttribute("Meter")).toBe(0)
		expect((state :: Instance):GetAttribute("Phase")).toBe("Asleep")
	end)

	it("returns the folders and the remote it made", function()
		local parent = newParent()
		local result = Net.setup(parent)
		expect(result.GiantState).toBe(parent:FindFirstChild("GiantState"))
		expect(result.Remotes).toBe(parent:FindFirstChild("Remotes"))
		expect(result.Warning).toBe(result.Remotes:FindFirstChild("Warning"))
		expect(result.SetTiptoe).toBe(result.Remotes:FindFirstChild("SetTiptoe"))
		expect(result.GrabMissed).toBe(result.Remotes:FindFirstChild("GrabMissed"))
		expect(result.EggHome).never.toBeNil()
		expect(result.EggHome).toBe(result.Remotes:FindFirstChild("EggHome"))
		expect(result.Bounced).never.toBeNil()
		expect(result.Bounced).toBe(result.Remotes:FindFirstChild("Bounced"))
		expect(result.SlamWarning).never.toBeNil()
		expect(result.SlamWarning).toBe(result.Remotes:FindFirstChild("SlamWarning"))
		expect(result.SlamLanded).never.toBeNil()
		expect(result.SlamLanded).toBe(result.Remotes:FindFirstChild("SlamLanded"))
		expect(result.Caught).never.toBeNil()
		expect(result.Caught).toBe(result.Remotes:FindFirstChild("Caught"))
	end)

	it("creates nothing new when it is called twice", function()
		local parent = newParent()
		local first = Net.setup(parent)
		first.GiantState:SetAttribute("Meter", 42)
		local second = Net.setup(parent)
		expect(#parent:GetDescendants()).toBe(10)
		expect(second.GiantState).toBe(first.GiantState)
		expect(second.Warning).toBe(first.Warning)
		expect(second.SetTiptoe).toBe(first.SetTiptoe)
		expect(second.GrabMissed).toBe(first.GrabMissed)
		expect(second.EggHome).toBe(first.EggHome)
		expect(second.Bounced).toBe(first.Bounced)
		expect(second.SlamWarning).toBe(first.SlamWarning)
		expect(second.SlamLanded).toBe(first.SlamLanded)
		expect(second.Caught).toBe(first.Caught)
		expect(second.GiantState:GetAttribute("Meter")).toBe(42)
	end)

	it("creates nothing when the module is only loaded", function()
		local before = #ReplicatedStorage:GetDescendants()
		local freshCopy = ReplicatedStorage.Shared.Net:Clone()
		-- Loads the module again, as if for the first time. The checker can't follow a path it can't see.
		local load: (ModuleScript) -> any = require :: any
		load(freshCopy)
		freshCopy:Destroy()
		expect(#ReplicatedStorage:GetDescendants()).toBe(before)
	end)
end)

describe("Net.waitForClient", function()
	-- Fills a fake parent the way the server's Net.setup does.
	local function serverMade(): Instance
		local parent = newParent()
		Net.setup(parent)
		return parent
	end

	it(
		"finds Remotes, Warning, SetTiptoe, GrabMissed, EggHome, Bounced, SlamWarning, SlamLanded, Caught and GiantState under the parent",
		function()
			local parent = serverMade()
			local found = Net.waitForClient(parent, 1)
			expect(found).never.toBeNil()
			local made = found :: Net.Made
			expect(made.Remotes).toBe(parent:FindFirstChild("Remotes"))
			expect(made.GiantState).toBe(parent:FindFirstChild("GiantState"))
			expect(made.Warning).toBe((parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("Warning"))
			expect(made.SetTiptoe).toBe((parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("SetTiptoe"))
			expect(made.GrabMissed).toBe((parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("GrabMissed"))
			expect(made.EggHome).never.toBeNil()
			expect(made.EggHome).toBe((parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("EggHome"))
			expect(made.Bounced).never.toBeNil()
			expect(made.Bounced).toBe((parent:FindFirstChild("Remotes") :: Instance):FindFirstChild("Bounced"))
			local remotes = parent:FindFirstChild("Remotes") :: Instance
			expect(made.SlamWarning).never.toBeNil()
			expect(made.SlamWarning).toBe(remotes:FindFirstChild("SlamWarning"))
			expect(made.SlamLanded).never.toBeNil()
			expect(made.SlamLanded).toBe(remotes:FindFirstChild("SlamLanded"))
			expect(made.Caught).never.toBeNil()
			expect(made.Caught).toBe(remotes:FindFirstChild("Caught"))
		end
	)

	it("waits for items that arrive a little later", function()
		local parent = newParent()
		task.delay(0.1, function()
			Net.setup(parent)
		end)
		local found = Net.waitForClient(parent, 2)
		expect(found).never.toBeNil()
	end)

	it("returns nil and says why when the items never arrive", function()
		local parent = newParent()
		local messages: { string } = {}
		local started = os.clock()
		local found = Net.waitForClient(parent, 0.2, function(message: string)
			table.insert(messages, message)
		end)
		expect(found).toBeNil()
		expect(os.clock() - started < 2).toBe(true)
		expect(#messages).toBe(1)
		expect(messages[1]).toContain("Remotes")
	end)

	it("returns nil when only some of the items arrive", function()
		local parent = newParent()
		local remotes = Instance.new("Folder")
		remotes.Name = Net.RemotesName
		remotes.Parent = parent
		local messages: { string } = {}
		local found = Net.waitForClient(parent, 0.2, function(message: string)
			table.insert(messages, message)
		end)
		expect(found).toBeNil()
		expect(#messages).toBe(1)
	end)

	it("returns nil and names SetTiptoe when only that remote is missing", function()
		local parent = serverMade()
		local remotes = parent:FindFirstChild("Remotes") :: Instance
		local setTiptoe = remotes:FindFirstChild("SetTiptoe") :: Instance
		setTiptoe:Destroy()
		local messages: { string } = {}
		local found = Net.waitForClient(parent, 0.2, function(message: string)
			table.insert(messages, message)
		end)
		expect(found).toBeNil()
		expect(#messages).toBe(1)
		expect(messages[1]).toContain("Remotes.SetTiptoe")
	end)

	it("returns nil and names GrabMissed when only that remote is missing", function()
		local parent = serverMade()
		local remotes = parent:FindFirstChild("Remotes") :: Instance
		local grabMissed = remotes:FindFirstChild("GrabMissed") :: Instance
		grabMissed:Destroy()
		local messages: { string } = {}
		local found = Net.waitForClient(parent, 0.2, function(message: string)
			table.insert(messages, message)
		end)
		expect(found).toBeNil()
		expect(#messages).toBe(1)
		expect(messages[1]).toContain("Remotes.GrabMissed")
	end)

	it("returns nil and names EggHome when only that remote is missing", function()
		local parent = serverMade()
		local remotes = parent:FindFirstChild("Remotes") :: Instance
		local eggHome = remotes:FindFirstChild("EggHome") :: Instance
		eggHome:Destroy()
		local messages: { string } = {}
		local found = Net.waitForClient(parent, 0.2, function(message: string)
			table.insert(messages, message)
		end)
		expect(found).toBeNil()
		expect(#messages).toBe(1)
		expect(messages[1]).toContain("Remotes.EggHome")
	end)

	it("returns nil and names Bounced when only that remote is missing", function()
		local parent = serverMade()
		local remotes = parent:FindFirstChild("Remotes") :: Instance
		local bounced = remotes:FindFirstChild("Bounced") :: Instance
		bounced:Destroy()
		local messages: { string } = {}
		local found = Net.waitForClient(parent, 0.2, function(message: string)
			table.insert(messages, message)
		end)
		expect(found).toBeNil()
		expect(#messages).toBe(1)
		expect(messages[1]).toContain("Remotes.Bounced")
	end)

	for _, name in { "SlamWarning", "SlamLanded", "Caught" } do
		it(`returns nil and names {name} when only that remote is missing`, function()
			local parent = serverMade()
			local remotes = parent:FindFirstChild("Remotes") :: Instance
			local remote = remotes:FindFirstChild(name) :: Instance
			remote:Destroy()
			local messages: { string } = {}
			local found = Net.waitForClient(parent, 0.2, function(message: string)
				table.insert(messages, message)
			end)
			expect(found).toBeNil()
			expect(#messages).toBe(1)
			expect(messages[1]).toContain(`Remotes.{name}`)
		end)
	end

	it("returns nil when an item is the wrong kind of object", function()
		local parent = newParent()
		for _, name in { Net.RemotesName, Net.GiantStateName } do
			local wrong = Instance.new("Part")
			wrong.Name = name
			wrong.Parent = parent
		end
		local found = Net.waitForClient(parent, 0.2, function() end)
		expect(found).toBeNil()
	end)
end)
