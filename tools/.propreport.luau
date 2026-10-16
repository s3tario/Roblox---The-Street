-- TEMP dev report (deleted before finishing)
local process = require("@lune/process")
local V = require("./lib/vrequire")
V.init("default.project.json")
local env = V.specEnv()
local roblox = require("@lune/roblox")
local Props = V.requirePath("ReplicatedStorage/Shared/Assets/Props")
local Common = V.requirePath("ReplicatedStorage/Shared/Assets/Props/Common")
local CF = roblox.CFrame
local filter = process.args[1]
local cf = CF.new(37, 5, -12) * CF.Angles(0, math.rad(33), 0)
for _, info in Props.list() do
	if filter and not string.find(info.id, filter, 1, true) and info.category ~= filter then continue end
	local ok, m = pcall(Props.build, info.id, nil, cf, nil)
	if not ok then print("ERROR", info.id, m) continue end
	local n = 0
	local unanch = 0
	local minY = math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			if not d.Anchored then unanch += 1 end
		end
	end
	local mn, mx = Common.localBounds(m, cf, m.PrimaryPart)
	local size = mx - mn
	local fp = info.footprint
	local function bad(a, b) return math.abs(a - b) > math.max(0.25 * b, 0.3) end
	local flag = (bad(size.X, fp.X) or bad(size.Y, fp.Y) or bad(size.Z, fp.Z)) and "FP!" or "   "
	local pflag = n > info.maxParts and "PARTS!" or ""
	local yflag = mn.Y < -0.1 and ("BELOW " .. string.format("%.2f", mn.Y)) or ""
	print(string.format("%-22s %3d/%3d %s size(%5.2f %5.2f %5.2f) fp(%5.2f %5.2f %5.2f) min(%5.2f %5.2f %5.2f) max(%5.2f %5.2f %5.2f) %s %s %s",
		info.id, n, info.maxParts, flag, size.X, size.Y, size.Z, fp.X, fp.Y, fp.Z, mn.X, mn.Y, mn.Z, mx.X, mx.Y, mx.Z, pflag, yflag, unanch > 0 and "UNANCHORED" or ""))
end
