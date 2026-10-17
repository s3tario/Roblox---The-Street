-- Exports the wardrobe catalog as JSON for the clothing tools (generate.py, upload.py).
--   lune run tools/clothing/export [out.json]     (run from the repo root; default: stdout)
-- Each entry: { id, name, slot, builder, style, pattern, finish, details, colors, brand, rarity, hidden, template }
-- where template is "shirt" (top/outer), "pants" (bottom) or nil.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local V = require("../lib/vrequire")

V.init("default.project.json")
local Catalog = V.requirePath("ReplicatedStorage/Shared/Config/Catalog")

local TEMPLATE = { top = "shirt", outer = "shirt", bottom = "pants" }

local items = {}
for _, id in Catalog.order do
	local it = Catalog.items[id]
	table.insert(items, {
		id = it.id,
		name = it.name,
		slot = it.slot,
		builder = it.builder,
		style = it.style,
		pattern = it.pattern,
		finish = it.finish,
		details = it.details,
		colors = it.colors,
		brand = it.brand,
		rarity = it.rarity,
		hidden = it.hidden == true,
		template = TEMPLATE[it.slot],
	})
end

local json = serde.encode("json", { items = items }, true)
local out = process.args[1]
if out then
	fs.writeFile(out, json)
	print(("exported %d items to %s"):format(#items, out))
else
	print(json)
end
