--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ServerStorage = game:GetService("ServerStorage")
local BackgroundRun = require(ServerStorage.Tests.BackgroundRun)

-- Stuck safety Task 51, step 1 (lessons 22, 29, 31 and 51): a full test run starts in the background and is fetched
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

	it("keeps a report with 50 failed tests under 900 characters, in order: first line, counts, extra line", function()
		local names: { string } = {}
		for index = 1, 50 do
			table.insert(names, `Suite test number {index}`)
		end
		local run = newRun(finishedRunner(fakeResults(2600, names)), function()
			return "117 stuck of 7487"
		end)
		run.start(nil)
		local report = run.fetch(0)
		local parts = lines(report)
		expect(#report < 900).toBe(true)
		expect(parts[1]).toBe("TESTS FAILED")
		expect(parts[2]).toBe("2600 passed, 50 failed, 0 suites could not run")
		expect(parts[3]).toBe("117 stuck of 7487")
		expect((string.find(parts[4] or "", "FAILED: Suite test number 1", 1, true))).never.toBeNil()
	end)

	it("names each failed test cut to 100 characters and ends with 'and N more' when there are too many", function()
		local names: { string } = {}
		for index = 1, 50 do
			table.insert(names, string.rep("n", 250) .. index)
		end
		local run = newRun(finishedRunner(fakeResults(10, names)))
		run.start(nil)
		local parts = lines(run.fetch(0))
		expect(parts[3]).toBe("FAILED: " .. string.rep("n", 100) .. " | " .. string.rep("x", 150))
		local last = parts[#parts]
		local more = string.match(last, "^and (%d+) more$")
		expect(more).never.toBeNil()
		local shown = #parts - 3 -- the first line, the counts, and this "and N more" line are not names
		expect(shown + (tonumber(more :: string) :: number)).toBe(50)
	end)

	it("lists every failed test by name and has no 'and N more' line when they all fit", function()
		local run = newRun(finishedRunner(fakeResults(5, { "Alpha one", "Beta two" })))
		run.start(nil)
		local parts = lines(run.fetch(0))
		expect(parts).toEqual({
			"TESTS FAILED",
			"5 passed, 2 failed, 0 suites could not run",
			"FAILED: Alpha one | " .. string.rep("x", 150),
			"FAILED: Beta two | " .. string.rep("x", 150),
		})
	end)

	it("a failed test's line carries its first failure message, cut short", function()
		local run = newRun(finishedRunner(fakeResults(5, { "Alpha one" })))
		run.start(nil)
		expect(lines(run.fetch(0))[3]).toBe("FAILED: Alpha one | " .. string.rep("x", 150))
	end)

	it("a message with many lines is joined on one line, with blank lines and colours removed", function()
		local message =
			"\27[2mexpect(received).toBe(expected)\27[0m\n\nExpected: \27[32m0\27[0m\nReceived: \27[31m2\27[0m"
		local run = newRun(finishedRunner(fakeResults(5, { "Beta two" }, nil, { ["Beta two"] = message })))
		run.start(nil)
		expect(lines(run.fetch(0))[3]).toBe(
			"FAILED: Beta two | expect(received).toBe(expected) / Expected: 0 / Received: 2"
		)
	end)

	it("starts with TESTS PASSED and has no failed-test lines when everything passes", function()
		local run = newRun(finishedRunner(fakeResults(8, {})))
		run.start(nil)
		expect(run.fetch(0)).toBe("TESTS PASSED\n8 passed, 0 failed, 0 suites could not run")
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
		expect(run.fetch(0)).toBe("TESTS PASSED\n1 passed, 0 failed, 0 suites could not run")
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
