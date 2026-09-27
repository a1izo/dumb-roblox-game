-- Map 3: Tokyo District at night, about 1000 x 800 studs: a station quarter with a metro
-- platform underneath, a shopping quarter round a department store and a covered arcade, a
-- sunken yokocho of tiny bars by the viaduct, and a residential hill climbing to a shrine,
-- with a canal across the south. Made in Blender (art/scripts/maps/venues/tokyo/); the layout
-- lives in Maps/Scenes/Tokyo/.

local SceneMap = require(script.Parent.SceneMap)

return SceneMap.new({ id = "TokyoDistrict", name = "Tokyo District", venue = "Tokyo" })
