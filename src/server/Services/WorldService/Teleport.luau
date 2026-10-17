--!strict
-- WorldService/Teleport (server, runtime): moving a character somewhere else in the world, safely.
--   1. refuse while another teleport for that player is running ("busy"), within the 2 s cooldown ("cooldown",
--      unless opts.force) or without a living character ("no_character")
--   2. tell the client to fade out ("World.Fade" "out" {label?, sublabel?, message?}) and wait for the fade
--      (plus opts.delay, e.g. taking the stairs during an elevator outage)
--   3. player:RequestStreamAroundAsync(target) so the destination is on the client before the character lands
--      (StreamingEnabled), then re-check that the player and the same character are still here
--   4. leave any seat, PivotTo(target), zero the velocity, and fade back in ("World.Fade" "in" {label, sublabel})
-- Every failure after the fade-out still fades the client back in, so nobody is left on a black screen.
--
--   Teleport.bind(onMoved)          onMoved(player, cframe) after every successful move (anti-cheat bookkeeping)
--   Teleport.run(player, cframe, opts?) -> (ok, errKey?)   yields ~0.3-4 s
--   Teleport.canTeleport(player, force?) -> (ok, errKey?)
--   Teleport.isBusy(player) -> boolean
--   Teleport.clear(player)          the player left
-- opts = { label?, sublabel?, message?, delay?, force?, fade? (default true), stream? (default true), reason? }

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Teleport = {}

Teleport.FADE = "World.Fade"
Teleport.COOLDOWN = 2
Teleport.FADE_OUT = 0.3
Teleport.STREAM_TIMEOUT = 4
Teleport.MAX_DELAY = 8

export type Opts = {
	label: string?,
	sublabel: string?,
	message: string?,
	delay: number?,
	force: boolean?,
	fade: boolean?,
	stream: boolean?,
	reason: string?,
	companyId: string?,
}

local busy: { [Player]: boolean } = {}
local lastAt: { [Player]: number } = {}
local onMovedFn: ((Player, CFrame) -> ())? = nil

function Teleport.bind(onMoved: (Player, CFrame) -> ())
	onMovedFn = onMoved
end

local function isLive(player: Player): boolean
	return player.Parent == Players
end

local function livingCharacter(player: Player): (Model?, BasePart?, Humanoid?)
	local char = player.Character
	if not char or char.Parent == nil then
		return nil, nil, nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hrp:IsA("BasePart")) then
		return nil, nil, nil
	end
	if hum and hum.Health <= 0 then
		return nil, nil, nil
	end
	return char, hrp, hum
end

function Teleport.isBusy(player: Player): boolean
	return busy[player] == true
end

function Teleport.canTeleport(player: Player, force: boolean?): (boolean, string?)
	if not isLive(player) then
		return false, "no_player"
	end
	if busy[player] then
		return false, "busy"
	end
	if not force and os.clock() - (lastAt[player] or -math.huge) < Teleport.COOLDOWN then
		return false, "cooldown"
	end
	local char = livingCharacter(player)
	if not char then
		return false, "no_character"
	end
	return true, nil
end

local function fade(player: Player, phase: string, info: { [string]: any })
	if isLive(player) then
		Net.fire(Teleport.FADE, player, phase, info)
	end
end

local function unseat(hum: Humanoid?)
	if not hum then
		return
	end
	local seat = hum.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		hum.Sit = false
	end
end

function Teleport.run(player: Player, cf: CFrame, opts: Opts?): (boolean, string?)
	local o: Opts = opts or {}
	local ok, why = Teleport.canTeleport(player, o.force)
	if not ok then
		return false, why
	end
	local char = livingCharacter(player) :: Model
	busy[player] = true
	local withFade = o.fade ~= false
	local function finish(success: boolean, err: string?): (boolean, string?)
		busy[player] = nil
		if withFade then
			fade(player, "in", if success then { label = o.label, sublabel = o.sublabel } else {})
		end
		return success, err
	end

	if withFade then
		fade(player, "out", { label = o.label, sublabel = o.sublabel, message = o.message })
		local extra = math.clamp(if type(o.delay) == "number" then o.delay else 0, 0, Teleport.MAX_DELAY)
		task.wait(Teleport.FADE_OUT + extra)
	end
	if o.stream ~= false and isLive(player) then
		local streamed, err = pcall(function()
			player:RequestStreamAroundAsync(cf.Position, Teleport.STREAM_TIMEOUT)
		end)
		if not streamed then
			warn("[WorldService] RequestStreamAroundAsync failed: " .. tostring(err))
		end
	end
	if not isLive(player) then
		busy[player] = nil
		return false, "no_player"
	end
	local now, hrp, hum = livingCharacter(player)
	if now ~= char or not hrp then
		return finish(false, "no_character")
	end
	unseat(hum)
	char:PivotTo(cf)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	lastAt[player] = os.clock()
	local moved = onMovedFn
	if moved then
		local okMoved, err = pcall(function(): string?
			moved(player, cf)
			return nil
		end)
		if not okMoved then
			warn("[WorldService] teleport bookkeeping failed: " .. tostring(err))
		end
	end
	return finish(true, nil)
end

function Teleport.clear(player: Player)
	busy[player] = nil
	lastAt[player] = nil
end

return Teleport
