--!strict
-- Pure text sanitizing for server-sent notifications (unit-tested under Lune).

local TextClean = {}

-- Strips control characters (keeps newlines when allowed) and cuts to maxLen bytes on a UTF-8 boundary.
function TextClean.clean(v: any, maxLen: number, allowNewlines: boolean?): string?
	if type(v) == "number" then
		v = tostring(v)
	end
	if type(v) ~= "string" then
		return nil
	end
	local s: string = v
	if utf8.len(s) == nil then
		s = string.gsub(s, "[\128-\255]", "")
	end
	if allowNewlines then
		s = string.gsub(s, "[%z\1-\9\11-\31\127]", "")
	else
		s = string.gsub(s, "[%z\1-\31\127]", " ")
	end
	s = string.match(s, "^%s*(.-)%s*$") or ""
	if s == "" then
		return nil
	end
	if #s > maxLen then
		-- Cut to maxLen bytes, then back off to a whole UTF-8 character.
		s = string.sub(s, 1, maxLen)
		for _ = 1, 4 do
			if utf8.len(s) ~= nil then
				break
			end
			s = string.sub(s, 1, #s - 1)
		end
	end
	return s
end

return TextClean
