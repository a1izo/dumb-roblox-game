-- The rules every map must keep so the game works on it, whatever it looks like.
--   validateLayout(layout)  pure checks on a map's layout() data (runs as a spec)
--   validateCrowd(layout)   the same for a map's crowd walks and car lanes (Tokyo's scramble)
--   validateBuilt(info)     checks on the built map in the world (runs in Studio after each
--                           build): tags, attributes, reachable desks, clear sight lines to
--                           the stations, and sheets resting on something.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapSync = require(Shared:WaitForChild("MapSync"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))

local MapContract = {}

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value
end

function MapContract.validateLayout(layout: any): { string }
	local problems = {}
	local function fail(text: string)
		table.insert(problems, text)
	end
	if type(layout) ~= "table" then
		return { "layout is not a table" }
	end
	local stations = layout.stations or {}
	if #stations ~= TaskTypes.STATIONS_PER_MAP then
		fail(string.format("needs exactly %d stations, has %d", TaskTypes.STATIONS_PER_MAP, #stations))
	end
	local names = {}
	for index, station in ipairs(stations) do
		if not TaskTypes.exists(station.type) then
			fail("station " .. index .. " has an unknown type " .. tostring(station.type))
		end
		if type(station.name) ~= "string" or station.name == "" then
			fail("station " .. index .. " has no name")
		elseif names[station.name] then
			fail("two stations are called " .. station.name)
		end
		names[station.name or ""] = true
		if not (isNumber(station.x) and isNumber(station.z) and isNumber(station.rot)) then
			fail("station " .. index .. " needs x, z and rot")
		end
	end
	local counts = {}
	for _, id in ipairs(TaskTypes.LIST) do
		counts[id] = 0
	end
	for _, station in ipairs(stations) do
		if counts[station.type] then
			counts[station.type] += 1
		end
	end
	for kind, count in pairs(counts) do
		if count < TaskTypes.MIN_PER_MAP then
			fail(string.format("needs at least %d %s stations", TaskTypes.MIN_PER_MAP, kind))
		end
	end
	if #(layout.spawns or {}) < Config.MAX_PLAYERS then
		fail("needs at least " .. Config.MAX_PLAYERS .. " spawns")
	end
	-- Four sheets at least; a big map spreads a few more over its ground.
	if #(layout.sheets or {}) < 4 then
		fail("needs at least 4 paper sheets")
	end
	if #(layout.hoods or {}) < 1 then
		fail("needs at least one hood")
	end
	if #(layout.areas or {}) < 6 then
		fail("needs at least 6 named areas")
	end
	if type(layout.tipBox) ~= "table" then
		fail("needs a tip box")
	end
	if type(layout.board) ~= "table" then
		fail("needs an evidence board")
	end
	return problems
end

-- Spare spots (maps made in Blender carry extra spots of each kind for a later change of the
-- counts): known station types, names unique across the active and spare stations, and every
-- spot with its coordinates.
function MapContract.validateSpare(layout: any): { string }
	local problems = {}
	local spare = layout.spare
	if spare == nil then
		return problems
	end
	local names = {}
	for _, station in ipairs(layout.stations or {}) do
		names[station.name] = true
	end
	for index, station in ipairs(spare.stations or {}) do
		if not TaskTypes.exists(station.type) then
			table.insert(problems, "spare station " .. index .. " has an unknown type " .. tostring(station.type))
		end
		if names[station.name] then
			table.insert(problems, "two stations are called " .. tostring(station.name))
		end
		names[station.name or ""] = true
		if not (isNumber(station.x) and isNumber(station.z) and isNumber(station.rot)) then
			table.insert(problems, "spare station " .. index .. " needs x, z and rot")
		end
	end
	for _, kind in ipairs({ "spawns", "sheets", "hoods", "areas" }) do
		for index, spot in ipairs(spare[kind] or {}) do
			if not (isNumber(spot.x) and isNumber(spot.z)) then
				table.insert(problems, "spare " .. kind .. " " .. index .. " needs x and z")
			end
		end
	end
	local areaNames = {}
	for _, area in ipairs(layout.areas or {}) do
		if areaNames[area.name] then
			table.insert(problems, "two areas are called " .. tostring(area.name))
		end
		areaNames[area.name] = true
	end
	return problems
end

-- A map with a crowd and cars (Tokyo's scramble: layout.crowd and layout.traffic): every link joins two
-- nodes that exist, a crossing runs from kerb to kerb, the walks hang together (a walker can get from
-- any node to any other), nobody walks or stands on top of a station's worker or a spawn, and every
-- lane has its stop line somewhere along it. A map without them has nothing to keep.
function MapContract.validateCrowd(layout: any): { string }
	local problems = {}
	local function fail(text: string)
		table.insert(problems, text)
	end
	local crowd = layout.crowd
	if crowd ~= nil then
		local nodes, links = crowd.nodes or {}, crowd.links or {}
		local keepClear = {}
		for _, group in ipairs({ layout, layout.spare or {} }) do
			for _, station in ipairs(group.stations or {}) do
				table.insert(
					keepClear,
					{ x = station.x, z = station.z, r = 10, what = "station " .. tostring(station.name) }
				)
			end
			for _, spawn in ipairs(group.spawns or {}) do
				table.insert(keepClear, { x = spawn.x, z = spawn.z, r = 4, what = "a spawn" })
			end
		end
		local joined = {}
		for index, node in ipairs(nodes) do
			joined[index] = {}
			if not (isNumber(node.x) and isNumber(node.z)) then
				fail("crowd node " .. index .. " needs x and z")
			elseif node.kind ~= "walk" and node.kind ~= "kerb" then
				fail("crowd node " .. index .. " has an unknown kind " .. tostring(node.kind))
			else
				for _, spot in ipairs(keepClear) do
					if isNumber(spot.x) and isNumber(spot.z) and (node.y or 0) == 0 then
						if math.sqrt((spot.x - node.x) ^ 2 + (spot.z - node.z) ^ 2) < spot.r then
							fail(string.format("crowd node %d is within %d studs of %s", index, spot.r, spot.what))
						end
					end
				end
			end
		end
		for index, link in ipairs(links) do
			local a, b = nodes[link.a], nodes[link.b]
			if not a or not b or link.a == link.b then
				fail("crowd link " .. index .. " does not join two nodes")
			else
				table.insert(joined[link.a], link.b)
				table.insert(joined[link.b], link.a)
				if link.kind == "crossing" then
					if a.kind ~= "kerb" or b.kind ~= "kerb" then
						fail("crowd link " .. index .. " crosses the road from somewhere that is not a kerb")
					end
				elseif link.kind ~= "walk" then
					fail("crowd link " .. index .. " has an unknown kind " .. tostring(link.kind))
				end
				if not isNumber(link.width) or link.width <= 0 then
					fail("crowd link " .. index .. " needs a width")
				end
			end
		end
		-- One piece: everything is reached from the first node.
		local reached, queue = { [1] = true }, { 1 }
		while #queue > 0 do
			local at = table.remove(queue) :: number
			for _, other in ipairs(joined[at] or {}) do
				if not reached[other] then
					reached[other] = true
					table.insert(queue, other)
				end
			end
		end
		for index in ipairs(nodes) do
			if not reached[index] then
				fail("crowd node " .. index .. " cannot be reached from the others")
			end
		end
		for index, post in ipairs(crowd.posts or {}) do
			if not (isNumber(post.x) and isNumber(post.z) and isNumber(post.rot)) then
				fail("crowd post " .. index .. " needs x, z and rot")
			end
		end
	end
	for index, lane in ipairs((layout.traffic or {}).lanes or {}) do
		local points = lane.points or {}
		local length = 0
		for i = 2, #points do
			length += math.sqrt((points[i][1] - points[i - 1][1]) ^ 2 + (points[i][2] - points[i - 1][2]) ^ 2)
		end
		if #points < 2 then
			fail("lane " .. index .. " needs at least two points")
		elseif not isNumber(lane.stop) or lane.stop <= 0 or lane.stop >= length then
			fail("lane " .. index .. " has no stop line along it")
		end
		if lane.road ~= nil and lane.road ~= 1 and lane.road ~= 2 then
			fail("lane " .. index .. " belongs to an unknown road " .. tostring(lane.road))
		end
		for _, key in ipairs(lane.kinds or {}) do
			if not table.find(MapSync.CARS, key) then
				fail("lane " .. index .. " wants a car the game does not have: " .. tostring(key))
			end
		end
	end
	return problems
end

-- How many of 8 points around a station (at head height, 9 studs out) can see its screen.
local function visibleFrom(screen: BasePart, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local target = screen.Position
	local seen = 0
	for index = 1, 8 do
		local angle = (index - 1) / 8 * math.pi * 2
		local from = target + Vector3.new(math.sin(angle) * 9, 0, math.cos(angle) * 9)
		from = Vector3.new(from.X, target.Y, from.Z)
		local result = workspace:Raycast(from, target - from, params)
		if not result or result.Instance == screen or result.Instance:IsDescendantOf(screen.Parent :: Instance) then
			seen += 1
		end
	end
	return seen
end

function MapContract.validateBuilt(info: any): { string }
	local problems = {}
	local function fail(text: string)
		table.insert(problems, text)
	end
	for _, station in ipairs(info.stations or {}) do
		local desk = station.desk
		if not desk:HasTag("LStation") or desk:GetAttribute("StationId") ~= station.id then
			fail(station.name .. ": desk is missing its tag or id")
		end
		if not station.screen:HasTag("LStationScreen") then
			fail(station.name .. ": screen is missing its tag")
		end
		if visibleFrom(station.screen, {}) < 3 then
			fail(station.name .. ": the screen can be seen from fewer than 3 of 8 sides")
		end
	end
	if not info.tipBox or not info.tipBox.part:HasTag("LTipBox") then
		fail("the tip box is missing its tag")
	end
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Include
	down.FilterDescendantsInstances = { info.model }
	for _, sheet in ipairs(info.sheets or {}) do
		local hit = workspace:Raycast(sheet.position + Vector3.new(0, 0.5, 0), Vector3.new(0, -2, 0), down)
		if not hit then
			fail("sheet " .. sheet.id .. " is floating")
		end
	end
	for _, item in ipairs(info.model:GetDescendants()) do
		if item:IsA("BasePart") and item.Transparency >= 0.3 and item.CanQuery and item.Transparency < 1 then
			if item.Material == Enum.Material.Glass then
				fail("glass part " .. item:GetFullName() .. " blocks sight lines (set CanQuery = false)")
			end
		end
	end
	for _, text in ipairs(MapContract.leftovers(info.model)) do
		fail(text)
	end
	return problems
end

-- Visible part-built pieces left inside a Blender prop (a prop dresses a gameplay part as a
-- model named "Visual" under it; the stand-in's extras must be hidden when it does). Screens
-- tagged LStationScreen are meant to show through the console's housing.
function MapContract.leftovers(root: Instance): { string }
	local found = {}
	local visuals = {}
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") and item.Name == "Visual" and item.Parent and item.Parent:IsA("BasePart") then
			table.insert(visuals, item)
		end
	end
	for _, visual in ipairs(visuals) do
		local cf, size = visual:GetBoundingBox()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { root }
		for _, part in ipairs(workspace:GetPartBoundsInBox(cf, size * 0.9, params)) do
			local isStandIn = part.ClassName == "Part"
				and part.Transparency < 1
				and part ~= visual.Parent
				and not part:IsDescendantOf(visual)
				and not part:HasTag("LStationScreen")
				and part.Size.Magnitude < size.Magnitude * 1.5
			if isStandIn then
				table.insert(
					found,
					"part " .. part:GetFullName() .. " shows through the " .. visual.Parent.Name .. " prop"
				)
			end
		end
	end
	return found
end

return MapContract
