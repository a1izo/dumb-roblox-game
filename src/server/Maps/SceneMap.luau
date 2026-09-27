-- A map made entirely in Blender: its geometry, gameplay layout (stations, spawns, sheets...),
-- spare spots and zones all come from the generated scene data in Maps/Scenes/<Venue>/, so
-- nothing about the map is written twice. build() puts up the imported scene, or the greybox
-- when the venue's FBX is not imported (SceneBuilder).

local SceneBuilder = require(script.Parent.SceneBuilder)

local SceneMap = {}

export type Spec = { id: string, name: string, venue: string }

function SceneMap.new(spec: Spec)
	local map = {}
	map.id = spec.id
	map.name = spec.name
	map.venue = spec.venue

	-- The gameplay contract (see MapContract): the scene's layout, with its spare spots and zones.
	function map.layout()
		local data = SceneBuilder.data(spec.venue)
		assert(
			data,
			"no scene data for " .. spec.venue .. " (run art/scripts/run_maps.py -- " .. spec.venue .. " --export)"
		)
		return data.layout
	end

	function map.build(b)
		SceneBuilder.build(b, spec.venue)
		return map.layout()
	end

	return map
end

return SceneMap
