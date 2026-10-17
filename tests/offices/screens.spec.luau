-- Directory and Elevator screens: their pure view models plus a smoke test of each screen under Lune.
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Text = require(Shared.Logic.DoorRules).Text
-- Loaded up front: the screens require Logos lazily, and a first require can yield under Lune's loader.
local _Logos = require(Shared.Assets.Logos)
local Directory = require(Client.UI.Screens.Directory)
local Elevator = require(Client.UI.Screens.Elevator)

local COMPANIES = {
	{ id = "mg_freeman", name = "MG Freeman", type = "bulge", departments = { "ib" }, tagline = "Capital, at scale." },
	{ id = "harrow_williams", name = "Harrow Williams", type = "middle", departments = { "ib" } },
	{ id = "anaeio", name = "Anaeio", type = "asset", available = false, plannedDepartments = { "am", "wm" } },
}
local TEMPLATES = { lobby = true, ib = true }
local _, LIST = OfficeAlloc.normalizeCompanies(COMPANIES)
local ENTRIES = OfficeAlloc.directory(LIST, TEMPLATES)

local function fakeApi(entries: any)
	local api = { entered = {}, rode = {} }
	function api:GetDirectory()
		return entries, nil
	end
	function api:GetCompanyId()
		return "mg_freeman"
	end
	function api:IsEmployeeOf(id)
		return id == "mg_freeman"
	end
	function api:Enter(id)
		table.insert(self.entered, id)
		return false, "Nope"
	end
	function api:Ride(floor)
		table.insert(self.rode, floor)
		return true, nil
	end
	return api
end

local function ctxFor(api: any)
	local notes = {}
	local closed = { n = 0 }
	return {
		Registry = {
			get = function(name: string)
				return if name == "OfficeController" then api else nil
			end,
		},
		UI = {
			Notify = function(_self, text)
				table.insert(notes, text)
			end,
		},
		close = function()
			closed.n += 1
		end,
	},
		notes,
		closed
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function count(root: Instance, prefix: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

return function(t)
	t.describe("Directory view model", function()
		t.it("shows open firms on the Open tab and everything on All", function()
			local open = Directory.rows(ENTRIES, { tab = "open", ownCompany = "mg_freeman" })
			t.expect(#open).toBe(2)
			t.expect(open[1].id).toBe("mg_freeman")
			t.expect(open[1].own).toBe(true)
			t.expect(open[1].departments).toBe("Investment Banking")
			t.expect(open[1].meta).toBe("Bulge Bracket")
			t.expect(open[2].own).toBe(false)
			local all = Directory.rows(ENTRIES, { tab = "all" })
			t.expect(#all).toBe(3)
			t.expect(all[3].id).toBe("anaeio")
			t.expect(all[3].available).toBe(false)
			t.expect(all[3].status).toBe(Text.get("opening_soon"))
			t.expect(all[3].departments).toBe("Asset Management · Wealth Management")
		end)
		t.it("filters a tower picker to its tenants, greying unknown ones", function()
			local tower = World.towers[11]
			local rows = Directory.rows(ENTRIES, { tenants = tower.picker })
			t.expect(#rows).toBe(#(tower.picker :: { string }))
			t.expect(rows[1].id).toBe("harrow_williams")
			t.expect(rows[1].available).toBe(true)
			for i = 2, #rows do
				t.expect(rows[i].available).toBe(false)
				t.expect(rows[i].status).toBe(Text.get("opening_soon"))
			end
		end)
	end)

	t.describe("Directory screen", function()
		t.it("renders a card per firm with Visit buttons only for open firms", function()
			local root = Instance.new("Frame")
			local api = fakeApi(ENTRIES)
			local ctx, notes = ctxFor(api)
			local handle = Directory.open({ source = "kiosk" }, root, ctx)
			t.expect(count(root, "Firm_")).toBe(2)
			t.expect(find(root, "Firm_mg_freeman") ~= nil).toBeTruthy()
			t.expect(find(root, "Visit") ~= nil).toBeTruthy()
			t.expect(find(root, "Own") ~= nil).toBeTruthy()
			handle.close()
			t.expect(#notes).toBe(0)
		end)
		t.it("opens a tower picker with only that tower's tenants", function()
			local root = Instance.new("Frame")
			local tower = World.towers[11]
			local ctx = ctxFor(fakeApi(ENTRIES))
			local handle = Directory.open({ source = "tower", title = tower.label, tenants = tower.picker }, root, ctx)
			t.expect(count(root, "Firm_")).toBe(#(tower.picker :: { string }))
			t.expect(find(root, "Firm_mg_freeman")).toBeNil()
			t.expect(find(root, "Soon") ~= nil).toBeTruthy()
			t.expect(find(root, "Tabs")).toBeNil()
			handle.close()
		end)
		t.it("shows an error with a retry when the directory can't load", function()
			local root = Instance.new("Frame")
			local handle = Directory.open({}, root, ctxFor(fakeApi(nil)))
			t.expect(find(root, "Retry") ~= nil).toBeTruthy()
			t.expect(count(root, "Firm_")).toBe(0)
			handle.close()
		end)
		t.it("works without an OfficeController at all", function()
			local root = Instance.new("Frame")
			local handle = Directory.open(nil, root, { close = function() end })
			t.expect(find(root, "Retry") ~= nil).toBeTruthy()
			handle.close()
		end)
	end)

	t.describe("Elevator screen", function()
		local payload = {
			companyId = "harrow_williams",
			name = "Harrow Williams",
			short = "HW",
			logo = "harrow_williams",
			current = "lobby",
			outage = true,
			floors = {
				{ id = "lobby", name = "Lobby", floor = 0, available = true },
				{ id = "ib", name = "Investment Banking", floor = 1, available = true },
				{ id = "st", name = "Sales & Trading", floor = 2, available = false },
			},
		}
		t.it("lists floors top first with the current one marked", function()
			local rows = Elevator.rows(payload)
			t.expect(#rows).toBe(3)
			t.expect(rows[1].id).toBe("st")
			t.expect(rows[3].here).toBe(true)
			t.expect(#Elevator.rows(nil)).toBe(0)
			t.expect(#Elevator.rows({ floors = "x" })).toBe(0)
		end)
		t.it("renders the panel with visitor and outage notes", function()
			local root = Instance.new("Frame")
			local handle = Elevator.open(payload, root, ctxFor(fakeApi({})))
			t.expect(count(root, "Floor_")).toBe(3)
			t.expect(find(root, "Outage") ~= nil).toBeTruthy()
			t.expect(find(root, "Visitor") ~= nil).toBeTruthy() -- the fake player works at MG Freeman
			handle.close()
			local own = Instance.new("Frame")
			local mine = table.clone(payload)
			mine.companyId = "mg_freeman"
			mine.outage = nil
			local h2 = Elevator.open(mine, own, ctxFor(fakeApi({})))
			t.expect(find(own, "Visitor")).toBeNil()
			t.expect(find(own, "Outage")).toBeNil()
			h2.close()
		end)
	end)
end
