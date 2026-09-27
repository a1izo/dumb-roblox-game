-- Map 3: Tokyo District at night, 400 x 300 studs: a scramble crossing before a station with a
-- metro platform underneath, a department store and a covered shopping street, a river lined
-- with cherry trees (Terrain water, filled by SceneBuilder), and across it a yokocho of tiny bars
-- by the rail viaduct. Made in Blender (art/scripts/maps/venues/tokyo/); the layout lives in
-- Maps/Scenes/Tokyo/.

local SceneMap = require(script.Parent.SceneMap)

return SceneMap.new({ id = "TokyoDistrict", name = "Tokyo District", venue = "Tokyo" })
