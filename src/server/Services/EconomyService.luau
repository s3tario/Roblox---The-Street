--!strict
-- EconomyService (server, owned by `shop`; contracts §7, spec §11): the player's Cash.
--
-- Data: data.wallet (Config/DataTemplate/Wallet) = { cash, earned, spent, living, recent }, replicated to its
-- owner (the HUD shows wallet.cash). The maths lives in Logic/Economy/Wallet, so this file only gathers multipliers,
-- persists, replicates and audits. Every change runs without yielding between the check and the write, so a spend
-- can never race another spend into negative cash.
--
-- API (contracts §7):
--   EconomyService:GetCash(player) -> number                         0 until the save has loaded
--   EconomyService:AddCash(player, amount, source, kind?) -> credited
--       kind "salary" | "bonus": x EventService salaryMult x DailyService money boost x ProfileService income mult
--       kind "reward" (default): x ProfileService income mult only     kind "refund" | "admin": credited exactly
--   EconomyService:SpendCash(player, amount, reason) -> boolean       all or nothing
--   EconomyService:ChargeLiving(player, amount) -> charged            weekly living costs; never below $0
--   EconomyService.CashChanged : Signal(player, newCash, delta)
-- Extras: GetWallet(player) -> copy?   GetMultiplier(player, kind) -> number   CanAfford(player, amount) -> boolean
--   Player attribute "Cash" mirrors wallet.cash (profile cards, other servers' UI never read it).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Shop = require(Shared.Config.Shop)
local Wallet = require(Shared.Logic.Economy.Wallet)
local Deps = require(script.Parent.ShopService.Deps)
local E = Shop.economy

local EconomyService = {
	Name = "EconomyService",
	Priority = 8,
	CashChanged = Signal.new(), -- (player, newCash, delta)
}

EconomyService.CASH_ATTR = "Cash"

local normalized: { [Player]: boolean } = {}
local lastSave: { [Player]: number } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
-- The player's wallet, repaired once per session (nil until the save has loaded).
local function walletOf(player: Player): Wallet.Wallet?
	local data = Deps.data(player)
	if not data then
		return nil
	end
	if not normalized[player] or type(data.wallet) ~= "table" then
		data.wallet = Wallet.normalize(data.wallet)
		normalized[player] = true
	end
	return data.wallet :: Wallet.Wallet
end

local function publish(player: Player, w: Wallet.Wallet, delta: number)
	Deps.replicate(player, "wallet")
	if player.Parent == Players and player:GetAttribute(EconomyService.CASH_ATTR) ~= w.cash then
		player:SetAttribute(EconomyService.CASH_ATTR, w.cash)
	end
	if delta ~= 0 then
		EconomyService.CashChanged:Fire(player, w.cash, delta)
	end
end

local function sourceText(source: any): string
	return if type(source) == "string" and source ~= "" then string.sub(source, 1, 40) else "unknown"
end

-- Asks DataService for an early save after a big change, at most once per Shop.economy.saveEvery seconds.
local function maybeSave(player: Player, amount: number, reason: string)
	if amount < E.saveAbove then
		return
	end
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < E.saveEvery then
		return
	end
	lastSave[player] = now
	task.spawn(Deps.save, player, reason)
end

local function multipliers(player: Player, kind: string): Wallet.Mults
	local _, rule = Wallet.kindOf(kind)
	return {
		event = if rule.event then Deps.modifier("salaryMult") else nil,
		daily = if rule.daily then Deps.dailyMult(player, "money") else nil,
		income = if rule.income then Deps.incomeMult(player) else nil,
	}
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function EconomyService:GetCash(player: Player): number
	local w = walletOf(player)
	return if w then w.cash else 0
end

function EconomyService:CanAfford(player: Player, amount: number): boolean
	local w = walletOf(player)
	return w ~= nil and type(amount) == "number" and amount == amount and amount >= 0 and w.cash >= amount
end

function EconomyService:GetWallet(player: Player): { [string]: any }?
	local w = walletOf(player)
	if not w then
		return nil
	end
	local copy = table.clone(w) :: any
	copy.recent = table.clone(w.recent)
	return copy
end

function EconomyService:GetMultiplier(player: Player, kind: string?): number
	local id = Wallet.kindOf(kind)
	return Wallet.multiplier(id, multipliers(player, id))
end

function EconomyService:AddCash(player: Player, amount: number, source: string?, kind: string?): number
	local w = walletOf(player)
	if not w then
		return 0
	end
	local kindId = Wallet.kindOf(kind)
	-- multipliers are read before the wallet is touched; none of these calls yield
	local credit = Wallet.creditAmount(amount, kindId, multipliers(player, kindId))
	if credit <= 0 then
		return 0
	end
	local src = sourceText(source)
	local added = Wallet.credit(w, credit, src, Time.now())
	if added <= 0 then
		return 0
	end
	publish(player, w, added)
	if kindId ~= "salary" or added >= E.auditAbove then
		Deps.audit(player, "cash_credit", { amount = added, base = amount, source = src, kind = kindId })
	end
	maybeSave(player, added, "cash")
	return added
end

function EconomyService:SpendCash(player: Player, amount: number, reason: string?): boolean
	local w = walletOf(player)
	if not w then
		return false
	end
	local before = w.cash
	local src = sourceText(reason)
	if not Wallet.spend(w, amount, src, Time.now()) then
		return false
	end
	local spent = before - w.cash
	if spent > 0 then
		publish(player, w, -spent)
		Deps.audit(player, "cash_spend", { amount = spent, reason = src, cash = w.cash })
		maybeSave(player, spent, "purchase")
	end
	return true
end

function EconomyService:ChargeLiving(player: Player, amount: number): number
	local w = walletOf(player)
	if not w then
		return 0
	end
	local taken = Wallet.charge(w, amount, "living", Time.now())
	if taken > 0 then
		publish(player, w, -taken)
		Deps.audit(player, "cash_living", { amount = taken, asked = amount, cash = w.cash })
	end
	return taken
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function onLoaded(player: Player)
	if player.Parent ~= Players then
		return
	end
	normalized[player] = nil
	local w = walletOf(player)
	if w then
		publish(player, w, 0)
	end
end

function EconomyService:Init()
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		onLoaded(player)
	end)
end

function EconomyService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		normalized[player] = nil
		lastSave[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if Deps.isLoaded(player) then
			task.spawn(onLoaded, player)
		end
	end
end

return EconomyService
