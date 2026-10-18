--!strict
-- ProfileService: first-name filtering (RUNTIME ONLY, server). Names are shown to every player (profile cards,
-- banners), so they go through TextService for broadcast. Yields.
--
--   Names.filter(name, userId, fallback) -> (text, status)
--     status "ok"       text is the name, unchanged by the filter
--     status "blocked"  the filter hid part of it (text is the filtered string): ask for another name
--     status "failed"   the filter could not run (service down, Studio without API access): text = fallback

local TextService = game:GetService("TextService")

local Names = {}

function Names.filter(name: string, userId: number, fallback: string): (string, string)
	local ok, result = pcall(function(): string
		local filtered = TextService:FilterStringAsync(name, userId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" then
		warn("[ProfileService] name filter failed: " .. tostring(result))
		return fallback, "failed"
	end
	if result ~= name then
		return result, "blocked"
	end
	return result, "ok"
end

return Names
