--!strict
-- A stand-in controller (owned by `market`) the Terminal uses when TerminalController isn't running: an empty market
-- cache, no book, and every order politely refused. The screen still opens and explains that the exchange isn't
-- connected instead of erroring. Same method shape as TerminalController.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Cache = require(script.Parent.Cache)

local Offline = {}

function Offline.new(): any
	local cache = Cache.new()
	local selected = "APX"
	local c = { Changed = Signal.new(), offline = true }
	function c:GetCache()
		return cache
	end
	function c:Now(): number
		return Time.now()
	end
	function c:GetBook(): any
		return nil
	end
	function c:GetLimits(): Ledger.Limits
		return Ledger.defaultLimits()
	end
	function c:GetPanel(): any
		return nil
	end
	function c:RefreshPanel() end
	function c:RequestSnapshot(_force: boolean?) end
	function c:GetSelected(): string
		return selected
	end
	function c:SetSelected(id: string)
		selected = id
	end
	function c:ShortTitle(): string
		return Tickers.text("short_title_default")
	end
	function c:Subtitle(): string
		return Tickers.text("offline")
	end
	function c:Trade(_order: any): (boolean, string?, any)
		return false, "offline", nil
	end
	function c:SetStops(_ticker: string, _stop: number?, _take: number?): (boolean, string?)
		return false, "offline"
	end
	function c:Flatten(): (boolean, string?, number?)
		return false, "offline", nil
	end
	function c:ErrorText(_err: string?, _vars: any): string
		return Tickers.text("offline_trade")
	end
	return c
end

return Offline
