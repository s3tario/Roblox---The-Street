--!strict
-- Shared types for the Terminal's parts (owned by `market`).
--   Env    what every part gets at construction: the controller, the UIController ctx and the screen's actions
--   State  what every part's update(state) gets on each refresh (market cache, the replicated book, live prices)
--   Part   { frame, update(state), tick?(now), destroy? }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Cache = require(script.Parent.Cache)

export type Actions = {
	select: (id: string) -> (), -- choose the ticker shown in the quote, facts and ticket ("ST10" = the index)
	setRange: (range: string) -> (), -- "1d" | "30d"
	setTab: (tab: string) -> (), -- phone layout tab
	trade: (side: string) -> (), -- open the ticket on a side ("buy" | "sell")
	notify: (text: string, kind: string?) -> (),
	refresh: () -> (), -- rebuild state and update every part now
	confirm: (opts: { [string]: any }, callback: (ok: boolean) -> ()) -> (), -- Kit.Confirm through UIController
}

export type Env = {
	controller: any, -- TerminalController (or a test fake): Trade, SetStops, Flatten, ErrorText, ...
	ui: any, -- UIController (Confirm, Notify)
	actions: Actions,
	mode: string, -- "trade" | "news" (read-only news stand)
	layout: string, -- "wide" | "phone"
}

export type State = {
	cache: Cache.Cache,
	book: any, -- data.portfolio (replicated) or nil before it loads
	prices: { [string]: number },
	now: number, -- synced server time
	selected: string,
	range: string,
	limits: Ledger.Limits,
	panel: { [string]: any }?, -- Portfolio.Panel (week metrics, session curve, skill)
	mode: string,
	layout: string,
}

export type Part = {
	frame: GuiObject,
	update: (state: State) -> (),
	tick: ((now: number) -> ())?, -- once a second while open (countdowns)
	destroy: (() -> ())?,
}

return {}
