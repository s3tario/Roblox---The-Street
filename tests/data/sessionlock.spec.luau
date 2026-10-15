local Shared = game:GetService("ReplicatedStorage").Shared
local SessionLock = require(Shared.Logic.SessionLock)
local TableUtil = require(Shared.Util.TableUtil)

local NOW = 1_800_000_000

-- A fake DataStore key-value map that behaves like UpdateAsync: the transform sees a copy of the stored
-- value, returning nil cancels, and stored values never share references with the caller.
local function newStore()
	local values = {}
	local store = {}
	function store.update(key, transform)
		local out = transform(TableUtil.deepCopy(values[key]))
		if out ~= nil then
			values[key] = TableUtil.deepCopy(out)
		end
		return out
	end
	function store.get(key)
		return TableUtil.deepCopy(values[key])
	end
	function store.set(key, v)
		values[key] = TableUtil.deepCopy(v)
	end
	return store
end

-- Minimal model of one server's session using only SessionLock transforms.
local function server(store, jobId)
	local self = { jobId = jobId, writeId = 0, data = nil, dead = nil }
	function self.load(key, now)
		local decision, reason, rec
		store.update(key, function(raw)
			local d, r, out = SessionLock.acquire(raw, now, jobId, 1)
			decision, reason, rec = d, r, out
			return out
		end)
		if rec then
			self.writeId = rec.writeId
			self.data = rec.data or { coins = 0 }
		end
		return decision, reason
	end
	function self.save(key, now, release, uncertain)
		local status, rec
		store.update(key, function(raw)
			local st, out = SessionLock.write(raw, now, jobId, 1, self.writeId, self.data, release, uncertain)
			status, rec = st, out
			return out
		end)
		if status == "ok" then
			self.writeId = rec.writeId
		else
			self.dead = status
		end
		return status
	end
	return self
end

return function(t)
	t.describe("SessionLock.decide", function()
		t.it("acquires a missing record or one without a session", function()
			t.expect(SessionLock.decide(nil, NOW, "A")).toBe("acquire")
			local d, r = SessionLock.decide({ data = { x = 1 }, writeId = 3 }, NOW, "A")
			t.expect(d).toBe("acquire")
			t.expect(r).toBe("free")
		end)
		t.it("re-acquires its own lock", function()
			local rec = { data = {}, session = { jobId = "A", placeId = 1, lockedAt = NOW - 5 }, writeId = 2 }
			local d, r = SessionLock.decide(rec, NOW, "A")
			t.expect(d).toBe("acquire")
			t.expect(r).toBe("own")
		end)
		t.it("waits on a live lock held by another job", function()
			local rec = { data = {}, session = { jobId = "B", placeId = 1, lockedAt = NOW - 30 }, writeId = 2 }
			local d, r = SessionLock.decide(rec, NOW, "A")
			t.expect(d).toBe("wait")
			t.expect(r).toBe("held")
			-- exactly at the threshold it is still live
			rec.session.lockedAt = NOW - SessionLock.STALE_AFTER
			t.expect(SessionLock.decide(rec, NOW, "A")).toBe("wait")
		end)
		t.it("steals a lock older than 600 s", function()
			local rec = { data = {}, session = { jobId = "B", placeId = 1, lockedAt = NOW - 601 }, writeId = 2 }
			local d, r = SessionLock.decide(rec, NOW, "A")
			t.expect(d).toBe("steal")
			t.expect(r).toBe("stale")
		end)
		t.it("steals a lock stamped absurdly far in the future (corrupt) but tolerates clock skew", function()
			local rec = { data = {}, session = { jobId = "B", placeId = 1, lockedAt = NOW + 5000 }, writeId = 2 }
			local d, r = SessionLock.decide(rec, NOW, "A")
			t.expect(d).toBe("steal")
			t.expect(r).toBe("corrupt")
			rec.session.lockedAt = NOW + 20
			t.expect(SessionLock.decide(rec, NOW, "A")).toBe("wait")
		end)
		t.it("takes over a live lock whose jobId has the steal prefix (Studio)", function()
			local rec = { data = {}, session = { jobId = "studio-old", placeId = 1, lockedAt = NOW - 5 }, writeId = 2 }
			local d, r = SessionLock.decide(rec, NOW, "studio-new", "studio-")
			t.expect(d).toBe("steal")
			t.expect(r).toBe("prefix")
			-- without the prefix, or for a live server's job, it still waits
			t.expect(SessionLock.decide(rec, NOW, "studio-new")).toBe("wait")
			rec.session.jobId = "8f2c-live-job"
			t.expect(SessionLock.decide(rec, NOW, "studio-new", "studio-")).toBe("wait")
			t.expect(SessionLock.heldElsewhere(rec, NOW, "studio-new", "studio-")).toBe(true)
		end)
		t.it("treats a malformed session as free", function()
			local rec = { data = {}, session = { jobId = 7 }, writeId = 2 }
			t.expect(SessionLock.decide(rec, NOW, "A")).toBe("acquire")
		end)
	end)

	t.describe("SessionLock.normalize", function()
		t.it("adopts a bare legacy profile as data", function()
			local rec = SessionLock.normalize({ wallet = { cash = 5 } })
			t.expect(rec.data.wallet.cash).toBe(5)
			t.expect(rec.writeId).toBe(0)
			t.expect(rec.session).toBeNil()
		end)
		t.it("returns nil for an empty key and drops garbage", function()
			t.expect(SessionLock.normalize(nil)).toBeNil()
			t.expect(SessionLock.normalize("junk").data).toBeNil()
			t.expect(SessionLock.normalize({}).data).toBeNil()
		end)
	end)

	t.describe("SessionLock.retryDelay", function()
		t.it("allows 6 attempts over about 20 seconds", function()
			local total, attempts = 0, 1
			while SessionLock.retryDelay(attempts) do
				total += SessionLock.retryDelay(attempts)
				attempts += 1
			end
			t.expect(attempts).toBe(SessionLock.MAX_ATTEMPTS)
			t.expect(attempts).toBe(6)
			t.expect(total).toBeBetween(15, 25)
		end)
	end)

	t.describe("SessionLock.acquire", function()
		t.it("stamps the session, keeps data and bumps writeId", function()
			local d, _, rec = SessionLock.acquire({ data = { a = 1 }, writeId = 4 }, NOW + 0.7, "A", 99)
			t.expect(d).toBe("acquire")
			t.expect(rec.data.a).toBe(1)
			t.expect(rec.writeId).toBe(5)
			t.expect(rec.session.jobId).toBe("A")
			t.expect(rec.session.placeId).toBe(99)
			t.expect(rec.session.lockedAt).toBe(NOW)
		end)
		t.it("cancels (nil record) when it must wait", function()
			local raw = { data = {}, session = { jobId = "B", placeId = 1, lockedAt = NOW }, writeId = 1 }
			local d, _, rec = SessionLock.acquire(raw, NOW, "A", 1)
			t.expect(d).toBe("wait")
			t.expect(rec).toBeNil()
		end)
	end)

	t.describe("SessionLock.checkWrite / write", function()
		local function held(jobId, writeId)
			return { data = { v = 1 }, session = { jobId = jobId, placeId = 1, lockedAt = NOW }, writeId = writeId }
		end
		t.it("allows the holder with the expected writeId", function()
			t.expect(SessionLock.checkWrite(held("A", 3), "A", 3)).toBe("ok")
		end)
		t.it("accepts our own previous attempt that committed despite an error (only when uncertain)", function()
			t.expect(SessionLock.checkWrite(held("A", 4), "A", 3, true)).toBe("ok")
			t.expect(SessionLock.checkWrite(held("A", 4), "A", 3, false)).toBe("conflict")
			local st, rec = SessionLock.write(held("A", 4), NOW, "A", 1, 3, { v = 9 }, false, true)
			t.expect(st).toBe("ok")
			t.expect(rec.writeId).toBe(4)
		end)
		t.it("rejects other holders, released locks, broken chains and removed keys", function()
			t.expect(SessionLock.checkWrite(held("B", 3), "A", 3)).toBe("stolen")
			t.expect(SessionLock.checkWrite({ data = {}, writeId = 3 }, "A", 3)).toBe("stolen")
			t.expect(SessionLock.checkWrite(held("A", 9), "A", 3)).toBe("conflict")
			t.expect(SessionLock.checkWrite(held("A", 2), "A", 3)).toBe("conflict")
			t.expect(SessionLock.checkWrite(nil, "A", 3)).toBe("missing")
		end)
		t.it("write refreshes the heartbeat and bumps writeId", function()
			local st, rec = SessionLock.write(held("A", 3), NOW + 120, "A", 1, 3, { v = 2 }, false)
			t.expect(st).toBe("ok")
			t.expect(rec.data.v).toBe(2)
			t.expect(rec.writeId).toBe(4)
			t.expect(rec.session.lockedAt).toBe(NOW + 120)
		end)
		t.it("a nil payload keeps the stored data (heartbeat / release only)", function()
			local st, rec = SessionLock.write(held("A", 3), NOW, "A", 1, 3, nil, true)
			t.expect(st).toBe("ok")
			t.expect(rec.data.v).toBe(1)
			t.expect(rec.session).toBeNil()
		end)
		t.it("returns no record when refused", function()
			local st, rec = SessionLock.write(held("B", 3), NOW, "A", 1, 3, { v = 2 }, false)
			t.expect(st).toBe("stolen")
			t.expect(rec).toBeNil()
		end)
	end)

	t.describe("protocol simulation", function()
		t.it("a second server waits while the first holds the lock, then acquires after release", function()
			local store = newStore()
			local a, b = server(store, "A"), server(store, "B")
			t.expect(a.load("u_1", NOW)).toBe("acquire")
			a.data.coins = 50
			t.expect(a.save("u_1", NOW + 120)).toBe("ok")
			t.expect(b.load("u_1", NOW + 130)).toBe("wait")
			t.expect(a.save("u_1", NOW + 140, true)).toBe("ok")
			t.expect(b.load("u_1", NOW + 141)).toBe("acquire")
			t.expect(b.data.coins).toBe(50)
		end)
		t.it("a stale lock is stolen and the old holder can no longer write", function()
			local store = newStore()
			local a, b = server(store, "A"), server(store, "B")
			a.load("u_1", NOW)
			a.data.coins = 10
			a.save("u_1", NOW + 120)
			local d, r = b.load("u_1", NOW + 120 + 601)
			t.expect(d).toBe("steal")
			t.expect(r).toBe("stale")
			b.data.coins = 99
			t.expect(b.save("u_1", NOW + 800)).toBe("ok")
			-- server A wakes up and tries to save its old state
			a.data.coins = 11
			t.expect(a.save("u_1", NOW + 900)).toBe("stolen")
			t.expect(a.dead).toBe("stolen")
			t.expect(store.get("u_1").data.coins).toBe(99)
			-- even after B releases, A's chain is broken
			b.save("u_1", NOW + 901, true)
			t.expect(a.save("u_1", NOW + 902)).toBe("stolen")
			t.expect(store.get("u_1").data.coins).toBe(99)
		end)
		t.it("a rejoin on the same job continues the writeId chain", function()
			local store = newStore()
			local first = server(store, "A")
			first.load("u_1", NOW)
			first.save("u_1", NOW + 10, true)
			local second = server(store, "A")
			t.expect(second.load("u_1", NOW + 20)).toBe("acquire")
			t.expect(second.writeId).toBe(first.writeId + 1)
			-- the stale first session can't write over the second
			t.expect(first.save("u_1", NOW + 30)).toBe("conflict")
		end)
		t.it("a write that errored after committing is retried without a false conflict", function()
			local store = newStore()
			local a = server(store, "A")
			a.load("u_1", NOW)
			a.data.coins = 5
			-- the first attempt commits, but the server never hears back
			local committedId = a.writeId
			store.update("u_1", function(raw)
				local _, out = SessionLock.write(raw, NOW + 5, "A", 1, committedId, a.data, false)
				return out
			end)
			a.data.coins = 6
			t.expect(a.save("u_1", NOW + 10, false, true)).toBe("ok")
			t.expect(store.get("u_1").data.coins).toBe(6)
			t.expect(a.save("u_1", NOW + 20)).toBe("ok")
		end)
		t.it("a removed key is never recreated by a save", function()
			local store = newStore()
			local a = server(store, "A")
			a.load("u_1", NOW)
			store.set("u_1", nil)
			t.expect(a.save("u_1", NOW + 10)).toBe("missing")
			t.expect(store.get("u_1")).toBeNil()
		end)
	end)

	t.describe("SessionLock.restore", function()
		t.it("refuses while another server's live session holds the lock", function()
			local raw = { data = {}, session = { jobId = "B", placeId = 1, lockedAt = NOW }, writeId = 4 }
			local st, rec = SessionLock.restore(raw, NOW + 10, "A", { wallet = { cash = 1 } })
			t.expect(st).toBe("held")
			t.expect(rec).toBeNil()
		end)
		t.it("writes the backup released, keeps the current rotation, appends the note", function()
			local raw = {
				data = { meta = { backupDay = 500, backupSlot = 3 }, wallet = { cash = 0 } },
				session = nil,
				writeId = 7,
			}
			local backup = { meta = { backupDay = 498, backupSlot = 1, sessions = 4 }, wallet = { cash = 900 } }
			local note = { t = NOW, kind = "restore", d = { slot = 1 } }
			local st, rec = SessionLock.restore(raw, NOW, "A", backup, note, 100)
			t.expect(st).toBe("ok")
			t.expect(rec.session).toBeNil()
			t.expect(rec.writeId).toBe(8)
			t.expect(rec.data.wallet.cash).toBe(900)
			t.expect(rec.data.meta.backupDay).toBe(500)
			t.expect(rec.data.meta.backupSlot).toBe(3)
			t.expect(rec.data.meta.sessions).toBe(4)
			t.expect(rec.data.audit[1].kind).toBe("restore")
			-- the source backup table is not mutated
			t.expect(backup.audit).toBeNil()
			t.expect(backup.meta.backupDay).toBe(498)
		end)
		t.it("restores over a stale or own lock", function()
			local stale = { data = {}, session = { jobId = "B", placeId = 1, lockedAt = NOW - 700 }, writeId = 1 }
			t.expect(SessionLock.restore(stale, NOW, "A", {})).toBe("ok")
			local own = { data = {}, session = { jobId = "A", placeId = 1, lockedAt = NOW }, writeId = 1 }
			t.expect(SessionLock.restore(own, NOW, "A", {})).toBe("ok")
		end)
	end)
end
