local Shared = game:GetService("ReplicatedStorage").Shared
local DataUtil = require(Shared.Logic.DataUtil)
local Migrations = require(Shared.Logic.Migrations)
local TableUtil = require(Shared.Util.TableUtil)

local NOW = 1_800_000_000

return function(t)
	t.describe("getPath / setPath", function()
		local data = { campus = { offer = false, quests = { "a", "b" } }, career = { level = 3 } }
		t.it("reads nested values, including false and array indices", function()
			t.expect(DataUtil.getPath(data, "campus.offer")).toBe(false)
			t.expect(DataUtil.getPath(data, "career.level")).toBe(3)
			t.expect(DataUtil.getPath(data, "campus.quests.2")).toBe("b")
			t.expect(DataUtil.getPath(data, "campus")).toBe(data.campus)
		end)
		t.it("returns nil for missing paths and non-table intermediates", function()
			t.expect(DataUtil.getPath(data, "campus.nope.deeper")).toBeNil()
			t.expect(DataUtil.getPath(data, "career.level.x")).toBeNil()
			t.expect(DataUtil.getPath(nil, "a")).toBeNil()
		end)
		t.it("sets values, creating intermediates, and reports the top-level key", function()
			local d = { campus = { offer = false } }
			local ok, top = DataUtil.setPath(d, "campus.offer", true)
			t.expect(ok).toBe(true)
			t.expect(top).toBe("campus")
			t.expect(d.campus.offer).toBe(true)
			ok, top = DataUtil.setPath(d, "work.cooldowns.pitch", 30)
			t.expect(ok).toBe(true)
			t.expect(top).toBe("work")
			t.expect(d.work.cooldowns.pitch).toBe(30)
		end)
		t.it("keeps arrays as arrays", function()
			local d = { list = { "a" } }
			DataUtil.setPath(d, "list.2", "b")
			t.expect(d.list[2]).toBe("b")
			t.expect(#d.list).toBe(2)
			DataUtil.setPath(d, "list.1", "z")
			t.expect(d.list[1]).toBe("z")
		end)
		t.it("refuses empty paths and scalar intermediates", function()
			local d = { career = { level = 3 } }
			t.expect(DataUtil.setPath(d, "", 1)).toBe(false)
			t.expect(DataUtil.setPath(d, "career.level.x", 1)).toBe(false)
			t.expect(d.career.level).toBe(3)
		end)
	end)

	t.describe("filterPrivate", function()
		t.it("drops private keys and keeps everything else (shallow)", function()
			local data = { wallet = { cash = 1 }, receipts = { a = 1 }, audit = {}, _session = {}, meta = {} }
			local out = DataUtil.filterPrivate(data, { receipts = true, audit = true, _session = true })
			t.expect(out.receipts).toBeNil()
			t.expect(out.audit).toBeNil()
			t.expect(out._session).toBeNil()
			t.expect(out.wallet).toBe(data.wallet)
			t.expect(out.meta).toBe(data.meta)
			t.expect(data.receipts).never(nil)
		end)
	end)

	t.describe("applyTemplate", function()
		local template = {
			wallet = { cash = 0, earned = 0 },
			settings = { music = true, sfx = 0.8 },
			career = { level = 1, reviews = {}, history = {} },
			inventory = { owned = {}, presets = { "default" } },
		}
		t.it("fills missing keys deeply without overwriting existing values", function()
			local data = { wallet = { cash = 50 }, settings = { music = false } }
			DataUtil.applyTemplate(data, template)
			t.expect(data.wallet.cash).toBe(50)
			t.expect(data.wallet.earned).toBe(0)
			t.expect(data.settings.music).toBe(false)
			t.expect(data.settings.sfx).toBe(0.8)
			t.expect(data.career.level).toBe(1)
		end)
		t.it("copies defaults (no shared references with the template)", function()
			local data = {}
			DataUtil.applyTemplate(data, template)
			data.career.reviews[1] = "x"
			t.expect(#template.career.reviews).toBe(0)
		end)
		t.it("never descends into template arrays", function()
			local data = { inventory = { presets = { "mine" } } }
			DataUtil.applyTemplate(data, template)
			t.expect(data.inventory.presets).toEqual({ "mine" })
		end)
		t.it("resets a scalar where the template expects a table and reports it", function()
			local data = { wallet = 5, career = { level = 4, history = "broken" } }
			local _, repaired = DataUtil.applyTemplate(data, template)
			t.expect(data.wallet).toEqual({ cash = 0, earned = 0 })
			t.expect(data.career.history).toEqual({})
			t.expect(data.career.level).toBe(4)
			t.expect(repaired).toContain("wallet")
			t.expect(repaired).toContain("career.history")
		end)
		t.it("matches TableUtil.deepFill for well-formed data", function()
			local a = { wallet = { cash = 9 } }
			local b = TableUtil.deepCopy(a)
			DataUtil.applyTemplate(a, template)
			TableUtil.deepFill(b, template)
			t.expect(a).toEqual(b)
		end)
	end)

	t.describe("newProfile", function()
		t.it("is a deep copy of the template with meta stamped", function()
			local template = { meta = { schema = 0, createdAt = 0, sessions = 0 }, wallet = { cash = 0 } }
			local p = DataUtil.newProfile(template, NOW + 0.4, 1)
			t.expect(p.meta.createdAt).toBe(NOW)
			t.expect(p.meta.schema).toBe(1)
			t.expect(p.wallet).never(template.wallet)
			t.expect(template.meta.createdAt).toBe(0)
		end)
	end)

	t.describe("prepareLoaded", function()
		local template = {
			meta = {
				schema = 1,
				createdAt = 0,
				lastSeen = 0,
				sessions = 0,
				activeSec = 0,
				backupDay = -1,
				backupSlot = 0,
			},
			wallet = { cash = 0 },
			audit = {},
		}
		local opts = { transient = { _session = true }, backupSlots = 3 }
		t.it("creates a new profile when the record has no data", function()
			local p = DataUtil.prepareLoaded(nil, template, NOW, opts)
			t.expect(p.status).toBe("ok")
			t.expect(p.isNew).toBe(true)
			t.expect(p.data.meta.createdAt).toBe(NOW)
			t.expect(p.data.meta.sessions).toBe(1)
			t.expect(p.data.meta.schema).toBe(Migrations.CURRENT_SCHEMA)
			t.expect(type(p.data._session)).toBe("table")
			t.expect(p.backupSlot).toBeNil()
		end)
		t.it("migrates, fills, stamps meta and strips persisted transient keys", function()
			local raw = { sessions = 4, createdAt = 100, wallet = { cash = 7 }, _session = { stale = true } }
			local p = DataUtil.prepareLoaded(raw, template, NOW, opts)
			t.expect(p.status).toBe("ok")
			t.expect(p.isNew).toBe(false)
			t.expect(p.fromSchema).toBe(0)
			t.expect(p.data.meta.sessions).toBe(5)
			t.expect(p.data.meta.createdAt).toBe(100)
			t.expect(p.data.meta.lastSeen).toBe(NOW)
			t.expect(p.data.meta.activeSec).toBe(0)
			t.expect(p.data.wallet.cash).toBe(7)
			t.expect(p.data._session.stale).toBeNil()
		end)
		t.it("schedules today's backup with an untouched copy of the save", function()
			local raw = { meta = { schema = 1, sessions = 2, backupDay = 1, backupSlot = 3 }, wallet = { cash = 1 } }
			local p = DataUtil.prepareLoaded(raw, template, NOW, opts)
			t.expect(p.backupSlot).toBe(1)
			t.expect(p.backupSnapshot.meta.sessions).toBe(2)
			t.expect(p.backupSnapshot.audit).toBeNil() -- copied before the template fill
			t.expect(p.backupSnapshot).never(p.data)
			local today = DataUtil.utcDay(NOW)
			raw = { meta = { schema = 1, backupDay = today, backupSlot = 1 } }
			t.expect(DataUtil.prepareLoaded(raw, template, NOW, opts).backupSlot).toBeNil()
		end)
		t.it("reports future and failed migrations without touching the input", function()
			local future = { meta = { schema = 50 } }
			local p = DataUtil.prepareLoaded(future, template, NOW, opts)
			t.expect(p.status).toBe("future")
			t.expect(p.data).toBeNil()
			t.expect(future.wallet).toBeNil()
			local broken = DataUtil.prepareLoaded({ x = 1 }, template, NOW, {
				steps = {
					[0] = function()
						error("bad step")
					end,
				},
				schema = 1,
			})
			t.expect(broken.status).toBe("error")
			t.expect(broken.err).toContain("bad step")
		end)
	end)

	t.describe("toSaveable", function()
		t.it("copies clean data unchanged", function()
			local data = { a = 1, b = "x", c = true, list = { 1, 2, 3 }, nested = { d = { e = 0 } }, empty = {} }
			local out, issues = DataUtil.toSaveable(data)
			t.expect(#issues).toBe(0)
			t.expect(out).toEqual(data)
			t.expect(out.nested).never(data.nested)
		end)
		t.it("drops unsaveable values and reports their paths", function()
			local data = {
				nan = 0 / 0,
				inf = math.huge,
				fn = function() end,
				vec = Vector3.new(1, 2, 3),
				bad = "\255\254",
				list = { 1, 0 / 0, 3 },
				ok = 5,
			}
			local out, issues = DataUtil.toSaveable(data)
			t.expect(out.ok).toBe(5)
			t.expect(out.nan).toBeNil()
			t.expect(out.inf).toBeNil()
			t.expect(out.fn).toBeNil()
			t.expect(out.vec).toBeNil()
			t.expect(out.bad).toBeNil()
			t.expect(out.list).toEqual({ 1, 3 })
			local paths = {}
			for _, issue in issues do
				paths[issue.path] = issue.reason
			end
			t.expect(paths.nan).toBe("non-finite number")
			t.expect(paths["list.2"]).toBe("non-finite number")
			t.expect(paths.fn).toContain("unsupported")
			t.expect(paths.bad).toContain("UTF-8")
		end)
		t.it("turns numeric keys of sparse or mixed tables into strings", function()
			local out, issues = DataUtil.toSaveable({ sparse = { [1] = "a", [5] = "b" }, mixed = { 1, x = 2 } })
			t.expect(out.sparse["1"]).toBe("a")
			t.expect(out.sparse["5"]).toBe("b")
			t.expect(out.mixed["1"]).toBe(1)
			t.expect(out.mixed.x).toBe(2)
			t.expect(#issues).toBe(2)
		end)
		t.it("breaks reference cycles but allows shared (non-cyclic) references", function()
			local shared = { v = 1 }
			local data = { a = shared, b = shared }
			data.self = data
			local out, issues = DataUtil.toSaveable(data)
			t.expect(out.a.v).toBe(1)
			t.expect(out.b.v).toBe(1)
			t.expect(out.self).toBeNil()
			t.expect(#issues).toBe(1)
			t.expect(issues[1].reason).toBe("reference cycle")
		end)
		t.it("skips transient top-level keys only at the top level", function()
			local out = DataUtil.toSaveable({ _session = { x = 1 }, keep = { _session = 2 } }, { _session = true })
			t.expect(out._session).toBeNil()
			t.expect(out.keep._session).toBe(2)
		end)
	end)

	t.describe("estimateSize", function()
		t.it("matches hand-computed JSON lengths", function()
			t.expect(DataUtil.estimateSize({})).toBe(2) -- {}
			t.expect(DataUtil.estimateSize({ 1, 2, 3 })).toBe(7) -- [1,2,3]
			t.expect(DataUtil.estimateSize({ a = 1 })).toBe(7) -- {"a":1}
			t.expect(DataUtil.estimateSize("hi")).toBe(4) -- "hi"
			t.expect(DataUtil.estimateSize('a"b')).toBe(6) -- "a\"b"
			t.expect(DataUtil.estimateSize("a\nb")).toBe(6) -- "a\nb"
			t.expect(DataUtil.estimateSize("\1")).toBe(8) -- "\u0001"
			t.expect(DataUtil.estimateSize(true)).toBe(4)
			t.expect(DataUtil.estimateSize(false)).toBe(5)
			t.expect(DataUtil.estimateSize(-12)).toBe(3)
			t.expect(DataUtil.estimateSize(1.5)).toBe(3)
			t.expect(DataUtil.estimateSize({ a = { 1, true }, b = "x" })).toBe(#'{"a":[1,true],"b":"x"}')
			t.expect(DataUtil.estimateSize({ [1] = "a", [3] = "b" })).toBe(#'{"1":"a","3":"b"}')
		end)
		t.it("scales linearly for big profiles", function()
			local trades = {}
			for i = 1, 1000 do
				trades[i] = { id = "t" .. i, qty = i }
			end
			local size = DataUtil.estimateSize({ trades = trades })
			t.expect(size).toBeGreaterThan(20000)
			t.expect(size).toBeLessThan(40000)
		end)
	end)

	t.describe("pushRing", function()
		t.it("keeps only the newest entries", function()
			local ring = {}
			for i = 1, 105 do
				DataUtil.pushRing(ring, { t = i }, 100)
			end
			t.expect(#ring).toBe(100)
			t.expect(ring[1].t).toBe(6)
			t.expect(ring[100].t).toBe(105)
		end)
		t.it("trims an over-full list down in one push", function()
			local ring = {}
			for i = 1, 250 do
				ring[i] = i
			end
			DataUtil.pushRing(ring, 251, 200)
			t.expect(#ring).toBe(200)
			t.expect(ring[1]).toBe(52)
			t.expect(ring[200]).toBe(251)
		end)
	end)

	t.describe("compact", function()
		t.it("bounds depth, keys and string length and stringifies unsaveable values", function()
			local long = string.rep("x", 500)
			local out = DataUtil.compact({
				s = long,
				deep = { a = { b = { c = 1 } } },
				nan = 0 / 0,
				v = Vector3.new(1, 2, 3),
				list = { 1, 2, 3 },
			})
			t.expect(#out.s).toBe(203)
			t.expect(out.deep.a.b).toBe("{...}")
			t.expect(out.nan).toBe(tostring(0 / 0))
			t.expect(type(out.v)).toBe("string")
			t.expect(out.list).toEqual({ 1, 2, 3 })
			local many = {}
			for i = 1, 40 do
				many["k" .. i] = i
			end
			local c = DataUtil.compact(many)
			t.expect(TableUtil.count(c)).toBe(17) -- 16 keys + _more
			t.expect(c._more).toBe(true)
			t.expect(DataUtil.compact(nil)).toBeNil()
		end)
		t.it("produces something toSaveable accepts without issues", function()
			local out = DataUtil.compact({ a = { [1] = 1, [3] = 3 }, b = function() end, c = { 1, 2 } })
			local _, issues = DataUtil.toSaveable(out)
			t.expect(#issues).toBe(0)
		end)
	end)

	t.describe("backoff / utcDay / backupSlotDue", function()
		t.it("backs off exponentially with a cap", function()
			t.expect(DataUtil.backoff(1)).toBe(1)
			t.expect(DataUtil.backoff(2)).toBe(2)
			t.expect(DataUtil.backoff(4)).toBe(8)
			t.expect(DataUtil.backoff(10, 1, 8)).toBe(8)
			t.expect(DataUtil.backoff(2, 0.5)).toBe(1)
		end)
		t.it("computes UTC days", function()
			t.expect(DataUtil.utcDay(0)).toBe(0)
			t.expect(DataUtil.utcDay(86399)).toBe(0)
			t.expect(DataUtil.utcDay(86400)).toBe(1)
		end)
		t.it("rotates slots 1..3 at most once per day", function()
			t.expect(DataUtil.backupSlotDue(nil, 10, 3)).toBe(1)
			t.expect(DataUtil.backupSlotDue({ backupDay = -1, backupSlot = 0 }, 10, 3)).toBe(1)
			t.expect(DataUtil.backupSlotDue({ backupDay = 9, backupSlot = 1 }, 10, 3)).toBe(2)
			t.expect(DataUtil.backupSlotDue({ backupDay = 9, backupSlot = 3 }, 10, 3)).toBe(1)
			t.expect(DataUtil.backupSlotDue({ backupDay = 10, backupSlot = 2 }, 10, 3)).toBeNil()
			t.expect(DataUtil.backupSlotDue({ backupDay = 9, backupSlot = 77 }, 10, 3)).toBe(1)
		end)
	end)

	t.describe("backupRecord / backupSummary", function()
		t.it("summarises a stored backup for support", function()
			local data = {
				meta = { schema = 1, sessions = 8 },
				career = { level = 12, roleId = "analyst" },
				wallet = { cash = 300 },
			}
			local rec = DataUtil.backupRecord(data, NOW + 0.5, 2)
			t.expect(rec.savedAt).toBe(NOW)
			t.expect(rec.day).toBe(DataUtil.utcDay(NOW))
			t.expect(rec.schema).toBe(1)
			t.expect(rec.reason).toBe("daily")
			local sum = DataUtil.backupSummary(2, rec)
			t.expect(sum.slot).toBe(2)
			t.expect(sum.level).toBe(12)
			t.expect(sum.roleId).toBe("analyst")
			t.expect(sum.cash).toBe(300)
			t.expect(sum.sessions).toBe(8)
			t.expect(sum.bytes).toBeGreaterThan(10)
		end)
		t.it("returns nil for empty or malformed slots", function()
			t.expect(DataUtil.backupSummary(1, nil)).toBeNil()
			t.expect(DataUtil.backupSummary(1, { data = 5 })).toBeNil()
			t.expect(DataUtil.backupSummary(1, { data = {} }).level).toBeNil()
		end)
	end)
end
