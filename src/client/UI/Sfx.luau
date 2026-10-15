--!strict
-- Client UI sound effects.
--   Sfx.play(name)                 cue from Shared/Config/Sounds (click open close notify good bad cash
--                                  levelup promotion alarm chime error type)
--   Sfx.setVolume("sfx" | "music", v)   0..1 (the player's settings; applied through SoundGroups)
--   Sfx.group("sfx" | "music") -> SoundGroup?   parent your own music/ambience Sounds' SoundGroup to these
-- Sounds are pooled per content id under SoundService; nothing is created until the first play, and
-- everything is a no-op outside Roblox (Lune tests).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local Sfx = {}

local LIVE = (workspace :: any) ~= nil
local POOL_SIZE = 4

type Pool = { sounds: { Sound }, nextIndex: number }

local folder: Folder? = nil
local groups: { [string]: SoundGroup } = {}
local volumes: { [string]: number } = { sfx = Sounds.groups.sfx, music = Sounds.groups.music }
local pools: { [string]: Pool } = {}
local lastPlayed: { [string]: number } = {}
local muted = false

local function soundService(): SoundService?
	if not LIVE then
		return nil
	end
	local ok, ss = pcall(function()
		return game:GetService("SoundService")
	end)
	return if ok then ss else nil
end

local function ensureGroup(name: string): SoundGroup?
	local existing = groups[name]
	if existing and existing.Parent then
		return existing
	end
	local ss = soundService()
	if not ss then
		return nil
	end
	local groupName = "TheStreet_" .. name
	local g = ss:FindFirstChild(groupName)
	local group: SoundGroup
	if g and g:IsA("SoundGroup") then
		group = g
	else
		group = Instance.new("SoundGroup")
		group.Name = groupName
		group.Parent = ss
	end
	group.Volume = volumes[name] or 1
	groups[name] = group
	return group
end

local function ensureFolder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local ss = soundService()
	if not ss then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "TheStreetSfx"
	f.Parent = ss
	folder = f
	return f
end

local function getSound(id: string): Sound?
	local pool = pools[id]
	if pool == nil then
		local parent = ensureFolder()
		local group = ensureGroup("sfx")
		if not parent then
			return nil
		end
		local list: { Sound } = {}
		for i = 1, POOL_SIZE do
			local s = Instance.new("Sound")
			s.Name = "Sfx" .. i
			s.SoundId = id
			s.Looped = false
			s.SoundGroup = group
			s.Parent = parent
			list[i] = s
		end
		pool = { sounds = list, nextIndex = 1 }
		pools[id] = pool
	end
	local p = pool :: Pool
	-- Prefer an idle sound; otherwise reuse the oldest one (round robin).
	for _, s in p.sounds do
		if not s.IsPlaying then
			return s
		end
	end
	local s = p.sounds[p.nextIndex]
	p.nextIndex = (p.nextIndex % #p.sounds) + 1
	return s
end

local function playNote(id: string, volume: number, speed: number)
	local s = getSound(id)
	if not s then
		return
	end
	s.Volume = math.clamp(volume, 0, 1)
	s.PlaybackSpeed = math.clamp(speed, 0.1, 4)
	s.TimePosition = 0
	s:Play()
end

-- Plays a cue by name. Unknown names fall back to "click" (and warn once).
local warnedUnknown: { [string]: boolean } = {}
function Sfx.play(name: string)
	if not LIVE or muted then
		return
	end
	local cue = Sounds.cues[name]
	if cue == nil then
		if not warnedUnknown[name] then
			warnedUnknown[name] = true
			warn("[Sfx] unknown sound cue " .. tostring(name))
		end
		cue = Sounds.cues.click
		if cue == nil then
			return
		end
	end
	if (volumes.sfx or 1) <= 0 then
		return
	end
	local now = os.clock()
	local last = lastPlayed[name]
	if last and now - last < (cue.gap or 0.04) then
		return
	end
	lastPlayed[name] = now
	local c = cue :: Sounds.Cue
	local ok, err = pcall(function(): any
		local baseSpeed = c.speed or 1
		local notes = c.notes
		if notes == nil or #notes == 0 then
			playNote(c.id, c.volume, baseSpeed)
			return nil
		end
		for _, note in notes do
			local vol = note.volume or c.volume
			local speed = note.speed or baseSpeed
			if note.delay <= 0 then
				playNote(c.id, vol, speed)
			else
				task.delay(note.delay, function()
					pcall(playNote, c.id, vol, speed)
				end)
			end
		end
		return nil
	end)
	if not ok then
		warn("[Sfx] failed to play " .. name .. ": " .. tostring(err))
	end
end

function Sfx.setVolume(groupName: string, v: number?)
	local value = if type(v) == "number" and v == v then math.clamp(v, 0, 1) else (volumes[groupName] or 1)
	volumes[groupName] = value
	if LIVE then
		local g = ensureGroup(groupName)
		if g then
			g.Volume = value
		end
	end
end

function Sfx.getVolume(groupName: string): number
	return volumes[groupName] or 1
end

-- SoundGroup for other features' music/ambience ("music") or effects ("sfx").
function Sfx.group(groupName: string): SoundGroup?
	return ensureGroup(groupName)
end

function Sfx.setMuted(on: boolean)
	muted = on == true
end

-- Creates the pools for the common cues up front so the first click has no load hitch.
function Sfx.preload()
	if not LIVE then
		return
	end
	local seen: { [string]: boolean } = {}
	for _, name in Sounds.names do
		local cue = Sounds.cues[name]
		if cue and not seen[cue.id] then
			seen[cue.id] = true
			getSound(cue.id)
		end
	end
end

return Sfx
