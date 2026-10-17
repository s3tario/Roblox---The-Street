--!strict
-- Catalog: shared types (re-exported by Catalog/init.luau as Catalog.Item, Catalog.Look, ...).

export type Slot = "top" | "outer" | "bottom" | "shoes" | "neck" | "wrist" | "eyes" | "head" | "bag"
export type Colors = { primary: string, secondary: string?, accent: string?, trim: string? }
export type Currency = "cash" | "pass" | "roll" | "heirloom"
export type Item = {
	id: string,
	name: string,
	slot: Slot,
	category: string,
	price: number,
	currency: Currency,
	pass: string?,
	minRank: number?,
	colors: Colors,
	builder: string,
	tier: number,
	brand: string,
	rarity: string,
	desc: string,
	tags: { string },
	style: string?,
	pattern: string?,
	finish: string?,
	details: { string }?,
	text: string?,
	hidden: boolean?,
}
export type Look = { id: string, brand: string, name: string, rarity: string, itemIds: { string } }
export type Viewer = {
	owned: { [string]: any }?,
	rank: number?,
	passes: { [string]: any }?,
}
export type Preset = {
	equipped: { [string]: string },
	hairStyle: string?,
	hairColor: string?,
	skin: string?,
	pose: string?,
}

return {}
