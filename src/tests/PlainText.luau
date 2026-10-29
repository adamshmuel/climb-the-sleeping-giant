--!strict
-- Plain-text helpers shared by the test reports.
local PlainText = {}

-- Jest colours its messages with ANSI codes, which only look like junk in plain text.
function PlainText.stripColors(text: string): string
	local plain = string.gsub(text, "\27%[[%d;]*m", "")
	return plain
end

return PlainText
