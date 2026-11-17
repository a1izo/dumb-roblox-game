--!strict
-- Steam and smoke in Tokyo (graphics plan, phase 13): off the ramen bar's counter, where the bowls are, and a thin
-- smoke off each yakitori grill. A soft, slow rising wisp from a holder part standing on the prop; no light, no sound.
-- Budget (VFX plan, part 9, a world loop): at most four sources alive at once, about three particles each, the
-- nearest four within reach; every rate goes through Emit.share(). Nothing under Low quality or once particles are cut;
-- under Reduce motion the wisps stay but stop drifting sideways and rise slower.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelCatalog")) :: any
local Util = require(script.Parent.Util)

local Steam = {}

type Source = { key: string, at: { { number } }, steam: boolean } -- where on the prop, as fractions of its width and height

-- Where each prop gives off its wisp: {sideways as a share of its width, up as a share of its height, depth as a share of its depth}.
local SOURCES: { Source } = {
	{ key = "RamenCounter", at = { { -0.28, 1.0, 0.1 }, { 0.12, 1.0, 0.1 } }, steam = true },
	{ key = "YakitoriGrill", at = { { 0, 1.0, 0 } }, steam = false },
}

local MOST = 4 -- sources alive at once
local REACH = 48
local PICK = 0.5
local RATE = 0.9 -- particles a second for one source, before Emit.share()

type Item = { emitter: ParticleEmitter, at: Vector3, on: boolean }

local function emitterOn(holder: Part, texture: string, steam: boolean): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(if steam then Color3.fromRGB(226, 228, 236) else Color3.fromRGB(176, 176, 182))
	emitter.LightEmission = 0
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if steam then 1.1 else 0.7),
		NumberSequenceKeypoint.new(1, if steam then 4.4 else 3),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, if steam then 0.84 else 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(3, 4)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(1.1, 1.8)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Acceleration = Vector3.new(0.12, 0.2, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-14, 14)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = holder
	return emitter
end

function Steam.build(index: Util.Index, _mapId: string): Util.Built?
	local texture = Util.glow()
	if texture == "" then
		return nil -- (the soft glow is not loaded: left out for this map)
	end
	local items: { Item } = {}
	local holders: { Part } = {}
	for _, source in ipairs(SOURCES) do
		local info = Catalog[source.key]
		for _, model in ipairs(index.props[source.key] or {}) do
			if info then
				local scale = model:GetScale()
				local size = Vector3.new(info.size[1], info.size[2], info.size[3]) * scale
				local pivot = model:GetPivot()
				for _, spot in ipairs(source.at) do
					local lift = if info.pivot == "bottom" then spot[2] * size.Y else (spot[2] - 0.5) * size.Y
					local cframe = pivot * CFrame.new(spot[1] * size.X, lift + 0.15, spot[3] * size.Z)
					local holder = Util.holder(cframe, Vector3.new(0.6, 0.2, 0.6), "SteamHolder")
					table.insert(holders, holder)
					table.insert(
						items,
						{ emitter = emitterOn(holder, texture, source.steam), at = cframe.Position, on = false }
					)
				end
			end
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
			local near: { { item: Item, d: number } } = {}
			for _, item in ipairs(items) do
				local d = (item.at - env.eye).Magnitude
				if d <= REACH and env.particles then
					table.insert(near, { item = item, d = d })
				end
				item.on = false
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
			for i = 1, math.min(MOST, #near) do
				near[i].item.on = true
			end
			for _, item in ipairs(items) do
				item.emitter.Rate = if item.on then RATE * env.share * (if env.reduced then 0.6 else 1) else 0
				item.emitter.Speed = if env.reduced then NumberRange.new(0.6, 1) else NumberRange.new(1.1, 1.8)
				item.emitter.Acceleration = if env.reduced then Vector3.new(0, 0.1, 0) else Vector3.new(0.12, 0.2, 0)
			end
		end,
		destroy = function()
			for _, holder in ipairs(holders) do
				holder:Destroy()
			end
		end,
	}
end

local kind: Util.Kind = { name = "steam", maps = { "TokyoDistrict" }, build = Steam.build }
return kind
