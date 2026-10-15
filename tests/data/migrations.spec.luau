local Shared = game:GetService("ReplicatedStorage").Shared
local Migrations = require(Shared.Logic.Migrations)
local TableUtil = require(Shared.Util.TableUtil)

return function(t)
	t.describe("Migrations.schemaOf", function()
		t.it("reads meta.schema and defaults to 0", function()
			t.expect(Migrations.schemaOf({ meta = { schema = 3 } })).toBe(3)
			t.expect(Migrations.schemaOf({})).toBe(0)
			t.expect(Migrations.schemaOf({ meta = { schema = "2" } })).toBe(0)
			t.expect(Migrations.schemaOf({ meta = { schema = 1.5 } })).toBe(0)
			t.expect(Migrations.schemaOf(nil)).toBe(0)
		end)
	end)

	t.describe("built-in migrations", function()
		t.it("has a step for every schema below CURRENT_SCHEMA", function()
			t.expect(Migrations.CURRENT_SCHEMA).toBe(1)
			for n = 0, Migrations.CURRENT_SCHEMA - 1 do
				t.expect(type(Migrations.steps[n])).toBe("function")
			end
		end)
		t.it("upgrades an unversioned (schema 0) profile", function()
			local old = {
				createdAt = 1700000000,
				sessions = 12,
				lastSeen = 1700005000,
				wallet = { cash = 42 },
				audit = {
					[1700000100] = { kind = "purchase", d = { id = "x" } },
					[1700000050] = { kind = "flag", d = {} },
				},
			}
			local out, from, status = Migrations.run(old)
			t.expect(status).toBe("ok")
			t.expect(from).toBe(0)
			t.expect(out.meta.schema).toBe(1)
			t.expect(out.meta.createdAt).toBe(1700000000)
			t.expect(out.meta.sessions).toBe(12)
			t.expect(out.meta.lastSeen).toBe(1700005000)
			t.expect(out.createdAt).toBeNil()
			t.expect(out.sessions).toBeNil()
			t.expect(out.wallet.cash).toBe(42)
			-- the audit map became an ordered list
			t.expect(#out.audit).toBe(2)
			t.expect(out.audit[1].kind).toBe("flag")
			t.expect(out.audit[1].t).toBe(1700000050)
			t.expect(out.audit[2].kind).toBe("purchase")
			-- the input was not touched
			t.expect(old.meta).toBeNil()
			t.expect(old.createdAt).toBe(1700000000)
		end)
		t.it("keeps an existing meta and a list-shaped audit log", function()
			local old = { meta = { createdAt = 5 }, createdAt = 9, audit = { { t = 1, kind = "a" } } }
			local out = Migrations.run(old)
			t.expect(out.meta.createdAt).toBe(5)
			t.expect(out.audit[1].kind).toBe("a")
		end)
		t.it("is idempotent: current data is returned unchanged (same table)", function()
			local cur = { meta = { schema = 1, sessions = 3 }, wallet = { cash = 1 } }
			local snapshot = TableUtil.deepCopy(cur)
			local out, from, status = Migrations.run(cur)
			t.expect(out).toBe(cur)
			t.expect(from).toBe(1)
			t.expect(status).toBe("ok")
			t.expect(cur).toEqual(snapshot)
			local again = Migrations.run((Migrations.run({ sessions = 2 })))
			t.expect(again.meta.schema).toBe(1)
			t.expect(again.meta.sessions).toBe(2)
		end)
		t.it("refuses to downgrade data written by a newer build", function()
			local future = { meta = { schema = 99 }, x = 1 }
			local out, from, status = Migrations.run(future)
			t.expect(status).toBe("future")
			t.expect(from).toBe(99)
			t.expect(out).toBe(future)
		end)
	end)

	t.describe("synthetic migration chains", function()
		local order
		local steps = {
			[0] = function(d)
				table.insert(order, 0)
				d.meta = d.meta or {}
				d.name = d.name or "anon"
			end,
			[1] = function(d)
				table.insert(order, 1)
				d.cash = { amount = d.cash or 0 }
			end,
			[2] = function(d)
				table.insert(order, 2)
				d.cash.currency = "usd"
			end,
		}
		t.it("runs every step from n to n+1 in order and stamps the schema", function()
			order = {}
			local out, from, status = Migrations.run({ cash = 7 }, steps, 3)
			t.expect(status).toBe("ok")
			t.expect(from).toBe(0)
			t.expect(order).toEqual({ 0, 1, 2 })
			t.expect(out.meta.schema).toBe(3)
			t.expect(out.name).toBe("anon")
			t.expect(out.cash).toEqual({ amount = 7, currency = "usd" })
		end)
		t.it("starts from the stored schema", function()
			order = {}
			local out = Migrations.run({ meta = { schema = 2 }, cash = { amount = 1 } }, steps, 3)
			t.expect(order).toEqual({ 2 })
			t.expect(out.cash.currency).toBe("usd")
		end)
		t.it("a second run of migrated data does nothing", function()
			order = {}
			local out = Migrations.run({ cash = 1 }, steps, 3)
			order = {}
			local again = Migrations.run(out, steps, 3)
			t.expect(#order).toBe(0)
			t.expect(again).toBe(out)
		end)
		t.it("a failing step leaves the input untouched and reports the error", function()
			local bad = {
				[0] = function(d)
					d.touched = true
				end,
				[1] = function(_d)
					error("boom")
				end,
			}
			local input = { x = 1 }
			local out, from, status, err = Migrations.run(input, bad, 2)
			t.expect(status).toBe("error")
			t.expect(from).toBe(0)
			t.expect(out).toBe(input)
			t.expect(input.touched).toBeNil()
			t.expect(err).toContain("boom")
		end)
		t.it("a missing step is an error, not a silent skip", function()
			local _, _, status, err = Migrations.run({}, { [0] = function() end }, 2)
			t.expect(status).toBe("error")
			t.expect(err).toContain("schema 1")
		end)
	end)
end
