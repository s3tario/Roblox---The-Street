local Server = game:GetService("ServerScriptService").Server
local Limiter = require(Server.Services.NotifyService.Limiter)
local TextClean = require(Server.Services.NotifyService.TextClean)

local function sendAll(st, key, from, to, step)
	local sent = 0
	local now = from
	while now <= to + 1e-9 do
		sent += #Limiter.offer(st, key, { now = now }, now)
		sent += #Limiter.drain(st, now)
		now += step
	end
	return sent
end

return function(t)
	t.describe("Notify limiter", function()
		t.it("allows max sends per window, then holds the rest", function()
			local st = Limiter.new({ max = 6, window = 2, dupWindow = 2, maxPending = 6 })
			local sent = 0
			for i = 1, 10 do
				sent += #Limiter.offer(st, "k" .. i, i, 0)
			end
			t.expect(sent).toBe(6)
			t.expect(Limiter.pendingCount(st)).toBe(4)
			t.expect(#Limiter.drain(st, 1)).toBe(0) -- still inside the window
			local later = Limiter.drain(st, 2.01)
			t.expect(#later).toBe(4)
			t.expect(later[1].payload).toBe(7) -- order preserved
		end)
		t.it("never exceeds 6 toasts in any 2 s window under spam", function()
			local st = Limiter.new({ max = 6, window = 2, dupWindow = 2, maxPending = 6 })
			local stamps = {}
			for i = 0, 400 do
				local now = i * 0.05
				for _, _e in Limiter.offer(st, "spam" .. i, i, now) do
					table.insert(stamps, now)
				end
				for _, _e in Limiter.drain(st, now) do
					table.insert(stamps, now)
				end
			end
			for i = 1, #stamps do
				local count = 0
				for j = i, #stamps do
					if stamps[j] - stamps[i] < 2 then
						count += 1
					end
				end
				t.expect(count).toBeLessThanOrEqual(6)
			end
			t.expect(st.dropped).toBeGreaterThan(0)
		end)
		t.it("coalesces duplicates into one delayed entry with a count", function()
			local st = Limiter.new({ max = 6, window = 2, dupWindow = 2 })
			t.expect(#Limiter.offer(st, "+$50", "a", 0)).toBe(1)
			t.expect(#Limiter.offer(st, "+$50", "b", 0.1)).toBe(0)
			t.expect(#Limiter.offer(st, "+$50", "c", 0.2)).toBe(0)
			t.expect(#Limiter.offer(st, "+$50", "d", 0.3)).toBe(0)
			t.expect(Limiter.pendingCount(st)).toBe(1)
			t.expect(#Limiter.drain(st, 1.5)).toBe(0) -- duplicate window not over yet
			local out = Limiter.drain(st, 2.0)
			t.expect(#out).toBe(1)
			t.expect(out[1].count).toBe(3)
			t.expect(out[1].payload).toBe("d") -- latest payload wins
		end)
		t.it("a steady duplicate stream sends at most once per duplicate window", function()
			local st = Limiter.new({ max = 6, window = 2, dupWindow = 2 })
			local sent = sendAll(st, "same", 0, 10, 0.1)
			t.expect(sent).toBeLessThanOrEqual(6)
			t.expect(sent).toBeGreaterThanOrEqual(5)
		end)
		t.it("bounds pending and counts drops", function()
			local st = Limiter.new({ max = 1, window = 10, dupWindow = 0, maxPending = 2 })
			for i = 1, 6 do
				Limiter.offer(st, "k" .. i, i, 0)
			end
			t.expect(Limiter.pendingCount(st)).toBe(2)
			t.expect(st.dropped).toBe(3)
		end)
		t.it("becomes idle again so state can be discarded", function()
			local st = Limiter.new({})
			Limiter.offer(st, "a", 1, 0)
			t.expect(Limiter.idle(st, 1)).toBe(false)
			t.expect(Limiter.idle(st, 5)).toBe(true)
		end)
	end)

	t.describe("Notify text cleaning", function()
		t.it("trims, strips control characters and accepts numbers", function()
			t.expect(TextClean.clean("  hi  ", 10)).toBe("hi")
			t.expect(TextClean.clean("a\0b\tc", 10)).toBe("a b c")
			t.expect(TextClean.clean("one\ntwo", 50, true)).toBe("one\ntwo")
			t.expect(TextClean.clean("one\ntwo", 50)).toBe("one two")
			t.expect(TextClean.clean(42, 10)).toBe("42")
		end)
		t.it("rejects empty and non-text values", function()
			t.expect(TextClean.clean("", 10)).toBeNil()
			t.expect(TextClean.clean("   ", 10)).toBeNil()
			t.expect(TextClean.clean({}, 10)).toBeNil()
			t.expect(TextClean.clean(nil, 10)).toBeNil()
		end)
		t.it("cuts on a UTF-8 boundary and drops invalid bytes", function()
			local cut = TextClean.clean(string.rep("é", 10), 5) :: string
			t.expect(#cut).toBe(4)
			t.expect(utf8.len(cut)).toBe(2)
			t.expect(TextClean.clean("\255\254ok", 10)).toBe("ok")
		end)
	end)
end
