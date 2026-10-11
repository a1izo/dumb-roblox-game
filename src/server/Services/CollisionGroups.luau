-- Who collides with whom.
--   Default       : the world
--   Characters    : players' bodies (and the test bots'); they stand on the world and bump into each other
--   Away          : a dead player waiting in the lobby, hidden: they stand on the world and walk through people
--   Ragdoll       : bodies of the dead; they rest on the world but do not shove anyone
--   Specters      : ghosts and spectators; they fly, the world stops them, but they pass through bodies
--   SpecterBounds : invisible boxes around each venue that keep ghosts inside
--   Crowd         : the Tokyo crowd (drawn by each client): players bump into them, nothing else does
--   CrowdPass     : a crowd walker stepping through someone it could not get round; collides with nothing
--   Vehicles      : the Tokyo cars (drawn by each client); they brake for people instead of touching them

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.RAGDOLL = "Ragdoll"
CollisionGroups.SPECTERS = "Specters"
CollisionGroups.BOUNDS = "SpecterBounds"
CollisionGroups.CHARACTERS = "Characters"
CollisionGroups.AWAY = "Away"
CollisionGroups.CROWD = "Crowd"
CollisionGroups.CROWD_PASS = "CrowdPass"
CollisionGroups.VEHICLES = "Vehicles"

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

function CollisionGroups.init()
	for _, name in ipairs({
		CollisionGroups.RAGDOLL,
		CollisionGroups.SPECTERS,
		CollisionGroups.BOUNDS,
		CollisionGroups.CHARACTERS,
		CollisionGroups.AWAY,
		CollisionGroups.CROWD,
		CollisionGroups.CROWD_PASS,
		CollisionGroups.VEHICLES,
	}) do
		register(name)
	end
	local set = function(a: string, b: string, collide: boolean)
		PhysicsService:CollisionGroupSetCollidable(a, b, collide)
	end
	set(CollisionGroups.RAGDOLL, "Default", true)
	set(CollisionGroups.RAGDOLL, CollisionGroups.RAGDOLL, true)
	set(CollisionGroups.SPECTERS, "Default", true)
	set(CollisionGroups.SPECTERS, CollisionGroups.SPECTERS, false)
	set(CollisionGroups.SPECTERS, CollisionGroups.RAGDOLL, false)
	set(CollisionGroups.SPECTERS, CollisionGroups.BOUNDS, true)
	set(CollisionGroups.BOUNDS, "Default", false)
	set(CollisionGroups.BOUNDS, CollisionGroups.RAGDOLL, false)
	set(CollisionGroups.BOUNDS, CollisionGroups.BOUNDS, false)
	-- Bodies: like the world's own parts, except that the hidden (away) ones pass through the others.
	local CHARS, AWAY = CollisionGroups.CHARACTERS, CollisionGroups.AWAY
	set(CHARS, "Default", true)
	set(CHARS, CHARS, true)
	set(CHARS, CollisionGroups.RAGDOLL, true)
	set(CHARS, CollisionGroups.SPECTERS, false)
	set(CHARS, CollisionGroups.BOUNDS, false)
	set(AWAY, "Default", true)
	set(AWAY, CHARS, false)
	set(AWAY, AWAY, false)
	set(AWAY, CollisionGroups.RAGDOLL, false)
	set(AWAY, CollisionGroups.SPECTERS, false)
	set(AWAY, CollisionGroups.BOUNDS, false)
	-- The Tokyo crowd and cars: drawn by each client, moved by the server's maths, never by physics.
	local groups = { "Default", CHARS, AWAY, CollisionGroups.RAGDOLL, CollisionGroups.SPECTERS, CollisionGroups.BOUNDS }
	for _, group in ipairs(groups) do
		set(CollisionGroups.CROWD, group, group == CHARS)
		set(CollisionGroups.CROWD_PASS, group, false)
		set(CollisionGroups.VEHICLES, group, false)
	end
	for _, a in ipairs({ CollisionGroups.CROWD, CollisionGroups.CROWD_PASS, CollisionGroups.VEHICLES }) do
		for _, b in ipairs({ CollisionGroups.CROWD, CollisionGroups.CROWD_PASS, CollisionGroups.VEHICLES }) do
			set(a, b, false)
		end
	end
end

-- Keeps a body's parts (and parts added later) in `group`, leaving alone any part another service has
-- already put elsewhere (a ghost, a ragdoll) unless `force` is set.
function CollisionGroups.body(character: Model, group: string, force: boolean?)
	local function apply(item: Instance)
		if item:IsA("BasePart") then
			local current = item.CollisionGroup
			if force or current == "Default" or current == CollisionGroups.CHARACTERS then
				item.CollisionGroup = group
			end
		end
	end
	for _, item in ipairs(character:GetDescendants()) do
		apply(item)
	end
	return character.DescendantAdded:Connect(apply)
end

-- Puts every part of a model (and parts added later) in a group.
function CollisionGroups.assign(model: Instance, group: string)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CollisionGroup = group
		end
	end
end

return CollisionGroups
