local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Rng = require(Shared.Util.Rng)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)

local COMPANIES = {
	{
		id = "mg_freeman",
		name = "MG Freeman",
		short = "MGF",
		type = "bank",
		tier = "bulge",
		departments = { "ib", "st", "wm", "er", "corpbank", "credit" },
		colors = { primary = "#0B2A4A", accent = Color3.fromRGB(201, 165, 76) },
		bossNames = { ib = "Harold Quill" },
	},
	{
		id = "anaeio",
		name = "Anaeio",
		type = "asset_management",
		departments = { "am", "wm", "credit" },
		colors = { primary = "#101010" },
	},
	{ id = "harrow_williams", name = "Harrow Williams", tier = "middle_market", departments = { "ib" } },
	{ id = "goldfield_saxe", name = "Goldfield Saxe", tier = "bulge", departments = { "ib", "st" }, available = false },
}

local TEMPLATES = { lobby = true, ib = true, st = true }

return function(t)
	t.describe("OfficeAlloc instance slots", function()
		t.it("hands out the lowest free index and keeps it per company", function()
			local a = OfficeAlloc.new(3)
			t.expect(OfficeAlloc.acquire(a, "mg_freeman")).toBe(1)
			t.expect(OfficeAlloc.acquire(a, "anaeio")).toBe(2)
			t.expect(OfficeAlloc.acquire(a, "mg_freeman")).toBe(1)
			t.expect(OfficeAlloc.indexOf(a, "anaeio")).toBe(2)
			t.expect(OfficeAlloc.companyAt(a, 1)).toBe("mg_freeman")
			t.expect(OfficeAlloc.count(a)).toBe(2)
		end)
		t.it("reuses freed indices and refuses when full", function()
			local a = OfficeAlloc.new(3)
			OfficeAlloc.acquire(a, "a")
			OfficeAlloc.acquire(a, "b")
			OfficeAlloc.acquire(a, "c")
			t.expect(OfficeAlloc.acquire(a, "d")).toBeNil()
			t.expect(OfficeAlloc.release(a, "b")).toBe(2)
			t.expect(OfficeAlloc.release(a, "b")).toBeNil()
			t.expect(OfficeAlloc.companyAt(a, 2)).toBeNil()
			t.expect(OfficeAlloc.acquire(a, "d")).toBe(2)
			t.expect(OfficeAlloc.release(a, "a")).toBe(1)
			t.expect(OfficeAlloc.acquire(a, "e")).toBe(1)
			t.expect(OfficeAlloc.count(a)).toBe(3)
		end)
		t.it("defaults to World.offices.maxInstances and every index fits the office grid", function()
			local a = OfficeAlloc.new()
			t.expect(a.max).toBe(World.offices.maxInstances)
			for i = 1, a.max do
				t.expect(OfficeAlloc.acquire(a, "c" .. i)).toBe(i)
				local origin = World.officeOrigin(i, World.offices.maxFloors - 1)
				local gi, gf = World.officeAt(origin)
				t.expect(gi).toBe(i)
				t.expect(gf).toBe(World.offices.maxFloors - 1)
			end
			t.expect(OfficeAlloc.acquire(a, "overflow")).toBeNil()
		end)
	end)

	t.describe("OfficeAlloc floors", function()
		local depts = { "ib", "st", "wm" }
		t.it("maps the lobby to 0 and departments to their 1-based order", function()
			t.expect(OfficeAlloc.floorIndex(depts, nil)).toBe(0)
			t.expect(OfficeAlloc.floorIndex(depts, "lobby")).toBe(0)
			t.expect(OfficeAlloc.floorIndex(depts, "ib")).toBe(1)
			t.expect(OfficeAlloc.floorIndex(depts, "wm")).toBe(3)
			t.expect(OfficeAlloc.floorIndex(depts, "pe")).toBeNil()
			t.expect(OfficeAlloc.floorAt(depts, 0)).toBe("lobby")
			t.expect(OfficeAlloc.floorAt(depts, 2)).toBe("st")
			t.expect(OfficeAlloc.floorAt(depts, 4)).toBeNil()
			t.expect(OfficeAlloc.floorAt(depts, -1)).toBeNil()
		end)
		t.it("never places a department beyond the last floor", function()
			local many = {}
			for i = 1, World.offices.maxFloors + 2 do
				table.insert(many, "d" .. i)
			end
			t.expect(OfficeAlloc.floorIndex(many, "d" .. (World.offices.maxFloors - 1))).toBe(World.offices.maxFloors - 1)
			t.expect(OfficeAlloc.floorIndex(many, "d" .. World.offices.maxFloors)).toBeNil()
		end)
		t.it("expires floors that stay empty for the TTL and keeps occupied ones", function()
			local floors = {
				["mg_freeman/lobby"] = OfficeAlloc.newFloor("mg_freeman", "lobby", 0),
				["mg_freeman/ib"] = OfficeAlloc.newFloor("mg_freeman", "ib", 0),
				["anaeio/lobby"] = OfficeAlloc.newFloor("anaeio", "lobby", 100),
			}
			t.expect(#OfficeAlloc.sweep(floors, {}, 150)).toBe(0)
			local gone = OfficeAlloc.sweep(floors, { ["mg_freeman/ib"] = true }, 181)
			t.expect(gone).toEqual({ "mg_freeman/lobby" })
			t.expect(floors["mg_freeman/ib"].lastOccupied).toBe(181)
			floors["mg_freeman/lobby"] = nil
			t.expect(OfficeAlloc.instanceEmpty(floors, "mg_freeman")).toBe(false)
			t.expect(#OfficeAlloc.sweep(floors, {}, 280)).toBe(0) -- ib was occupied at 181, anaeio created at 100
			t.expect(OfficeAlloc.sweep(floors, {}, 400)).toEqual({ "anaeio/lobby", "mg_freeman/ib" })
			floors["mg_freeman/ib"] = nil
			t.expect(OfficeAlloc.instanceEmpty(floors, "mg_freeman")).toBe(true)
			t.expect(OfficeAlloc.instanceEmpty(floors, "anaeio")).toBe(false)
		end)
		t.it("uses the default 3 minute TTL", function()
			local floors = { k = OfficeAlloc.newFloor("x", "lobby", 0) }
			t.expect(#OfficeAlloc.sweep(floors, {}, 180)).toBe(0)
			t.expect(#OfficeAlloc.sweep(floors, {}, 180.5)).toBe(1)
		end)
	end)

	t.describe("OfficeAlloc companies", function()
		t.it("normalizes a list module", function()
			local byId, list = OfficeAlloc.normalizeCompanies({ list = COMPANIES })
			t.expect(#list).toBe(4)
			t.expect(list[1].id).toBe("mg_freeman")
			local mgf = byId.mg_freeman
			t.expect(mgf.short).toBe("MGF")
			t.expect(mgf.tierLabel).toBe("Bulge Bracket")
			t.expect(mgf.primary).toEqual(Color3.fromRGB(11, 42, 74))
			t.expect(mgf.accent).toEqual(Color3.fromRGB(201, 165, 76))
			t.expect(mgf.logo).toBe("mg_freeman")
			t.expect(mgf.bossNames.ib).toBe("Harold Quill")
			t.expect(byId.anaeio.short).toBe("A")
			t.expect(byId.anaeio.tierLabel).toBe("Asset Management")
			t.expect(byId.goldfield_saxe.disabled).toBe(true)
		end)
		t.it("normalizes map, plain-list and get/ids modules alike", function()
			local map = { helpers = { foo = 1 }, tiers = { bulge = {} } }
			for _, c in COMPANIES do
				map[c.id] = c
			end
			local byMap = OfficeAlloc.normalizeCompanies(map)
			t.expect(byMap.mg_freeman ~= nil).toBeTruthy()
			t.expect(byMap.helpers).toBeNil()
			t.expect(byMap.tiers).toBeNil()
			local _, plain = OfficeAlloc.normalizeCompanies(COMPANIES)
			t.expect(#plain).toBe(4)
			local getter = {
				ids = { "anaeio", "missing" },
				get = function(id)
					for _, c in COMPANIES do
						if c.id == id then
							return c
						end
					end
					return nil
				end,
			}
			local _, viaGet = OfficeAlloc.normalizeCompanies(getter)
			t.expect(#viaGet).toBe(1)
			t.expect(viaGet[1].id).toBe("anaeio")
			local _, none = OfficeAlloc.normalizeCompanies(nil)
			t.expect(#none).toBe(0)
		end)
		t.it("normalizes tracks and names departments", function()
			local tracks = OfficeAlloc.normalizeTracks({
				list = {
					{ id = "ib", name = "Investment Banking", ladder = { { title = "Analyst" }, { title = "Managing Director" } } },
					{ id = "st", name = "Sales & Trading", enabled = false },
				},
			})
			t.expect(tracks.ib.topTitle).toBe("Managing Director")
			t.expect(tracks.st.disabled).toBe(true)
			t.expect(OfficeAlloc.departmentName("ib", tracks)).toBe("Investment Banking")
			t.expect(OfficeAlloc.departmentName("pe", tracks)).toBe("Private Equity") -- fallback text
			t.expect(OfficeAlloc.departmentName("zz", nil)).toBe("zz")
		end)
	end)

	t.describe("OfficeAlloc availability and directory", function()
		local byId, list = OfficeAlloc.normalizeCompanies({ list = COMPANIES })
		t.it("opens a company only with a lobby and at least one department floor", function()
			t.expect(OfficeAlloc.isAvailable(byId.mg_freeman, TEMPLATES)).toBe(true)
			t.expect(OfficeAlloc.isAvailable(byId.anaeio, TEMPLATES)).toBe(false)
			t.expect(OfficeAlloc.isAvailable(byId.goldfield_saxe, TEMPLATES)).toBe(false) -- disabled in config
			t.expect(OfficeAlloc.isAvailable(byId.mg_freeman, { ib = true })).toBe(false) -- no lobby template
			t.expect(OfficeAlloc.isAvailable(nil, TEMPLATES)).toBe(false)
		end)
		t.it("marks each department floor open or opening soon", function()
			local depts = OfficeAlloc.departments(byId.mg_freeman, TEMPLATES)
			t.expect(#depts).toBe(6)
			t.expect(depts[1].id).toBe("ib")
			t.expect(depts[1].floor).toBe(1)
			t.expect(depts[1].available).toBe(true)
			t.expect(depts[2].available).toBe(true)
			t.expect(depts[3].available).toBe(false)
			local tracks = OfficeAlloc.normalizeTracks({ { id = "st", name = "S&T", enabled = false } })
			t.expect(OfficeAlloc.departments(byId.mg_freeman, TEMPLATES, tracks)[2].available).toBe(false)
			t.expect(OfficeAlloc.floorOpen(byId.mg_freeman, "ib", TEMPLATES)).toBe(true)
			t.expect(OfficeAlloc.floorOpen(byId.mg_freeman, "wm", TEMPLATES)).toBe(false)
			t.expect(OfficeAlloc.floorOpen(byId.mg_freeman, "lobby", TEMPLATES)).toBe(true)
			t.expect(OfficeAlloc.floorOpen(byId.mg_freeman, "pe", TEMPLATES)).toBe(false)
		end)
		t.it("lists open firms first, in Street order", function()
			local entries = OfficeAlloc.directory(list, TEMPLATES)
			t.expect(#entries).toBe(4)
			t.expect(entries[1].id).toBe("mg_freeman")
			t.expect(entries[2].id).toBe("harrow_williams")
			t.expect(entries[1].available).toBe(true)
			t.expect(entries[3].available).toBe(false)
			t.expect(entries[3].id).toBe("goldfield_saxe") -- Bank Row comes before the Anaeio tower
			t.expect(entries[4].id).toBe("anaeio")
			local open = OfficeAlloc.filterOpen(entries, true)
			t.expect(#open).toBe(2)
			t.expect(#OfficeAlloc.filterOpen(entries, false)).toBe(4)
		end)
		t.it("filters a tower picker to its tenants in tower order, with placeholders", function()
			local entries = OfficeAlloc.directory(list, TEMPLATES)
			local tower = World.towers[11] -- Middle Market Plaza
			t.expect(tower.id).toBe("middle_market")
			local picked = OfficeAlloc.pickerEntries(entries, tower.picker :: { string })
			t.expect(#picked).toBe(4)
			t.expect(picked[1].id).toBe("harrow_williams")
			t.expect(picked[1].available).toBe(true)
			t.expect(picked[2].id).toBe("blairmont")
			t.expect(picked[2].placeholder).toBe(true)
			t.expect(picked[2].available).toBe(false)
			t.expect(picked[4].name).toBe("Eastbridge Capital")
			for _, e in picked do
				t.expect(e.id ~= "mg_freeman").toBeTruthy()
			end
			t.expect(#OfficeAlloc.pickerEntries(entries, { "harrow_williams", "harrow_williams" })).toBe(1)
		end)
	end)

	t.describe("OfficeAlloc coworkers", function()
		t.it("spawns 4-8 coworkers, 4 when the server is busy", function()
			local rng = Rng.new("coworkers")
			for _ = 1, 50 do
				t.expect(OfficeAlloc.coworkerCount(rng, 1)).toBeBetween(4, 8)
			end
			t.expect(OfficeAlloc.coworkerCount(rng, OfficeAlloc.BUSY_FLOORS)).toBe(4)
		end)
		t.it("picks distinct desks from the back half first, skipping taken ones", function()
			local rng = Rng.new("desks")
			local picks = OfficeAlloc.pickDesks(24, 8, rng, { [24] = true, [13] = true })
			t.expect(#picks).toBe(8)
			local seen = {}
			for _, i in picks do
				t.expect(seen[i]).toBeNil()
				seen[i] = true
				t.expect(i > 12).toBeTruthy()
				t.expect(i ~= 24 and i ~= 13).toBeTruthy()
			end
			t.expect(#OfficeAlloc.pickDesks(3, 8, rng)).toBe(3)
			t.expect(#OfficeAlloc.pickDesks(0, 8, rng)).toBe(0)
			-- deterministic for a seed
			local a = OfficeAlloc.pickDesks(24, 6, Rng.new("same"))
			local b = OfficeAlloc.pickDesks(24, 6, Rng.new("same"))
			t.expect(a).toEqual(b)
		end)
	end)
end
