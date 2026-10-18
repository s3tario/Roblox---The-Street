--!strict
-- Housing defaults (owned by `shop`; contracts §3 and §7). Saved in data.housing and replicated to the owner.
-- Kept through rebirth (v3 §9).
--   owned    { [decorId] = true }                          decor bought or granted (Config/Decor ids)
--   placed   { [context] = { [slotId] = decorId } }        what stands in each decor slot, per context
--            contexts: dorm, apartment, desk, office (Config/Decor.CONTEXTS). Slot ids come from the DecorSlot
--            markers (HousingService/Slots), so every desk and office of the same template shares them.
--   theme    { [context] = themeId }                       room theme per themed context (Config/Decor.themes)

return {
	housing = {
		owned = {},
		placed = {
			dorm = {},
			apartment = {},
			desk = {},
			office = {},
		},
		theme = {},
	},
}
