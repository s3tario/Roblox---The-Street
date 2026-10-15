local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Kit = require(Shared.Build.Kit)

return function(t)
	t.describe("World config", function()
		t.it("every door targets a known anchor and lives in a known zone", function()
			for id, door in World.doors do
				t.expect(World.zones[door.zone] ~= nil).toBeTruthy()
				if door.ride then
					t.expect(World.anchors[door.ride.via] ~= nil).toBeTruthy()
					t.expect(World.anchors[door.ride.to] ~= nil).toBeTruthy()
				else
					if World.anchors[door.target] == nil then
						error("door " .. id .. " targets unknown anchor " .. tostring(door.target))
					end
				end
			end
		end)
		t.it("every anchor's zone exists and every zone is covered by exactly one builder", function()
			for id, a in World.anchors do
				if World.zones[a.zone] == nil then
					error("anchor " .. id .. " in unknown zone " .. a.zone)
				end
			end
			local covered = {}
			for _, b in World.builders do
				for _, z in b.zones do
					t.expect(covered[z]).toBeNil()
					covered[z] = b.module
				end
			end
			for zoneId in World.zones do
				if covered[zoneId] == nil then
					error("zone " .. zoneId .. " has no builder")
				end
			end
		end)
		t.it("interior builders match World.builders", function()
			for id, def in World.interiors do
				local found = false
				for _, b in World.builders do
					if b.module == def.builder and table.find(b.zones, id) then
						found = true
					end
				end
				if not found then
					error("interior " .. id .. " builder mismatch")
				end
			end
		end)
		t.it("interior slots never overlap regions or each other", function()
			local seenSlots = {}
			for id, def in World.interiors do
				t.expect(seenSlots[def.slot]).toBeNil()
				seenSlots[def.slot] = id
				local mn = World.interiorBounds(id)
				for _, r in World.regions do
					t.expect(mn.X > r.max.X or mn.Z > r.max.Z).toBeTruthy()
				end
			end
		end)
		t.it("zoneAt resolves exterior and interior positions", function()
			t.expect(World.zoneAt(Vector3.new(-1400, 0, 0))).toBe("campus")
			t.expect(World.zoneAt(Vector3.new(0, 10, 0))).toBe("street")
			t.expect(World.zoneAt(World.slotOrigin(World.interiors.hq_lobby.slot))).toBe("hq_lobby")
			t.expect(World.zoneAt(Vector3.new(100000, 0, 0))).toBeNil()
		end)
	end)

	t.describe("Kit (bake-safe)", function()
		t.it("builds parts, markers, signs and rooms under Lune", function()
			local root = Kit.model(nil, "Test")
			local p = Kit.block(root, Kit.at(0, 1, 0), Vector3.new(4, 2, 4), Kit.Palette.street.marble, Kit.Mat.Marble)
			t.expect(p.Anchored).toBe(true)
			t.expect(p.Material).toBe(Enum.Material.Marble)
			local c = Kit.cylinder(root, Kit.at(0, 5, 0), 10, 2, Kit.Palette.street.brass, Kit.Mat.Metal)
			t.expect(c.Size.X).toBe(10)
			t.expect(math.abs(c.CFrame.RightVector.Y)).toBeCloseTo(1, 1e-6) -- cylinder axis is vertical
			local a = Kit.anchor(root, "street_plaza", Kit.at(0, 3, 0))
			t.expect(a:GetAttribute("AnchorId")).toBe("street_plaza")
			t.expect(a:HasTag("Anchor")).toBe(true)
			local d = Kit.door(root, "door_street_hq", Kit.at(0, 4, 5), Vector3.new(6, 8, 1))
			t.expect(d:GetAttribute("DoorId")).toBe("door_street_hq")
			Kit.interact(p, "terminal")
			t.expect(p:HasTag("Interact")).toBe(true)
			local label = Kit.sign(p, "STERLING & VANCE", { glow = true, font = Enum.Font.GothamBlack })
			t.expect(label.Text).toBe("STERLING & VANCE")
			local room = Kit.room(root, {
				cf = Kit.at(0, 0, 0),
				size = Vector3.new(20, 10, 30),
				floorColor = Kit.Palette.street.oak,
				wallColor = Kit.Palette.street.white,
				gaps = { { side = "front", offset = 0, width = 6, height = 8 } },
			})
			t.expect(Kit.countParts(room)).toBeGreaterThan(5)
			local grid = Kit.windowGrid(root, {
				cf = Kit.at(0, 20, -10),
				width = 40,
				height = 30,
				cols = 8,
				rows = 6,
				glassColor = Kit.Palette.street.glass,
				frameColor = Kit.Palette.street.brass,
				litChance = 0.3,
				seed = "test",
			})
			t.expect(Kit.countParts(grid)).toBeGreaterThan(16)
		end)
		t.it("rejects invalid enum names at build time", function()
			t.expect(function()
				Kit.sign(Kit.part(nil, {}), "x", { font = (Enum.Font :: any).NotAFont })
			end).toThrow()
		end)
	end)
end
