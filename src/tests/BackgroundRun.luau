--!strict
-- Starts a test run in the background and fetches a short report later (Lessons 22, 29 and 51).
-- A full run holds Studio for about a minute, so the caller starts it, waits, then fetches once. The state lives in
-- attributes (named values) on `folder`: Status ("running" or "done"), Done (spec files finished) and Report.
-- The report always stays under 900 characters, because Studio cuts a result at 1024 and the counts and the extra
-- line (for example a scan result) must never be cut off.
export type Runner = (filter: string?, progress: (number) -> ()) -> any
export type Deps = { runner: Runner, folder: Instance, extra: (() -> string)? }
export type Run = { start: (filter: string?) -> string, fetch: (maxWait: number) -> string }

local PlainText = require(game:GetService("ServerStorage").Tests.PlainText)

local REPORT_LIMIT = 880 -- characters: a safe margin under the 900 the report must stay below
local NAME_LIMIT = 100 -- characters kept of each failed test's name
local WHY_LIMIT = 150 -- characters kept of each failed test's first failure message
local EXTRA_LIMIT = 200 -- characters kept of the extra line
local ERROR_LIMIT = 300 -- characters kept of an error message
local MORE_LINE_RESERVE = 24 -- room kept free for the closing "and N more" line
local POLL_SECONDS = 0.1

local BackgroundRun = {}

local function cut(text: string, limit: number): string
	return string.sub(text, 1, limit)
end

-- The test's first failure message on one line: colours removed, blank lines dropped, lines joined with " / ".
local function whyText(test: any): string?
	local first = (test.failureMessages or {})[1]
	if first == nil then
		return nil
	end
	local kept: { string } = {}
	for _, line in string.split(PlainText.stripColors(tostring(first)), "\n") do
		if string.find(line, "%S") ~= nil then
			table.insert(kept, line)
		end
	end
	if #kept == 0 then
		return nil
	end
	return cut(table.concat(kept, " / "), WHY_LIMIT)
end

-- One entry per failed test: its cut name, then " | " and its cut message when it has one.
local function failedNames(results: any): { string }
	local names: { string } = {}
	for _, suite in results.testResults or {} do
		for _, test in suite.testResults or {} do
			if test.status == "failed" then
				local name = cut(tostring(test.fullName), NAME_LIMIT)
				local why = whyText(test)
				table.insert(names, if why ~= nil then `{name} | {why}` else name)
			end
		end
	end
	return names
end

-- The first line, the counts, the extra line, then as many failed test names as fit, then "and N more".
local function buildReport(results: any, extraLine: string?): string
	local passed: number = results.numPassedTests or 0
	local failed: number = results.numFailedTests or 0
	local broken: number = results.numRuntimeErrorTestSuites or 0
	local failedSuites: number = results.numFailedTestSuites or 0
	local total: number = results.numTotalTests or 0
	local ok = failed == 0 and broken == 0 and failedSuites == 0 and total > 0
	local lines: { string } = {
		if ok then "TESTS PASSED" else "TESTS FAILED",
		`{passed} passed, {failed} failed, {broken} suites could not run`,
	}
	if extraLine ~= nil and extraLine ~= "" then
		table.insert(lines, cut(extraLine, EXTRA_LIMIT))
	end
	local length = #table.concat(lines, "\n")
	local names = failedNames(results)
	local shown = 0
	for index, name in names do
		local line = `FAILED: {name}`
		local isLast = index == #names
		local room = REPORT_LIMIT - length - 1 - (if isLast then 0 else MORE_LINE_RESERVE)
		if #line > room then
			break
		end
		table.insert(lines, line)
		length += #line + 1
		shown += 1
	end
	if shown < #names then
		table.insert(lines, `and {#names - shown} more`)
	end
	return table.concat(lines, "\n")
end

function BackgroundRun.new(deps: Deps): Run
	local folder = deps.folder

	local function clear()
		for name in folder:GetAttributes() do
			folder:SetAttribute(name, nil)
		end
	end

	local function runAndStore(filter: string?)
		local ok, outcome = pcall(function(): string
			local results = deps.runner(filter, function(done: number)
				folder:SetAttribute("Done", done)
			end)
			local extraLine: string? = nil
			if deps.extra ~= nil then
				local extraOk, extraResult = pcall(deps.extra)
				extraLine = if extraOk then tostring(extraResult) else `extra line failed: {tostring(extraResult)}`
			end
			return buildReport(results, extraLine)
		end)
		local report = if ok then outcome else `TESTS FAILED\n{cut(tostring(outcome), ERROR_LIMIT)}`
		folder:SetAttribute("Report", report)
		folder:SetAttribute("Status", "done")
	end

	local function start(filter: string?): string
		if folder:GetAttribute("Status") == "running" then
			return "already running"
		end
		clear()
		folder:SetAttribute("Status", "running")
		folder:SetAttribute("Done", 0)
		task.spawn(runAndStore, filter)
		return "started"
	end

	local function fetch(maxWait: number): string
		if folder:GetAttribute("Status") == nil then
			return "no run"
		end
		local waited = 0
		while folder:GetAttribute("Status") ~= "done" and waited < maxWait do
			task.wait(POLL_SECONDS)
			waited += POLL_SECONDS
		end
		if folder:GetAttribute("Status") ~= "done" then
			return `running, {folder:GetAttribute("Done") or 0} spec files done`
		end
		local report = tostring(folder:GetAttribute("Report"))
		clear()
		return report
	end

	return { start = start, fetch = fetch }
end

return BackgroundRun
