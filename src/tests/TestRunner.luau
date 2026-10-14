--!strict
-- Runs every Jest test in ServerStorage.Tests and returns a plain-text report.
-- Run it in Studio edit mode with execute_luau:
--   return require(game:GetService("ServerStorage").Tests.TestRunner:Clone())()
-- The first line is "TESTS PASSED" or "TESTS FAILED". The second line has the counts.
-- After that come every suite that could not run and every failed test with its messages.

local ServerStorage = game:GetService("ServerStorage")

-- Jest colours its messages with ANSI codes, which only look like junk in plain text.
local function stripColors(text: string): string
	local plain = string.gsub(text, "\27%[[%d;]*m", "")
	return plain
end

local function describeError(value: any): string
	if type(value) == "table" then
		local message = value.message or value.stack
		if message ~= nil then
			return stripColors(tostring(message))
		end
	end
	return stripColors(tostring(value))
end

local function buildReport(results: any): string
	local passedCount: number = results.numPassedTests or 0
	local failedCount: number = results.numFailedTests or 0
	local brokenSuites: number = results.numRuntimeErrorTestSuites or 0
	local failedSuites: number = results.numFailedTestSuites or 0
	local totalCount: number = results.numTotalTests or 0

	local details: { string } = {}
	for _, suite in results.testResults or {} do
		if suite.testExecError ~= nil then
			table.insert(details, `SUITE COULD NOT RUN: {suite.testFilePath}\n{describeError(suite.testExecError)}`)
		end
		for _, test in suite.testResults or {} do
			if test.status == "failed" then
				local messages = stripColors(table.concat(test.failureMessages or {}, "\n"))
				table.insert(details, `FAILED: {test.fullName}\n{messages}`)
			end
		end
	end

	local ok = failedCount == 0 and brokenSuites == 0 and failedSuites == 0 and totalCount > 0
	local lines: { string } = {
		if ok then "TESTS PASSED" else "TESTS FAILED",
		`{passedCount} passed, {failedCount} failed, {brokenSuites} suites could not run`,
	}
	if totalCount == 0 and brokenSuites == 0 then
		table.insert(lines, "No tests were found. Check the name filter.")
	end
	for _, detail in details do
		table.insert(lines, detail)
	end
	return table.concat(lines, "\n")
end

return function(nameFilter: string?): string
	local loaded, Jest = pcall(function(): any
		return require(ServerStorage.DevPackages.Jest)
	end)
	if not loaded then
		return `TESTS FAILED\nJest could not run: {describeError(Jest)}`
	end

	local started, succeeded, outcome = pcall(function(): (boolean, any)
		return Jest.runCLI(ServerStorage.Tests, { ci = true, testPathPattern = nameFilter }, { ServerStorage.Tests })
			:await()
	end)
	if not started then
		return `TESTS FAILED\nJest could not run: {describeError(succeeded)}`
	end
	if not succeeded then
		return `TESTS FAILED\nJest could not run: {describeError(outcome)}\n(If you passed a name filter, check that it matches a spec file.)`
	end
	return buildReport(outcome.results)
end
