-- Runs every tests/**/*.spec.luau under Lune.
--   lune run tools/test               -- all specs
--   lune run tools/test market career -- only specs whose path contains "market" or "career"

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local V = require("./lib/vrequire")
local TestKit = require("./lib/testkit")

V.init("default.project.json")

local filters = process.args

local function collect(dir: string, out: { string })
	if not fs.isDir(dir) then
		return
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, e in entries do
		local p = dir .. "/" .. e
		if fs.isDir(p) then
			collect(p, out)
		elseif string.sub(e, -10) == ".spec.luau" then
			table.insert(out, p)
		end
	end
end

local files = {}
collect("tests", files)

local passed, failed = 0, 0
local failures = {}
local start = os.clock()

for _, file in files do
	local include = #filters == 0
	for _, f in filters do
		if string.find(file, f, 1, true) then
			include = true
		end
	end
	if include then
		local ok, specFn = pcall(function()
			local chunk =
				luau.load(fs.readFile(file), { debugName = file, environment = V.specEnv(), injectGlobals = true })
			return chunk()
		end)
		if not ok or type(specFn) ~= "function" then
			failed += 1
			table.insert(failures, { file = file, name = "(load)", err = tostring(specFn) })
		else
			local results = TestKit.run(specFn, file)
			local fileFails = 0
			for _, r in results do
				if r.ok then
					passed += 1
				else
					failed += 1
					fileFails += 1
					table.insert(failures, { file = file, name = r.name, err = r.err })
				end
			end
			print(("%s %s (%d tests)"):format(if fileFails == 0 then "PASS" else "FAIL", file, #results))
		end
	end
end

for _, f in failures do
	print(("\n✗ %s :: %s\n  %s"):format(f.file, f.name, string.gsub(tostring(f.err), "\n", "\n  ")))
end
print(("\n%d passed, %d failed in %.2fs"):format(passed, failed, os.clock() - start))
if failed > 0 then
	process.exit(1)
end
