--!strict
-- Wardrobe screen: the "Outfits" tab. Five preset slots (the first two free, the rest with the Executive Club
-- pass): each row shows the saved outfit's name and size with "Wear" and "Save current" buttons.
--
--   Presets.build(opts) -> Panel
--     opts = { onSave: (index, name?) -> (), onLoad: (index) -> () }
--   panel.frame                  the panel (put it in a Scroll)
--   panel.update(presets, openSlots, busy)
--     presets   = inventory.presets ({ ["1"] = { name, equipped } })
--     openSlots = Catalog.presetSlotsFor(viewer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

local Presets = {}

export type Panel = {
	frame: Frame,
	update: (presets: any, openSlots: number, busy: boolean) -> (),
}

type Row = {
	name: Kit.Label,
	info: Kit.Label,
	lock: Kit.Badge,
	wear: Kit.Button,
	save: Kit.Button,
}

function Presets.build(opts: { onSave: (number, string?) -> (), onLoad: (number) -> () }): Panel
	local panel = Kit.List({ gap = 8, name = "Presets" })

	local hint = Kit.Label({ text = Catalog.text("presets_hint"), size = "sm", color = "textDim", name = "Hint" })
	panel.add(hint)

	local nameInput = Kit.TextInput({
		placeholder = Catalog.text("preset_name_placeholder"),
		maxLength = Catalog.PRESET_SLOTS.nameMax,
		name = "PresetName",
	})
	panel.add(nameInput)

	local rows: { Row } = {}
	for i = 1, Catalog.PRESET_SLOTS.max do
		local card = Kit.Panel({ color = "panelAlt", name = "Preset" .. i, padding = 10 })
		local row = Kit.List({ direction = "horizontal", gap = 8, name = "Row" })
		row.frame.Size = UDim2.new(1, 0, 0, Kit.TAP)
		row.frame.AutomaticSize = Enum.AutomaticSize.None
		card.add(row)

		local texts = Kit.List({ gap = 0, name = "Texts", size = UDim2.new(1, -250, 1, 0) })
		texts.layout.VerticalAlignment = Enum.VerticalAlignment.Center
		row.add(texts)
		local name = Kit.Label({ text = "", size = "md", font = "bodyBold", autoSize = "none", height = 22, name = "Name" })
		name.frame.TextTruncate = Enum.TextTruncate.AtEnd
		texts.add(name)
		local info = Kit.Label({ text = "", size = "xs", color = "textDim", autoSize = "none", height = 16, name = "Info" })
		texts.add(info)
		local lock = Kit.Badge({ text = Catalog.text("preset_locked"), color = "accent", name = "Lock" })
		texts.add(lock)

		local wear = Kit.Button({
			text = Catalog.text("preset_load"),
			style = "primary",
			size = UDim2.fromOffset(100, Kit.TAP),
			name = "Wear",
			onClick = function()
				opts.onLoad(i)
			end,
		})
		row.add(wear)
		local save = Kit.Button({
			text = Catalog.text("preset_save"),
			style = "secondary",
			size = UDim2.fromOffset(130, Kit.TAP),
			name = "Save",
			onClick = function()
				local typed = nameInput.get()
				opts.onSave(i, if typed ~= "" then typed else nil)
				nameInput.set("")
			end,
		})
		row.add(save)

		panel.add(card)
		rows[i] = { name = name, info = info, lock = lock, wear = wear, save = save }
	end

	local function update(presets: any, openSlots: number, busy: boolean)
		local list = if type(presets) == "table" then presets else {}
		for i, r in rows do
			local p = list[tostring(i)]
			local locked = i > openSlots
			local count = 0
			if type(p) == "table" and type(p.equipped) == "table" then
				for _ in p.equipped do
					count += 1
				end
			end
			local empty = type(p) ~= "table"
			r.name.setText(if empty then Catalog.text("preset_name", { index = i }) else tostring(p.name))
			r.info.setText(if empty then Catalog.text("preset_empty") else Catalog.text("preset_pieces", { count = count }))
			r.info.frame.Visible = not locked
			r.lock.frame.Visible = locked
			r.wear.setDisabled(locked or empty or busy)
			r.save.setDisabled(locked or busy)
		end
	end

	return { frame = panel.frame, update = update }
end

return Presets
