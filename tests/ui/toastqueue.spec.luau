local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ToastQueue = require(Client.UI.Kit.ToastQueue)

local function types(events)
	local out = {}
	for _, e in events do
		table.insert(out, e.type)
	end
	return out
end

return function(t)
	t.describe("ToastQueue", function()
		t.it("shows up to maxVisible toasts and queues the rest", function()
			local q = ToastQueue.new({ maxVisible = 4, duration = 4 })
			for i = 1, 4 do
				t.expect(types(ToastQueue.push(q, "t" .. i, "info", 0))).toEqual({ "show" })
			end
			t.expect(#ToastQueue.push(q, "t5", "info", 0)).toBe(0)
			t.expect(#q.visible).toBe(4)
			t.expect(#q.queued).toBe(1)
		end)
		t.it("coalesces identical visible toasts into a counter", function()
			local q = ToastQueue.new({})
			ToastQueue.push(q, "+$50", "cash", 0)
			local ev = ToastQueue.push(q, "+$50", "cash", 1)
			t.expect(types(ev)).toEqual({ "update" })
			t.expect(ev[1].item.count).toBe(2)
			t.expect(ev[1].item.expiresAt).toBe(1 + q.duration)
			t.expect(ToastQueue.label(ev[1].item)).toBe("+$50  x2")
			-- a different kind is a different toast
			t.expect(types(ToastQueue.push(q, "+$50", "good", 1))).toEqual({ "show" })
			-- server-coalesced counts add up
			local ev2 = ToastQueue.push(q, "+$50", "cash", 2, { count = 3 })
			t.expect(ev2[1].item.count).toBe(5)
		end)
		t.it("coalesces identical queued toasts", function()
			local q = ToastQueue.new({ maxVisible = 1 })
			ToastQueue.push(q, "a", "info", 0)
			ToastQueue.push(q, "b", "info", 0)
			ToastQueue.push(q, "b", "info", 0)
			t.expect(#q.queued).toBe(1)
			t.expect(q.queued[1].count).toBe(2)
		end)
		t.it("expires toasts and promotes queued ones", function()
			local q = ToastQueue.new({ maxVisible = 2, duration = 4, backlogLinger = 1 })
			ToastQueue.push(q, "a", "info", 0)
			ToastQueue.push(q, "b", "info", 0.5)
			ToastQueue.push(q, "c", "info", 0.6) -- queued; hurries "a"
			t.expect(q.visible[1].expiresAt).toBe(1) -- shownAt 0 + backlogLinger
			local ev = ToastQueue.tick(q, 1)
			t.expect(types(ev)).toEqual({ "hide", "show" })
			t.expect(ev[1].item.text).toBe("a")
			t.expect(ev[2].item.text).toBe("c")
			t.expect(#q.queued).toBe(0)
			t.expect(#ToastQueue.tick(q, 2)).toBe(0)
			local late = ToastQueue.tick(q, 10)
			t.expect(types(late)).toEqual({ "hide", "hide" })
			t.expect(#q.visible).toBe(0)
		end)
		t.it("bounds the queue by dropping the oldest", function()
			local q = ToastQueue.new({ maxVisible = 1, maxQueued = 3 })
			for i = 1, 10 do
				ToastQueue.push(q, "m" .. i, "info", 0)
			end
			t.expect(#q.queued).toBe(3)
			t.expect(q.queued[1].text).toBe("m8")
			t.expect(q.dropped).toBe(6)
		end)
		t.it("dismiss hides one toast and promotes", function()
			local q = ToastQueue.new({ maxVisible = 1 })
			local first = ToastQueue.push(q, "a", "info", 0)[1].item
			ToastQueue.push(q, "b", "info", 0)
			local ev = ToastQueue.dismiss(q, first.id, 0.2)
			t.expect(types(ev)).toEqual({ "hide", "show" })
			t.expect(q.visible[1].text).toBe("b")
			t.expect(#ToastQueue.dismiss(q, 999, 0.3)).toBe(0) -- unknown id is a no-op (no promotion pending)
		end)
		t.it("clear hides everything", function()
			local q = ToastQueue.new({ maxVisible = 2 })
			ToastQueue.push(q, "a", "info", 0)
			ToastQueue.push(q, "b", "info", 0)
			ToastQueue.push(q, "c", "info", 0)
			t.expect(types(ToastQueue.clear(q))).toEqual({ "hide", "hide" })
			t.expect(#q.visible + #q.queued).toBe(0)
		end)
	end)
end
