-- The rules every map must keep so the game works on it, whatever it looks like.
--   validateLayout(layout)  pure checks on a map's layout() data (runs as a spec)
--   validateBuilt(info)     checks on the built map in the world (runs in Studio after each
--                           build): tags, attributes, reachable desks, clear sight lines to
--                           the stations, and sheets resting on something.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapContract = {}

local STATION_TYPES = { Camera = true, Fingerprint = true, Phone = true }

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
	if #stations ~= 8 then
		fail("needs exactly 8 stations, has " .. #stations)
	end
	local names = {}
	for index, station in ipairs(stations) do
		if not STATION_TYPES[station.type] then
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
	local counts = { Camera = 0, Fingerprint = 0, Phone = 0 }
	for _, station in ipairs(stations) do
		if counts[station.type] then
			counts[station.type] += 1
		end
	end
	for kind, count in pairs(counts) do
		if count < 2 then
			fail("needs at least 2 " .. kind .. " stations")
		end
	end
	if #(layout.spawns or {}) < Config.MAX_PLAYERS then
		fail("needs at least " .. Config.MAX_PLAYERS .. " spawns")
	end
	if #(layout.sheets or {}) ~= 4 then
		fail("needs exactly 4 paper sheets")
	end
	local drops = layout.dropPoints or {}
	if #drops ~= 3 then
		fail("needs exactly 3 drop points")
	end
	for index, drop in ipairs(drops) do
		if type(drop.name) ~= "string" or drop.name == "" then
			fail("drop point " .. index .. " has no name")
		end
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
	for _, drop in ipairs(info.dropPoints or {}) do
		if not drop.part:HasTag("LDropPoint") then
			fail(drop.name .. ": drop point is missing its tag")
		end
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
