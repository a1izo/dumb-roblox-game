-- Where the players' avatars perform in the intro: marks found on the built map (in front of
-- station desks, in the open part of each area, on a free spot for a chair, with the back to a
-- wall), checked for room, and a cast that gives every player a mark and something to do.
-- The cast is chosen on the server so every client shows the same scene; it never depends on
-- roles (Shared/Presentation/Activities).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Activities =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"):WaitForChild("Activities"))

local Staging = {}

export type Mark = { cf: CFrame, kind: string, area: string, outdoor: boolean }

local function characters(): { Instance }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("LBotCharacter")) do
		table.insert(list, model)
	end
	return list
end

local function rayParams(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = characters()
	p.RespectCanCollide = true
	return p
end

local function overlapParams(): OverlapParams
	local p = OverlapParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = characters()
	p.RespectCanCollide = true
	return p
end

-- The floor under a point, or nil when there is none nearby.
local function floorAt(point: Vector3): Vector3?
	local hit = workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), rayParams())
	return if hit then hit.Position else nil
end

-- True when a body (and a chair behind it for seats) fits on the mark.
local function roomy(cf: CFrame, seat: boolean): boolean
	local size = if seat then Vector3.new(2.6, 4.6, 3.6) else Vector3.new(2.2, 4.6, 1.8)
	local centre = cf * CFrame.new(0, 2.7, if seat then 0.5 else 0)
	return #workspace:GetPartBoundsInBox(centre, size, overlapParams()) == 0
end

local function outdoors(point: Vector3): boolean
	return workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, 80, 0), rayParams()) == nil
end

local function add(list: { Mark }, position: Vector3, look: Vector3, kind: string, area: string)
	local floor = floorAt(position)
	if not floor then
		return
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local cf = CFrame.lookAt(floor, floor + flat.Unit)
	if roomy(cf, kind == "seat") then
		table.insert(list, { cf = cf, kind = kind, area = area, outdoor = outdoors(floor) })
	end
end

-- The name of the area closest to a point.
local function areaName(map, point: Vector3): string
	local best, bestDistance = "", math.huge
	for _, area in ipairs(map.areas or {}) do
		local distance = (area.position - point).Magnitude
		if distance < bestDistance then
			best, bestDistance = area.name, distance
		end
	end
	return best
end

function Staging.marks(map, rng: Random): { Mark }
	local marks: { Mark } = {}
	for _, station in ipairs(map.stations or {}) do
		local desk = station.desk
		if desk and desk.Parent then
			-- Where the worker stands, facing the desk.
			local spot = (desk.CFrame * CFrame.new(0, 0, -2.8)).Position
			add(marks, spot, desk.Position - spot, "desk", areaName(map, desk.Position))
		end
	end
	for _, area in ipairs(map.areas or {}) do
		local centre = area.position
		local yaw = rng:NextNumber() * math.pi * 2
		local look = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		add(marks, centre + look * 2, -look, "stand", area.name)
		local side = Vector3.new(-look.Z, 0, look.X)
		add(marks, centre + side * 5, side, "seat", area.name)
		-- Back to the nearest wall within reach.
		local params = rayParams()
		for step = 0, 7 do
			local angle = yaw + step * math.pi / 4
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local hit = workspace:Raycast(centre + Vector3.new(0, 3, 0), dir * 16, params)
			if hit and hit.Distance > 4 then
				add(marks, hit.Position - dir * 1.3 - Vector3.new(0, 3, 0), -dir, "wall", area.name)
				break
			end
		end
	end
	return marks
end

export type Role = {
	userId: number,
	cf: CFrame,
	kind: string,
	clip: string,
	props: { string },
	caption: string,
	area: string,
}

-- Gives every player a mark and an activity. Returns the cast and up to four vignettes (indexes
-- into the cast) for the camera to visit.
function Staging.cast(map, userIds: { number }, rng: Random): ({ Role }, { number })
	local marks = Staging.marks(map, rng)
	for i = #marks, 2, -1 do
		local j = rng:NextInteger(1, i)
		marks[i], marks[j] = marks[j], marks[i]
	end
	-- Take marks kind by kind in turn, so the scene mixes desks, chairs, walls and the open floor.
	local byKind: { [string]: { Mark } } = {}
	for _, mark in ipairs(marks) do
		byKind[mark.kind] = byKind[mark.kind] or {}
		table.insert(byKind[mark.kind], mark)
	end
	local order = { "desk", "stand", "seat", "wall" }
	local sorted = table.clone(userIds)
	table.sort(sorted)
	local cast: { Role } = {}
	local usedClips: { [string]: boolean } = {}
	local turn = rng:NextInteger(0, #order - 1)
	for _, userId in ipairs(sorted) do
		local mark: Mark? = nil
		for _ = 1, #order do
			turn = turn % #order + 1
			local pool = byKind[order[turn]]
			if pool and #pool > 0 then
				mark = table.remove(pool)
				break
			end
		end
		if not mark then
			break
		end
		local options = {}
		for _, activity in ipairs(Activities.BY_KIND[mark.kind]) do
			if not activity.outdoor or mark.outdoor then
				table.insert(options, activity)
			end
		end
		local fresh = {}
		for _, activity in ipairs(options) do
			if not usedClips[activity.clip] then
				table.insert(fresh, activity)
			end
		end
		local pool = if #fresh > 0 then fresh else options
		local activity = pool[rng:NextInteger(1, #pool)]
		usedClips[activity.clip] = true
		table.insert(cast, {
			userId = userId,
			cf = mark.cf,
			kind = mark.kind,
			clip = activity.clip,
			props = activity.props,
			caption = activity.caption,
			area = mark.area,
		})
	end
	-- Vignettes: up to four, different kinds first.
	local vignettes = {}
	local seenKinds = {}
	for index, role in ipairs(cast) do
		if #vignettes < 4 and not seenKinds[role.kind] then
			seenKinds[role.kind] = true
			table.insert(vignettes, index)
		end
	end
	for index in ipairs(cast) do
		if #vignettes >= 4 then
			break
		end
		if not table.find(vignettes, index) then
			table.insert(vignettes, index)
		end
	end
	return cast, vignettes
end

-- A neutral spot for the Grimoire to land: the floor of the area nearest the middle of the map.
function Staging.landmark(map): Vector3?
	local areas = map.areas or {}
	if #areas == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, area in ipairs(areas) do
		sum += area.position
	end
	local middle = sum / #areas
	local best, bestDistance = areas[1].position, math.huge
	for _, area in ipairs(areas) do
		local distance = (area.position - middle).Magnitude
		if distance < bestDistance then
			best, bestDistance = area.position, distance
		end
	end
	return floorAt(best) or best
end

return Staging
