local Shared = game:GetService("ReplicatedStorage").Shared
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local World = require(Shared.Config.World)
local Leveling = require(Shared.Logic.Leveling)
local Template = require(Shared.Config.DataTemplate.Career)

local IB_FIRMS = {
	"mg_freeman",
	"goldfield_saxe",
	"morrow_stanton",
	"merriweather_lynch",
	"evermoor",
	"lazaro_freres",
	"centerline",
	"harrow_williams",
	"blairmont",
	"houlton_lockey",
	"sterling_vance",
	"eastbridge_capital",
}

local TYPE_MULTS = {
	bulge = { 1.0, 1.2, 1.3, 3 },
	elite = { 1.15, 1.0, 1.4, 4 },
	middle = { 0.9, 0.9, 1.0, 3 },
	regional = { 0.8, 0.8, 0.8, 2 },
}

return function(t)
	t.describe("tracks", function()
		t.it("lists all 11 track ids, only IB available in milestone 1", function()
			t.expect(#Tracks.list).toBe(11)
			for i, id in { "ib", "st", "pe", "credit", "wm", "am", "er", "corpbank", "vc", "re", "corp" } do
				t.expect(Tracks.list[i].id).toBe(id)
				t.expect(type(Tracks.list[i].name)).toBe("string")
				t.expect(Tracks.list[i].available).toBe(id == "ib")
			end
		end)
		t.it("has the IB ladder with contiguous level bands from L9 to L100", function()
			local ib = Tracks.get("ib") :: Tracks.TrackDef
			local ids = { "ib_analyst", "ib_associate", "ib_vp", "ib_director", "ib_md" }
			local titles = { "Analyst", "Associate", "Vice President", "Director", "Managing Director" }
			t.expect(#ib.ladder).toBe(5)
			local expectFloor = Tracks.STUDENT.maxLevel + 1
			for rank, role in ib.ladder do
				t.expect(role.rank).toBe(rank)
				t.expect(role.roleId).toBe(ids[rank])
				t.expect(role.title).toBe(titles[rank])
				t.expect(role.minLevel).toBe(expectFloor)
				t.expect(role.maxLevel).toBeGreaterThan(role.minLevel)
				expectFloor = role.maxLevel + 1
				if rank > 1 then
					local prev = ib.ladder[rank - 1]
					t.expect(role.salary).toBeGreaterThan(prev.salary)
					t.expect(role.book).toBeGreaterThan(prev.book)
					t.expect(role.minOvr).toBeGreaterThanOrEqual(prev.minOvr)
				end
				if rank < #ib.ladder then
					t.expect((role.coreToPromote or 0) > 0).toBeTruthy()
				end
				t.expect(Tracks.role(role.roleId)).toBe(role)
			end
			t.expect(ib.ladder[5].maxLevel).toBe(100)
			t.expect(ib.ladder[1].book).toBe(250000)
			t.expect(ib.ladder[5].book).toBe(1000000)
		end)
		t.it("gates Managing Director behind a Rare+ school only", function()
			local ib = Tracks.get("ib") :: Tracks.TrackDef
			for rank = 1, 4 do
				t.expect(ib.ladder[rank].schoolGate).toBeNil()
			end
			t.expect(ib.ladder[5].schoolGate).toBe(3)
			t.expect(Tracks.tierName(3)).toBe("Rare")
		end)
		t.it("dress levels follow min(5, rank + 1)", function()
			local ib = Tracks.get("ib") :: Tracks.TrackDef
			t.expect(Tracks.dressLevelFor(ib.ladder[3])).toBe(4)
			t.expect(Tracks.dressLevelFor(ib.ladder[5])).toBe(5)
		end)
		t.it("roleForLevel maps levels to the ladder", function()
			t.expect((Tracks.roleForLevel("ib", 3) :: any).roleId).toBe("student")
			t.expect((Tracks.roleForLevel("ib", 30) :: any).roleId).toBe("ib_associate")
			t.expect((Tracks.roleForLevel("ib", 100) :: any).roleId).toBe("ib_md")
			t.expect(Tracks.roleForLevel("st", 30)).toBeNil()
		end)
		t.it("Leveling caps agree with the ladder", function()
			for _, role in (Tracks.get("ib") :: Tracks.TrackDef).ladder do
				t.expect(Leveling.capFor("ib", role.rank)).toBe(role.maxLevel)
			end
		end)
		t.it("text() substitutes placeholders and falls back to the key", function()
			t.expect(Tracks.text("level_up", { level = 12 })).toBe("Level 12!")
			t.expect(Tracks.text("no_such_key")).toBe("no_such_key")
			t.expect(Tracks.text("objective_report", { company = "MG Freeman" }))
				.toBe("Ride the subway downtown and find MG Freeman's tower on Bank Row.")
		end)
	end)

	t.describe("companies", function()
		t.it("contains every canonical company id", function()
			local ids = {
				"mg_freeman",
				"goldfield_saxe",
				"morrow_stanton",
				"merriweather_lynch",
				"evermoor",
				"lazaro_freres",
				"centerline",
				"harrow_williams",
				"blairmont",
				"houlton_lockey",
				"sterling_vance",
				"eastbridge_capital",
				"anaeio",
				"bluestone",
				"krk",
				"ironclad",
				"aresmont",
				"gray_heron",
				"bridgecrest",
				"citrine",
				"quantum_ridge",
				"lotus_wealth",
				"sequel",
				"a17z",
				"seedline",
				"brookfold",
				"keystone",
				"northwind",
				"applewood",
			}
			for _, id in ids do
				t.expect(Companies.get(id)).toBeTruthy()
			end
			t.expect(#Companies.list).toBe(#ids)
		end)
		t.it("the twelve IB firms hire for IB with the type multipliers and dress levels", function()
			local hiring = Companies.forTrack("ib")
			t.expect(#hiring).toBe(12)
			for _, id in IB_FIRMS do
				local c = Companies.get(id) :: Companies.CompanyDef
				t.expect(c.available).toBeTruthy()
				t.expect(table.concat(c.departments, ",")).toBe("ib")
				local m = TYPE_MULTS[c.type]
				t.expect(m).toBeTruthy()
				t.expect(c.payMult).toBe(m[1])
				t.expect(c.bookMult).toBe(m[2])
				t.expect(c.prestigeMult).toBe(m[3])
				t.expect(c.minOutfitLevel).toBe(m[4])
				t.expect(c.logo).toBe(id)
				t.expect(#c.culture).toBeGreaterThan(20)
				t.expect(#c.tagline).toBeGreaterThan(3)
				t.expect(type(c.bossNames.ib)).toBe("string")
				t.expect(Companies.hiring(id, "ib")).toBeTruthy()
				t.expect(typeof(c.colors.primary)).toBe("Color3")
			end
		end)
		t.it("has distinct primary colours and distinct bosses across the IB firms", function()
			local colours, bosses = {}, {}
			for _, id in IB_FIRMS do
				local c = Companies.get(id) :: Companies.CompanyDef
				t.expect(colours[c.hex.primary]).toBeNil()
				t.expect(bosses[c.bossNames.ib]).toBeNil()
				colours[c.hex.primary] = true
				bosses[c.bossNames.ib] = true
			end
		end)
		t.it("Sterling & Vance has the walk-on seat", function()
			local h = Companies.hiring("sterling_vance", "ib") :: Companies.HiringDef
			t.expect(h.walkOn).toBeTruthy()
		end)
		t.it("companies of later milestones are listed but not hiring", function()
			local c = Companies.get("bluestone") :: Companies.CompanyDef
			t.expect(c.available).toBeFalsy()
			t.expect(#c.departments).toBe(0)
			t.expect(Companies.hiring("bluestone", "pe")).toBeNil()
			t.expect(#c.plannedDepartments).toBeGreaterThan(0)
		end)
		t.it("every tower company exists", function()
			for _, tower in World.towers do
				if tower.company then
					t.expect(Companies.get(tower.company)).toBeTruthy()
				end
				for _, id in tower.picker or {} do
					t.expect(Companies.get(id)).toBeTruthy()
				end
			end
		end)
		t.it("bossName falls back politely", function()
			t.expect(Companies.bossName("mg_freeman", "ib")).toBe("Catherine Ashby")
			t.expect(Companies.bossName("nope", "ib")).toBe("your managing director")
		end)
	end)

	t.describe("data template", function()
		t.it("starts as a level 1 student", function()
			local c = Template.career
			t.expect(c.level).toBe(1)
			t.expect(c.rank).toBe(0)
			t.expect(c.status).toBe("student")
			t.expect(c.roleId).toBe("student")
			t.expect(c.reviewDue).toBe(false)
			t.expect(type(c.plaques)).toBe("table")
			t.expect(type(c.promotion.missing)).toBe("table")
		end)
	end)
end
