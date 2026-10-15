--!strict
-- UI sound cues (owned by `ui`), played by src/client/UI/Sfx.luau with Sfx.play(name).
--
-- Every cue uses built-in rbxasset:// sounds that ship with the Roblox client, so the game sounds complete
-- without uploading anything. Distinct cues come from pitch (speed) and short note sequences.
-- To use your own uploaded sound, replace `id` with "rbxassetid://<number>" (and drop `notes` if the new
-- sound already contains the whole jingle).
--
-- Fields:
--   id      sound content id
--   volume  0..1 base volume (multiplied by the player's sfx setting through the Sfx SoundGroup)
--   speed   PlaybackSpeed (pitch); 1 = original
--   notes   optional sequence { {delay = seconds after the first note, speed?, volume?}, ... }
--   gap     minimum seconds between two plays of this cue (anti-stacking); default 0.04

export type Note = { delay: number, speed: number?, volume: number? }
export type Cue = { id: string, volume: number, speed: number?, notes: { Note }?, gap: number? }

local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local SNAP = "rbxasset://sounds/snap.wav"

-- Musical intervals as playback-speed ratios.
local THIRD = 1.26 -- major third (2^(4/12))
local FIFTH = 1.498 -- perfect fifth (2^(7/12))

local Sounds = {}

Sounds.cues = {
	click = { id = CLICK, volume = 0.4, speed = 1.1, gap = 0.03 },
	open = { id = SWOOSH, volume = 0.3, speed = 1.15 },
	close = { id = SWOOSH, volume = 0.25, speed = 0.85 },
	notify = { id = PING, volume = 0.35, speed = 1.0, gap = 0.12 },
	good = { id = PING, volume = 0.4, speed = THIRD, gap = 0.12 },
	bad = { id = BUTTON, volume = 0.45, speed = 0.6, gap = 0.12 },
	cash = {
		id = SNAP,
		volume = 0.45,
		speed = 1.3,
		gap = 0.1,
		notes = { { delay = 0 }, { delay = 0.07, speed = 1.7 } },
	},
	levelup = {
		id = PING,
		volume = 0.5,
		gap = 0.5,
		notes = { { delay = 0, speed = 1 }, { delay = 0.09, speed = THIRD }, { delay = 0.18, speed = FIFTH } },
	},
	promotion = {
		id = PING,
		volume = 0.55,
		gap = 1,
		notes = {
			{ delay = 0, speed = 1 },
			{ delay = 0.11, speed = THIRD },
			{ delay = 0.22, speed = FIFTH },
			{ delay = 0.36, speed = 2, volume = 0.65 },
		},
	},
	alarm = {
		id = PING,
		volume = 0.5,
		speed = 0.7,
		gap = 0.8,
		notes = { { delay = 0 }, { delay = 0.22 }, { delay = 0.44 } },
	},
	chime = {
		id = PING,
		volume = 0.4,
		gap = 0.4,
		notes = { { delay = 0, speed = FIFTH }, { delay = 0.13, speed = 1.12 } },
	},
	error = { id = BUTTON, volume = 0.45, speed = 0.5, gap = 0.15 },
	type = { id = CLICK, volume = 0.18, speed = 1.6, gap = 0.02 },
} :: { [string]: Cue }

-- Every cue name the UI uses (tests check they all exist).
Sounds.names = {
	"click",
	"open",
	"close",
	"notify",
	"good",
	"bad",
	"cash",
	"levelup",
	"promotion",
	"alarm",
	"chime",
	"error",
	"type",
}

-- Default SoundGroup volumes before the player's settings arrive.
Sounds.groups = { sfx = 0.8, music = 0.5 }

return Sounds
