-- Who collides with whom.
--   Default       : the world and living characters
--   Ragdoll       : bodies of the dead; they rest on the world but do not shove anyone
--   Specters      : ghosts; they pass through everything except their own bounds
--   SpecterBounds : invisible boxes around each venue that keep ghosts inside

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.RAGDOLL = "Ragdoll"
CollisionGroups.SPECTERS = "Specters"
CollisionGroups.BOUNDS = "SpecterBounds"

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

function CollisionGroups.init()
	for _, name in ipairs({ CollisionGroups.RAGDOLL, CollisionGroups.SPECTERS, CollisionGroups.BOUNDS }) do
		register(name)
	end
	local set = function(a: string, b: string, collide: boolean)
		PhysicsService:CollisionGroupSetCollidable(a, b, collide)
	end
	set(CollisionGroups.RAGDOLL, "Default", true)
	set(CollisionGroups.RAGDOLL, CollisionGroups.RAGDOLL, true)
	set(CollisionGroups.SPECTERS, "Default", false)
	set(CollisionGroups.SPECTERS, CollisionGroups.SPECTERS, false)
	set(CollisionGroups.SPECTERS, CollisionGroups.RAGDOLL, false)
	set(CollisionGroups.SPECTERS, CollisionGroups.BOUNDS, true)
	set(CollisionGroups.BOUNDS, "Default", false)
	set(CollisionGroups.BOUNDS, CollisionGroups.RAGDOLL, false)
	set(CollisionGroups.BOUNDS, CollisionGroups.BOUNDS, false)
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
