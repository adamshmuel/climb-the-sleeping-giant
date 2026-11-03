--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ServerStorage = game:GetService("ServerStorage")
local BackgroundRun = require(ServerStorage.Tests.BackgroundRun)

-- Stuck safety Task 51, step 1: a full test run starts in the background and is fetched
-- later as a short report. Every test uses a fake runner and a fake Folder for the attributes, never the real
-- ServerStorage.Tests. A fake Jest result has only the fields the report reads.
describe("BackgroundRun", function()
	local folder: Folder
	local calls: number
	local parked: { thread }

	beforeEach(function()
		folder = Instance.new("Folder")
		calls = 0
		parked = {}
	end)

	afterEach(function()
		folder:Destroy()
	end)

	local function failedTest(name: string, message: string?): any
		return { status = "failed", fullName = name, failureMessages = { message or string.rep("x", 300) } }
	end

	-- A Jest-shaped result: `failedNames` become failed tests, the rest of the passed count are passed ones.
	local function fakeResults(
		passed: number,
		failedNames: { string },
		brokenSuites: number?,
		messages: { [string]: string }?
	): any
		local tests: { any } = {}
		for _, name in failedNames do
			table.insert(tests, failedTest(name, if messages ~= nil then messages[name] else nil))
		end
		return {
			numPassedTests = passed,
			numFailedTests = #failedNames,
			numRuntimeErrorTestSuites = brokenSuites or 0,
			numFailedTestSuites = if #failedNames > 0 then 1 else 0,
			numTotalTests = passed + #failedNames,
			testResults = { { testResults = tests } },
		}
	end

	local function newRun(runner: BackgroundRun.Runner, extra: (() -> string)?): BackgroundRun.Run
		return BackgroundRun.new({ runner = runner, folder = folder, extra = extra })
	end

	local function finishedRunner(results: any): BackgroundRun.Runner
		return function()
			calls += 1
			return results
		end
	end

	-- A runner that reports 3 spec files done and then waits until the test resumes it.
	local function parkedRunner(results: any): BackgroundRun.Runner
		return function(_filter, progress)
			calls += 1
			progress(3)
			table.insert(parked, coroutine.running())
			coroutine.yield()
			return results
		end
	end

	local function lines(report: string): { string }
		return string.split(report, "\n")
	end

	-- Every page of a report, fetched one after the other until a page ends with "end of report" (at most 10 pages).
	local function fetchPages(run: BackgroundRun.Run): { string }
		local pages: { string } = {}
		for _ = 1, 10 do
			local page = run.fetch(0)
			table.insert(pages, page)
			if string.sub(page, -13) == "end of report" or page == "no run" then
				break
			end
		end
		return pages
	end

	-- The failed names (without "FAILED: ") on every page, in the order they were printed.
	local function namesOn(pages: { string }): { string }
		local found: { string } = {}
		for _, page in pages do
			for _, line in lines(page) do
				if string.find(line, "FAILED: ", 1, true) == 1 then
					table.insert(found, string.sub(line, 9))
				end
			end
		end
		return found
	end

	-- 50 failed tests with long names that differ in their first two characters: "01nnn...", "02nnn...".
	local function fiftyLongNames(): { string }
		local names: { string } = {}
		for index = 1, 50 do
			table.insert(names, string.format("%02d", index) .. string.rep("n", 250))
		end
		return names
	end

	it(
		"keeps page 1 of a 50-failure report under 900 characters, in order: first line, counts, extra line, names",
		function()
			local names: { string } = {}
			for index = 1, 50 do
				table.insert(names, `Suite test number {index}`)
			end
			local run = newRun(finishedRunner(fakeResults(2600, names)), function()
				return "117 stuck of 7487"
			end)
			run.start(nil)
			local pages = fetchPages(run)
			local parts = lines(pages[1])
			expect(#pages[1] < 900).toBe(true)
			expect(parts[1]).toBe("TESTS FAILED")
			expect(parts[2]).toBe("2600 passed, 50 failed, 0 suites could not run")
			expect(parts[3]).toBe("117 stuck of 7487")
			expect(parts[4]).toBe("FAILED: Suite test number 1")
			expect(#namesOn(pages)).toBe(50)
		end
	)

	it("lists all 50 long failed names across pages, each page under 900 characters", function()
		local names = fiftyLongNames()
		local run = newRun(finishedRunner(fakeResults(10, names)))
		run.start(nil)
		local pages = fetchPages(run)
		for _, page in pages do
			expect(#page < 900).toBe(true)
		end
		local shown = namesOn(pages)
		expect(#shown).toBe(50)
		for index, name in names do
			expect(shown[index]).toBe(string.sub(name, 1, 100))
		end
		-- Every page but the last says where to look next.
		expect(#pages > 1).toBe(true)
		expect(lines(pages[1])[#lines(pages[1])]).toBe(`more on the next page: fetch again (page 1 of {#pages})`)
	end)

	it("never says 'and N more' for names", function()
		local run = newRun(finishedRunner(fakeResults(10, fiftyLongNames())))
		run.start(nil)
		for _, page in fetchPages(run) do
			expect(string.find(page, "and %d+ more")).toBeNil()
		end
	end)

	it("puts no message before the last name", function()
		local run = newRun(finishedRunner(fakeResults(10, fiftyLongNames())))
		run.start(nil)
		local all: { string } = {}
		for _, page in fetchPages(run) do
			for _, line in lines(page) do
				table.insert(all, line)
			end
		end
		local lastName = 0
		local firstMessage = math.huge
		for index, line in all do
			if string.find(line, " | ", 1, true) ~= nil then
				firstMessage = math.min(firstMessage, index)
			elseif string.find(line, "FAILED: ", 1, true) == 1 then
				lastName = index
			end
		end
		expect(lastName > 0).toBe(true)
		expect(firstMessage < math.huge).toBe(true) -- the report does carry messages
		expect(firstMessage > lastName).toBe(true)
	end)

	it("keeps the folder until the last page is fetched, and the last page ends with 'end of report'", function()
		local run = newRun(finishedRunner(fakeResults(10, fiftyLongNames())))
		run.start(nil)
		local first = run.fetch(0)
		expect(string.sub(first, -13)).never.toBe("end of report")
		expect(folder:GetAttribute("Status")).toBe("done")
		local last = first
		for _ = 1, 10 do
			if string.sub(last, -13) == "end of report" then
				break
			end
			expect(folder:GetAttribute("Status")).toBe("done")
			last = run.fetch(0)
		end
		expect(string.sub(last, -13)).toBe("end of report")
		expect(folder:GetAttribute("Status")).toBeNil()
	end)

	it("a run with 13 failures names all 13 on page 1 or 2, then their first messages", function()
		local names: { string } = {}
		for index = 1, 13 do
			table.insert(names, string.format("%02d", index) .. string.rep("n", 98))
		end
		local run = newRun(finishedRunner(fakeResults(10, names)))
		run.start(nil)
		local pages = fetchPages(run)
		expect(#namesOn({ pages[1], pages[2] or "" })).toBe(13)
		local all: { string } = {}
		for _, page in pages do
			for _, line in lines(page) do
				table.insert(all, line)
			end
		end
		local lastName = 0
		for index, line in all do
			if string.find(line, "FAILED: ", 1, true) == 1 then
				lastName = index
			end
		end
		expect(all[lastName + 1]).toBe(string.sub(names[1], 1, 40) .. " | " .. string.rep("x", 150))
	end)

	-- The shape of the real red run in work/t58b/step2-result.md: 5 failures with long names and long messages.
	local function longFailures(): { string }
		local names: { string } = {}
		for index = 1, 5 do
			table.insert(names, string.rep("n", 99) .. index)
		end
		return names
	end

	it(
		"names all 5 failed tests, each with a long name and a 150-character message, with no 'and N more' line",
		function()
			local run = newRun(finishedRunner(fakeResults(10, longFailures())))
			run.start(nil)
			local pages = fetchPages(run)
			local count = 0
			local messageLines = 0
			for _, page in pages do
				expect(#page < 900).toBe(true)
				for _, line in lines(page) do
					if string.find(line, "FAILED: ", 1, true) == 1 then
						count += 1
					elseif string.find(line, " | ", 1, true) ~= nil then
						messageLines += 1
					end
					expect(string.find(line, "and %d+ more")).toBeNil()
				end
			end
			expect(count).toBe(5)
			expect(messageLines).toBe(5)
		end
	)

	it("gives messages to the earliest failures while room is left", function()
		local names: { string } = {}
		for index = 1, 5 do
			table.insert(names, string.format("%02d", index) .. string.rep("n", 98))
		end
		local run = newRun(finishedRunner(fakeResults(10, names)))
		run.start(nil)
		local messageLines: { string } = {}
		for _, page in fetchPages(run) do
			for _, line in lines(page) do
				if string.find(line, " | ", 1, true) ~= nil then
					table.insert(messageLines, line)
				end
			end
		end
		expect(#messageLines).toBe(5)
		for index, line in messageLines do
			expect(line).toBe(string.sub(names[index], 1, 40) .. " | " .. string.rep("x", 150))
		end
	end)

	it("lists every failed test by name and has no 'and N more' line when they all fit", function()
		local run = newRun(finishedRunner(fakeResults(5, { "Alpha one", "Beta two" })))
		run.start(nil)
		local parts = lines(run.fetch(0))
		expect(parts).toEqual({
			"TESTS FAILED",
			"5 passed, 2 failed, 0 suites could not run",
			"FAILED: Alpha one",
			"FAILED: Beta two",
			"Alpha one | " .. string.rep("x", 150),
			"Beta two | " .. string.rep("x", 150),
			"end of report",
		})
	end)

	it("a failed test's message line carries its first failure message, cut short", function()
		local longName = string.rep("n", 60)
		local run = newRun(finishedRunner(fakeResults(5, { longName })))
		run.start(nil)
		expect(lines(run.fetch(0))[4]).toBe(string.rep("n", 40) .. " | " .. string.rep("x", 150))
	end)

	it("a message with many lines is joined on one line, with blank lines and colours removed", function()
		local message =
			"\27[2mexpect(received).toBe(expected)\27[0m\n\nExpected: \27[32m0\27[0m\nReceived: \27[31m2\27[0m"
		local run = newRun(finishedRunner(fakeResults(5, { "Beta two" }, nil, { ["Beta two"] = message })))
		run.start(nil)
		expect(lines(run.fetch(0))[4]).toBe("Beta two | expect(received).toBe(expected) / Expected: 0 / Received: 2")
	end)

	it("starts with TESTS PASSED and has no failed-test lines when everything passes", function()
		local run = newRun(finishedRunner(fakeResults(8, {})))
		run.start(nil)
		expect(run.fetch(0)).toBe("TESTS PASSED\n8 passed, 0 failed, 0 suites could not run\nend of report")
	end)

	it("refuses a second start while a run is going and does not call the runner again", function()
		local run = newRun(parkedRunner(fakeResults(1, {})))
		expect(run.start(nil)).toBe("started")
		expect(run.start(nil)).toBe("already running")
		expect(calls).toBe(1)
	end)

	it("clears every attribute when a finished run is fetched, and allows a new start", function()
		local run = newRun(finishedRunner(fakeResults(1, {})))
		run.start(nil)
		run.fetch(0)
		expect(next(folder:GetAttributes())).toBeNil()
		expect(run.start(nil)).toBe("started")
		expect(calls).toBe(2)
	end)

	it("returns 'running' with how many spec files are done when the run is not finished", function()
		local run = newRun(parkedRunner(fakeResults(1, {})))
		run.start(nil)
		expect(run.fetch(0)).toBe("running, 3 spec files done")
		-- The unfinished fetch must not clear the run: it finishes afterwards and a second fetch gets the report.
		task.spawn(parked[1])
		expect(run.fetch(0)).toBe("TESTS PASSED\n1 passed, 0 failed, 0 suites could not run\nend of report")
	end)

	it("gives a report that starts with TESTS FAILED and the error when the runner errors", function()
		local run = newRun(function()
			error("the runner broke")
		end)
		run.start(nil)
		local report = run.fetch(0)
		expect(lines(report)[1]).toBe("TESTS FAILED")
		expect((string.find(report, "the runner broke", 1, true))).never.toBeNil()
		expect(#report < 900).toBe(true)
	end)

	it("passes the name filter to the runner", function()
		local seen: string? = "unset"
		local run = newRun(function(filter)
			seen = filter
			return fakeResults(1, {})
		end)
		run.start("RealWorld")
		run.fetch(0)
		expect(seen).toBe("RealWorld")
	end)

	it("returns 'no run' when nothing was started", function()
		local run = newRun(finishedRunner(fakeResults(1, {})))
		expect(run.fetch(0)).toBe("no run")
	end)
end)
