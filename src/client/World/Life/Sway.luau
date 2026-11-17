--!strict
-- Things that hang and turn in Tokyo (graphics plan, phase 13): the shop curtains (noren) in the doorways, the paper
-- lanterns (chochin) and the strings of lanterns sway a few degrees about the point they hang from, swelling and
-- easing with the wind's own gusts, and the karaoke bars' mirror balls turn. Each is a placed prop (a model of its
-- own), so it is simply tilted about its top edge and put back: no part is added. Only the nearest few within
-- reach move; the rest wait where they were built. Under Reduce motion everything hangs still and the balls stop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("ModelCatalog")) :: any
local Util = require(script.Parent.Util)
local LifePatterns = require(Shared:WaitForChild("LifePatterns"))

local Sway = {}

type Rule = { amp: number, period: number, spin: number? } -- amp in degrees; spin in radians a second

local RULES: { [string]: Rule } = {
	Noren = { amp = 6, period = 5.2 },
	Chochin = { amp = 4, period = 3.6 },
	LanternString = { amp = 2.5, period = 6.4 },
	MirrorBall = { amp = 0, period = 1, spin = 0.35 },
}

local REACH = 75 -- studs from the camera within which a prop moves
local MOST = 30 -- how many at once
local PICK = 0.5 -- seconds between choosing which

type Item = {
	model: Model,
	rule: Rule,
	base: CFrame,
	hinge: CFrame, -- where it hangs from, in its own space
	phase: number,
	angle: number, -- a turning prop's angle
	moved: boolean,
	at: Vector3,
}

local function put(item: Item, cframe: CFrame)
	if item.model.Parent then
		item.model:PivotTo(cframe)
	end
end

function Sway.build(index: Util.Index, _mapId: string): Util.Built?
	local items: { Item } = {}
	for key, rule in pairs(RULES) do
		local info = Catalog[key]
		for _, model in ipairs(index.props[key] or {}) do
			local base = model:GetPivot()
			-- (a prop of "centre" pivot hangs from half its height up; its size is in the catalog, y up)
			local top = if not info then 0 elseif info.pivot == "bottom" then info.size[2] else info.size[2] / 2
			local height = top * model:GetScale()
			table.insert(items, {
				model = model,
				rule = rule,
				base = base,
				hinge = CFrame.new(0, height, 0),
				phase = LifePatterns.phaseOf(base.X, base.Z, 6.28),
				angle = LifePatterns.phaseOf(base.Z, base.X, 6.28),
				moved = false,
				at = base.Position,
			})
		end
	end
	if #items == 0 then
		return nil
	end
	local active: { Item } = {}
	local pickedAt = -math.huge

	local function pick(eye: Vector3)
		local near: { { item: Item, d: number } } = {}
		for _, item in ipairs(items) do
			local d = (item.at - eye).Magnitude
			if d <= REACH then
				table.insert(near, { item = item, d = d })
			elseif item.moved then
				item.moved = false
				put(item, item.base)
			end
		end
		table.sort(near, function(a, b)
			return a.d < b.d
		end)
		table.clear(active)
		for i = 1, #near do
			if i <= MOST then
				table.insert(active, near[i].item)
			elseif near[i].item.moved then
				near[i].item.moved = false
				put(near[i].item, near[i].item.base)
			end
		end
	end

	return {
		step = function(env: Util.Env)
			if env.now - pickedAt >= PICK then
				pickedAt = env.now
				pick(env.eye)
			end
			local gust = LifePatterns.gust(env.now)
			for _, item in ipairs(active) do
				local rule = item.rule
				if env.reduced then
					if item.moved then
						item.moved = false
						put(item, item.base)
					end
				elseif rule.spin then
					item.angle = (item.angle + rule.spin * env.dt) % (2 * math.pi)
					item.moved = true
					put(item, item.base * CFrame.Angles(0, item.angle, 0))
				else
					local amp = math.rad(rule.amp) * gust
					local ax = amp * LifePatterns.sway(env.now, rule.period, item.phase)
					local az = amp * 0.4 * LifePatterns.sway(env.now, rule.period * 1.3, item.phase + 2)
					local ay = amp * 0.3 * LifePatterns.sway(env.now, rule.period * 0.8, item.phase + 4)
					item.moved = true
					put(item, item.base * item.hinge * CFrame.Angles(ax, ay, az) * item.hinge:Inverse())
				end
			end
		end,
		destroy = function()
			for _, item in ipairs(items) do
				if item.moved then
					put(item, item.base)
				end
			end
		end,
	}
end

local kind: Util.Kind = { name = "sway", maps = { "TokyoDistrict" }, build = Sway.build }
return kind
