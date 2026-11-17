--!strict
-- Rain dripping off Tokyo's awnings (graphics plan, phase 13). The map marks every awning and canopy with an unseen
-- box that shelters from rain (SceneBuilder, LRainCover); while it rains, a line of drops runs off the open edge of
-- each one near the camera and falls to the street. The open edge is the side no wall is on (found by a ray from the
-- box's middle, once). Within the world-loop budget: at most three awnings drip at once, about two drops alive each,
-- rates through Emit.share(). Nothing in Low quality, once particles are cut, or when it is not raining.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))
local LightingController = require(script.Parent.Parent.LightingController)
local Util = require(script.Parent.Util)

local Drips = {}

local MOST = 3
local REACH = 42
local PICK = 0.5
local RATE = 1.7 -- drops a second along one awning's edge, before Emit.share()
local WET = 0.15 -- how much rain it takes for them to drip
local FALL = 45 -- gravity on a drop, studs a second squared (the rain's own streaks fall as fast)

type Item = { cover: BasePart, edge: CFrame, width: number, holder: Part?, emitter: ParticleEmitter?, at: Vector3 }

-- The CFrame of the awning's open edge, its front pointing out: the side with no wall within a stud or so.
local function openEdge(cover: BasePart, params: RaycastParams): CFrame
	local size = cover.Size
	local middle = cover.CFrame * CFrame.new(0, -size.Y / 2 - 0.1, 0)
	local reach = size.Z / 2 + 0.7
	local front = workspace:Raycast(middle.Position, middle.LookVector * reach, params) -- (a part looks down its -Z)
	local back = workspace:Raycast(middle.Position, -middle.LookVector * reach, params)
	local turn = if front and not back then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	return middle * turn * CFrame.new(0, 0, -size.Z / 2)
end

local function emitterFor(item: Item, texture: string)
	local holder = Util.holder(item.edge, Vector3.new(item.width, 0.1, 0.1), "DripHolder")
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(Color3.fromRGB(204, 216, 238))
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0.5
	emitter.Size = NumberSequence.new(0.2)
	emitter.Squash = NumberSequence.new(3)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.45),
		NumberSequenceKeypoint.new(0.85, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.75, 0.95)
	emitter.Speed = NumberRange.new(0)
	emitter.Acceleration = Vector3.new(0, -FALL, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Rate = 0
	emitter.Parent = holder
	item.holder = holder
	item.emitter = emitter
end

function Drips.build(index: Util.Index, _mapId: string): Util.Built?
	local texture = Assets.texture("TokyoRain")
	if texture == "" then
		texture = Util.glow()
	end
	if texture == "" or #index.covers == 0 then
		return nil
	end
	local items: { Item } = {}
	local params = Util.rayParams()
	for _, cover in ipairs(index.covers) do
		-- (an awning: a long thin box up at the shop fronts, not a tree's crown or a canopy over a whole yard)
		local size = cover.Size
		if size.Y < 2 and size.Z <= 6 and cover.Position.Y > 6 then
			local edge = openEdge(cover, params)
			table.insert(
				items,
				{ cover = cover, edge = edge, width = size.X * 0.9, holder = nil, emitter = nil, at = edge.Position }
			)
		end
	end
	if #items == 0 then
		return nil
	end
	local pickedAt = -math.huge
	return {
		step = function(env: Util.Env)
			if env.now - pickedAt < PICK then
				return
			end
			pickedAt = env.now
			local wet = LightingController.preset().rain > WET and env.particles
			local near: { { item: Item, d: number } } = {}
			for _, item in ipairs(items) do
				local d = (item.at - env.eye).Magnitude
				if wet and d <= REACH then
					table.insert(near, { item = item, d = d })
				elseif item.emitter then
					item.emitter.Rate = 0
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
			for i, entry in ipairs(near) do
				local item = entry.item
				if i <= MOST then
					if not item.emitter then
						emitterFor(item, texture)
					end
					(item.emitter :: ParticleEmitter).Rate = RATE * env.share
				elseif item.emitter then
					item.emitter.Rate = 0
				end
			end
		end,
		destroy = function()
			for _, item in ipairs(items) do
				if item.holder then
					item.holder:Destroy()
				end
			end
		end,
	}
end

local kind: Util.Kind = { name = "drips", maps = { "TokyoDistrict" }, build = Drips.build }
return kind
