--!strict
-- OfficeFloorsA (officesA; design v3 §14, §19 M1; contracts §11): department floor templates, baked into
-- build/Templates.rbxm (ServerStorage.FirmTemplates) and cloned per company at runtime by OfficeService.
--
--   build(templateId, parent?) -> Model     the template built around the origin (World.TEMPLATE_HALF bounds)
--     "ib"                                  the Investment Banking floor in the owner's reference-photo style
--     "st" | "er" | "corpbank"              clean placeholder floors "under renovation" with every marker
--   TEMPLATES                               the template ids this module builds (= Config/World.templates entry)
--
-- Every floor shares one plan (Layout) and one set of slot/marker builders (Desks, Offices, Rooms, Core); a Style
-- decides the look, so a later track adds a style (and any bespoke dressing) without touching the markers.

local Floor = require(script.Floor)
local Geo = require(script.Geo)
local Placeholder = require(script.Placeholder)
local Style = require(script.Style)

local OfficeFloorsA = {}

OfficeFloorsA.TEMPLATES = { "ib", "st", "er", "corpbank" }

function OfficeFloorsA.build(templateId: string, parent: Instance?): Model
	local root: Model
	if templateId == "ib" then
		root = Floor.build("ib", nil, Style.ib)
	elseif Placeholder.supports(templateId) then
		root = Placeholder.build(templateId, nil)
	else
		error("OfficeFloorsA: unknown template " .. tostring(templateId), 2)
	end
	Geo.settle(root)
	root.Parent = parent
	return root
end

return OfficeFloorsA
