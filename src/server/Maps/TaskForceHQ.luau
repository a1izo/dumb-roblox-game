-- Map 1: Agency HQ, the Agency's 38th and 39th floors of the Kagegaoka Central Tower at night: the
-- lobby under a double-height atrium, the bullpen, the interrogation suite behind its one-way
-- mirror, a grand stair up to the operations deck facing the video wall, the forensics lab, the
-- archive, the director's glass office; the city 440 studs below the windows. Made in Blender
-- (art/scripts/maps/venues/agency/); the layout lives in Maps/Scenes/Agency/.

local SceneMap = require(script.Parent.SceneMap)

return SceneMap.new({ id = "TaskForceHQ", name = "Bureau HQ", venue = "Agency" })
