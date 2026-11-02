--!strict
-- Starts a test run in the background and fetches a short report later (Lessons 22, 29 and 51).
-- A full run holds Studio for about a minute, so the caller starts it, waits, then fetches once. The state lives in
-- attributes (named values) on `folder`: Status ("running" or "done"), Done (spec files finished), Page1, Page2 ...
-- (the report, one page per fetch), PageCount and PageNext. Every page stays under 900 characters, because Studio
-- cuts a result at 1024 and the counts and the extra line (for example a scan result) must never be cut off. The
-- attributes are cleared only when the last page is fetched.
export type Runner = (filter: string?, progress: (number) -> ()) -> any
export type Deps = { runner: Runner, folder: Instance, extra: (() -> string)? }
export type Run = { start: (filter: string?) -> string, fetch: (maxWait: number) -> string }

local PlainText = require(game:GetService("ServerStorage").Tests.PlainText)

local REPORT_LIMIT = 899 -- characters per page: the most that stays under 900
local NAME_LIMIT = 100 -- characters kept of each failed test's name
local WHY_LIMIT = 150 -- characters kept of each failed test's first failure message
local EXTRA_LIMIT = 200 -- characters kept of the extra line
local ERROR_LIMIT = 300 -- characters kept of an error message
local MESSAGE_NAME_LIMIT = 40 -- characters kept of a failed test's name on its message line
local POINTER_RESERVE = 51 -- room kept free on a page for its "more on the next page" line (and its line break)
local MESSAGE_PAGES = 2 -- most pages that failure messages may add after the last page of names
local LEFT_OUT_RESERVE = 31 -- room kept free for the "messages left out for N tests" line (and its line break)
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

type Failure = { name: string, why: string? }

-- One entry per failed test: its cut name, and its cut message when it has one.
local function failures(results: any): { Failure }
	local found: { Failure } = {}
	for _, suite in results.testResults or {} do
		for _, test in suite.testResults or {} do
			if test.status == "failed" then
				table.insert(found, { name = cut(tostring(test.fullName), NAME_LIMIT), why = whyText(test) })
			end
		end
	end
	return found
end

-- The report as a list of pages, each under the limit. Page 1 starts with the first line, the counts and the extra
-- line. Then come every failed test's name (never dropped: a full page ends with a pointer to the next one), then,
-- the messages of the earliest failures while room is left (at most MESSAGE_PAGES more pages). The last page ends with "end of report".
local function buildPages(results: any, extraLine: string?): { string }
	local passed: number = results.numPassedTests or 0
	local failed: number = results.numFailedTests or 0
	local broken: number = results.numRuntimeErrorTestSuites or 0
	local failedSuites: number = results.numFailedTestSuites or 0
	local total: number = results.numTotalTests or 0
	local ok = failed == 0 and broken == 0 and failedSuites == 0 and total > 0
	local head: { string } = {
		if ok then "TESTS PASSED" else "TESTS FAILED",
		`{passed} passed, {failed} failed, {broken} suites could not run`,
	}
	if extraLine ~= nil and extraLine ~= "" then
		table.insert(head, cut(extraLine, EXTRA_LIMIT))
	end
	local pages: { { string } } = { head }
	local budget = REPORT_LIMIT - POINTER_RESERVE -- every page keeps room for its closing line
	local length = #table.concat(head, "\n")
	local function place(line: string, room: number): boolean
		if length + 1 + #line <= room then
			table.insert(pages[#pages], line)
			length += 1 + #line
			return true
		end
		return false
	end
	local found = failures(results)
	for _, failure in found do
		local line = `FAILED: {failure.name}`
		if not place(line, budget) then
			table.insert(pages, { line })
			length = #line
		end
	end
	local messages: { string } = {}
	for _, failure in found do
		if failure.why ~= nil then
			table.insert(messages, `{cut(failure.name, MESSAGE_NAME_LIMIT)} | {failure.why}`)
		end
	end
	local lastNamePage = #pages
	local added = 0
	for index, message in messages do
		local onLastPage = #pages - lastNamePage >= MESSAGE_PAGES
		local room = if onLastPage and index < #messages then budget - LEFT_OUT_RESERVE else budget
		if not place(message, room) then
			if onLastPage then
				break
			end
			table.insert(pages, { message })
			length = #message
		end
		added += 1
	end
	if added < #messages then
		table.insert(pages[#pages], `messages left out for {#messages - added} tests`)
	end
	local texts: { string } = {}
	for index, page in pages do
		table.insert(
			page,
			if index < #pages then `more on the next page: fetch again (page {index} of {#pages})` else "end of report"
		)
		table.insert(texts, table.concat(page, "\n"))
	end
	return texts
end

function BackgroundRun.new(deps: Deps): Run
	local folder = deps.folder

	local function clear()
		for name in folder:GetAttributes() do
			folder:SetAttribute(name, nil)
		end
	end

	local function runAndStore(filter: string?)
		local ok, outcome = pcall(function(): { string }
			local results = deps.runner(filter, function(done: number)
				folder:SetAttribute("Done", done)
			end)
			local extraLine: string? = nil
			if deps.extra ~= nil then
				local extraOk, extraResult = pcall(deps.extra)
				extraLine = if extraOk then tostring(extraResult) else `extra line failed: {tostring(extraResult)}`
			end
			return buildPages(results, extraLine)
		end)
		local pages: { string } = if ok
			then outcome
			else { `TESTS FAILED\n{cut(tostring(outcome), ERROR_LIMIT)}\nend of report` }
		for index, page in pages do
			folder:SetAttribute(`Page{index}`, page)
		end
		folder:SetAttribute("PageCount", #pages)
		folder:SetAttribute("PageNext", 1)
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
		local pageIndex: number = (folder:GetAttribute("PageNext") :: number?) or 1
		local count: number = (folder:GetAttribute("PageCount") :: number?) or 1
		local page = tostring(folder:GetAttribute(`Page{pageIndex}`))
		if pageIndex >= count then
			clear()
		else
			folder:SetAttribute("PageNext", pageIndex + 1)
		end
		return page
	end

	return { start = start, fetch = fetch }
end

return BackgroundRun
