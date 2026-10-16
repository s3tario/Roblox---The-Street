--!strict
-- Shared plumbing for sign builders: every sign is a Model with an invisible, non-colliding PrimaryPart
-- "Root" at cf, attributes SignKind/SignMount, tag "Sign", and a seeded builder context (the same Ctx
-- helpers prop builders use, with LOCAL CFrames). Bake-safe (contracts §13).

local Common = require(script.Parent.Parent.Props.Common)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Hash = require(script.Parent.Parent.Parent.Util.Hash)

local Base = {}

export type Opts = { [string]: any }
export type Ctx = Common.Ctx

local function seedFor(kind: string, cf: CFrame, o: Opts): number
	local s = o.seed
	if (type(s) == "number" and s == s and s ~= math.huge and s ~= -math.huge) or type(s) == "string" then
		return Hash.u32("sign", kind, s)
	end
	local p = cf.Position
	return Hash.u32("sign", kind, math.floor(p.X * 4 + 0.5), math.floor(p.Y * 4 + 0.5), math.floor(p.Z * 4 + 0.5))
end

-- Creates the sign model (unparented) and its builder context.
function Base.begin(kind: string, cf: CFrame, opts: Opts?): (Model, Ctx)
	local o: Opts = if type(opts) == "table" then opts else {}
	local model = Common.shell(Common.optStr(o, "name", "Sign_" .. kind, 60), cf)
	model:SetAttribute("SignKind", kind)
	model:AddTag("Sign")
	local c = Common.ctx(model, cf, o, Rng.new(seedFor(kind, cf, o)), kind, nil)
	return model, c
end

-- Stamps the mount, parents the model and returns it.
function Base.finish(model: Model, parent: Instance?, mount: string): Model
	model:SetAttribute("SignMount", mount)
	if parent then
		model.Parent = parent
	end
	return model
end

-- Width that comfortably fits `text` at letter height `h` (clamped), used when opts.width is absent.
function Base.fitWidth(text: string, h: number, lo: number, hi: number): number
	local longest = 0
	for line in string.gmatch(text, "[^\n]+") do
		longest = math.max(longest, #line)
	end
	return math.clamp(longest * h * 0.62 + h * 0.6, lo, hi)
end

return Base
