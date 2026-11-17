--!strict
-- Breath in the cold (graphics plan, phase 13): on the University's snowy grounds a faint puff leaves the mouth of
-- each person near the camera now and then, a few seconds apart, and fades as it drifts. Only outdoors (a person with
-- a roof over their head breathes no cloud), only the nearest three characters within 40 studs, never your own when
-- the camera is that close to it, about five particles a puff; the rate goes through Emit.share(). Nothing in Low
-- quality or once particles are cut; Reduce motion keeps the puffs and makes them smaller and slower.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingController = require(script.Parent.Parent.LightingController)
local Util = require(script.Parent.Util)
local LifePatterns = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LifePatterns"))

local Breath = {}

local MOST = 3
local REACH = 40
local TOO_CLOSE = 5 -- studs: your own mouth in front of the camera is not drawn
local PICK = 0.5
local ROOF = 40 -- how far up a roof is looked for over a head
local PERIOD = 3.8 -- seconds between breaths
local EXHALE = 0.8 -- seconds a breath lasts
local RATE = 6 -- particles a second while breathing out, before Emit.share()

type Item = { head: BasePart, emitter: ParticleEmitter, attachment: Attachment, phase: number, on: boolean }

local function newItem(head: BasePart, texture: string, userId: number): Item
	local attachment = Instance.new("Attachment")
	attachment.Name = "BreathMouth"
	attachment.Position = Vector3.new(0, -0.28, -0.62) -- (the head faces -Z: the mouth is low and in front)
	attachment.Parent = head
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Breath"
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(Color3.fromRGB(232, 238, 248))
	emitter.LightEmission = 0.1
	emitter.LightInfluence = 0.5
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1.5),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.3, 1.8)
	emitter.Speed = NumberRange.new(1.1, 1.7)
	emitter.Drag = 1.6
	emitter.Acceleration = Vector3.new(0, 0.35, 0)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = attachment
	return { head = head, emitter = emitter, attachment = attachment, phase = (userId % 97) / 97 * PERIOD, on = false }
end

function Breath.build(_index: Util.Index, _mapId: string): Util.Built?
	local texture = Util.glow()
	if texture == "" then
		return nil
	end
	local items: { [Instance]: Item } = {} -- by head
	local pickedAt = -math.huge
	local chosen: { [Instance]: boolean } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function drop(head: Instance)
		local item = items[head]
		if item then
			item.attachment:Destroy()
			items[head] = nil
		end
	end

	local function pick(env: Util.Env)
		local outdoors = LightingController.zone() == nil
		local near: { { head: BasePart, userId: number, d: number } } = {}
		if outdoors and env.particles then
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local head = if character then character:FindFirstChild("Head") else nil
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				if head and head:IsA("BasePart") and humanoid and humanoid.Health > 0 then
					local d = (head.Position - env.eye).Magnitude
					if d <= REACH and d >= TOO_CLOSE then
						params.FilterDescendantsInstances = { character :: Instance }
						-- (a roof, an awning or a tree's crown over the head: no cloud)
						local roofed = workspace:Raycast(head.Position, Vector3.new(0, ROOF, 0), params)
						if not roofed then
							table.insert(near, { head = head, userId = player.UserId, d = d })
						end
					end
				end
			end
		end
		table.sort(near, function(a, b)
			return a.d < b.d
		end)
		table.clear(chosen)
		for i = 1, math.min(MOST, #near) do
			local entry = near[i]
			chosen[entry.head] = true
			if not items[entry.head] then
				items[entry.head] = newItem(entry.head, texture, entry.userId)
			end
		end
		for head in pairs(items) do
			if not chosen[head] or not head.Parent then
				drop(head)
			end
		end
	end

	return {
		step = function(env: Util.Env)
			if env.now - pickedAt >= PICK then
				pickedAt = env.now
				pick(env)
			end
			local small = if env.reduced then 0.6 else 1
			for _, item in pairs(items) do
				local on = LifePatterns.blink(env.now, PERIOD, EXHALE / PERIOD, item.phase) == 1
				if on ~= item.on then
					item.on = on
					item.emitter.Rate = if on then RATE * env.share * small else 0
				end
			end
		end,
		destroy = function()
			for head in pairs(items) do
				drop(head)
			end
		end,
	}
end

local kind: Util.Kind = { name = "breath", maps = { "UniversityCampus" }, build = Breath.build }
return kind
