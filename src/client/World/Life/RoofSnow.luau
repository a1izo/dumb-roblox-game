--!strict
-- Snow sliding off a roof edge (graphics plan, phase 13): now and then, on the University grounds, a clump of snow lets
-- go of a building's eave near the camera and falls to the ground in a short burst of flakes. The map's lighting boxes
-- (LLookZone, "UniversityCampus_Inside") give each building's footprint and height; the edge spots are points a little
-- outside those walls at roof height with a long clear drop below them (a wall shared with the next building has no
-- drop and is left out), found once when the map is sorted out. One emitter does it all, moved from edge to edge:
-- about a dozen flakes a slide, one slide every five to nine seconds, the burst through Emit.share(). Nothing in Low
-- quality or once particles are cut; under Reduce motion the slides are rarer.

local Util = require(script.Parent.Util)

local RoofSnow = {}

local LOOK = "UniversityCampus_Inside"
local OUT = 1.8 -- studs outside the box's wall (the box is the inside of the building)
local SIDES = { 0.25, 0.5, 0.75 } -- along each side
local MIN_DROP = 8
local REACH = 75
local BURST = 12

type Spot = { at: Vector3, out: Vector3 }

function RoofSnow.build(index: Util.Index, _mapId: string): Util.Built?
	local texture = Util.flake()
	if texture == "" then
		return nil
	end
	local params = Util.rayParams()
	local spots: { Spot } = {}
	for _, zone in ipairs(index.zones) do
		local size = zone.Size
		local top = zone.Position.Y + size.Y / 2
		if zone:GetAttribute("Preset") == LOOK and top >= 7 and top <= 30 then
			-- the four walls: a unit pointing out, and the half-length of the wall along its way
			local walls = {
				{ out = Vector3.new(1, 0, 0), along = Vector3.new(0, 0, 1), half = size.Z / 2, reach = size.X / 2 },
				{ out = Vector3.new(-1, 0, 0), along = Vector3.new(0, 0, 1), half = size.Z / 2, reach = size.X / 2 },
				{ out = Vector3.new(0, 0, 1), along = Vector3.new(1, 0, 0), half = size.X / 2, reach = size.Z / 2 },
				{ out = Vector3.new(0, 0, -1), along = Vector3.new(1, 0, 0), half = size.X / 2, reach = size.Z / 2 },
			}
			for _, wall in ipairs(walls) do
				for _, share in ipairs(SIDES) do
					local flat = zone.Position
						+ wall.out * (wall.reach + OUT)
						+ wall.along * ((share * 2 - 1) * wall.half)
					local from = Vector3.new(flat.X, top - 0.5, flat.Z)
					local hit = workspace:Raycast(from, Vector3.new(0, -40, 0), params)
					local drop = if hit then from.Y - hit.Position.Y else 40
					if drop >= MIN_DROP then
						table.insert(spots, { at = Vector3.new(flat.X, top, flat.Z), out = wall.out })
					end
				end
			end
		end
	end
	if #spots == 0 then
		return nil
	end
	local holder = Util.holder(CFrame.new(spots[1].at), Vector3.new(2, 0.2, 0.2), "RoofSnowHolder")
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(Color3.fromRGB(240, 244, 252))
	emitter.LightEmission = 0.15
	emitter.LightInfluence = 0.4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.1, 1.5)
	emitter.Speed = NumberRange.new(1.2, 2.6)
	emitter.Acceleration = Vector3.new(0, -26, 0)
	emitter.SpreadAngle = Vector2.new(22, 22)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = holder
	local nextAt = os.clock() + 3
	return {
		step = function(env: Util.Env)
			if env.now < nextAt then
				return
			end
			nextAt = env.now + (5 + math.random() * 4) * (if env.reduced then 1.7 else 1)
			if not env.particles then
				return
			end
			local near: { Spot } = {}
			for _, spot in ipairs(spots) do
				if (spot.at - env.eye).Magnitude <= REACH then
					table.insert(near, spot)
				end
			end
			if #near == 0 then
				return
			end
			local spot = near[math.random(1, #near)]
			-- (the holder looks outward: its front is where the clump goes)
			holder.CFrame = CFrame.lookAt(spot.at, spot.at + spot.out)
			emitter:Emit(math.max(3, math.floor(BURST * env.share + 0.5)))
		end,
		destroy = function()
			holder:Destroy()
		end,
	}
end

local kind: Util.Kind = { name = "roofSnow", maps = { "UniversityCampus" }, build = RoofSnow.build }
return kind
