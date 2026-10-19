-- scratch: dump the Street's parts to JSON for the preview renderer
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local V = require("../../tools/lib/vrequire")
V.init("default.project.json")
local Street = V.require(V.resolve("ServerStorage/WorldBuilders/Street"))
local roblox = require("@lune/roblox")
local root = roblox.Instance.new("Folder")
local m = Street.build(root)
local out = {}
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") then
		local cf = d.CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		local shape = "Block"
		if d.ClassName == "Part" then
			shape = d.Shape.Name
		elseif d.ClassName == "WedgePart" then
			shape = "Wedge"
		elseif d.ClassName == "CornerWedgePart" then
			shape = "CornerWedge"
		end
		local c = d.Color
		table.insert(out, {
			s = shape,
			cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			sz = { d.Size.X, d.Size.Y, d.Size.Z },
			c = { c.R, c.G, c.B },
			t = d.Transparency,
			m = d.Material.Name,
			n = d.Name,
		})
	end
end
fs.writeFile(process.args[1] or "street.json", serde.encode("json", out))
print("parts", #out)
