--!strict
-- The Street's art direction (Palette.street plus the extra tones the district needs): limestone and marble,
-- granite paving, glass curtain walls with brass mullions, black-and-gold signage, bronze, clean asphalt.
-- Bake-safe.

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit
local S = Deps.Palette.street
local hex = Kit.hex

local Look = {}

Look.M = Enum.Material

-- stone
Look.limestone = S.limestone
Look.limestoneDark = S.limestoneDark
Look.limestoneWarm = hex("#E2D6BF")
Look.sandstone = hex("#C9B08A")
Look.marble = S.marble
Look.marbleVein = S.marbleVein
Look.granite = S.granite
Look.graniteLight = S.graniteLight
Look.graniteDark = hex("#2E3034")
Look.blackGranite = hex("#17191C")
Look.basalt = hex("#3A3C40")
Look.brick = hex("#8A4B36")
Look.brickDark = hex("#6B3727")
Look.brickRed = hex("#9A4A35")
Look.terracotta = hex("#B5653E")
Look.cream = hex("#EFE6D2")
Look.slate = hex("#3F454C")

-- metal
Look.brass = S.brass
Look.gold = S.gold
Look.goldBright = S.goldBright
Look.bronze = hex("#7A5A35")
Look.bronzeDark = hex("#4E3A24")
Look.copper = hex("#B87333")
Look.verdigris = hex("#5E8C7A")
Look.steel = S.steelBrushed
Look.steelDark = hex("#2C2F33")
Look.iron = hex("#1C1E21")
Look.aluminum = hex("#C9CDD2")
Look.white = S.white

-- glass (opaque Glass material boxes read as reflective curtain walls)
Look.glass = S.glass
Look.glassDark = S.glassDark
Look.glassTint = S.glassTint
Look.glassNavy = hex("#22374F")
Look.glassSilver = hex("#9DB2C1")
Look.glassGreen = hex("#4F7F7A")
Look.glassTeal = hex("#2D5C63")
Look.glassSmoke = hex("#1F2731")
Look.glassBronze = hex("#5E4F3E")
Look.glassBlack = hex("#14181D")
Look.lobbyGlass = hex("#CFE0E8")
Look.interior = hex("#1A2027")

-- light
Look.warmLight = S.warmLight
Look.coolLight = hex("#E4EEFA")
Look.lampGlow = hex("#FFD9A0")
Look.neonRed = hex("#FF4F5E")
Look.neonCyan = hex("#5CE1E6")
Look.neonGold = hex("#FFC864")

-- street
Look.asphalt = S.asphalt
Look.asphaltDark = hex("#1E2023")
Look.line = S.asphaltLine
Look.lineYellow = hex("#E3B935")
Look.curb = S.curb
Look.sidewalk = S.sidewalk
Look.plaza = hex("#9C9A95")
Look.plazaDark = hex("#6E6D6A")
Look.planter = S.planter
Look.foliage = S.foliage
Look.foliageLight = S.foliageLight
Look.foliageDark = hex("#2F5230")
Look.trunk = hex("#4A3828")
Look.soil = hex("#3A2A1E")
Look.water = hex("#5A8CA8")
Look.awningGreen = S.awningGreen
Look.awningRed = S.awningRed
Look.navy = S.navy
Look.black = S.black
Look.screen = S.screenBlue
Look.walnut = S.walnut
Look.velvet = hex("#5A1A24")

return Look
