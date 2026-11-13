-- Watches the Tokyo crowd without a play test: steps the bundle's CrowdSim over the real walk graph for a few minutes,
-- the scramble's lamps going round as ScrambleCycle says, with nobody about, and reports what the crowd did, in numbers.
-- From execute_luau in the Edit datamodel (after python scripts/crowd/bundle.py):
--   local root = game:GetObjects("rbxasset://dg_specs.rbxm")[1]
--   local text = require(root.Tools.watch)(root, 1, 300)   -- seed, seconds
--   root:Destroy()
--   return text
-- The numbers of 2026-11-13, before the crowd's rework (docs/agent-memory/tokyo-crowd-2026-11.md), came from this.

return function(root: Instance, seed: number?, seconds: number?): string
	local r = root :: any
	local CrowdSim = require(r.Server.Maps.Mechanics.TokyoDistrict.CrowdSim)
	local Cycle = require(r.Shared.ScrambleCycle)
	local data = require(r.Server.Maps.TokyoLayout).crowd
	local SEED = seed or 1
	local SECONDS = seconds or 300
	local DT = 1 / 30
	local out = {}
	local function say(...)
		table.insert(out, string.format(...))
	end

	-- The graph ------------------------------------------------------------------------------------
	local nodes, links = data.nodes, data.links
	local degree = {}
	for i = 1, #nodes do
		degree[i] = 0
	end
	local pairCount, doubles = {}, {}
	local widths = { le1 = 0, le15 = 0, le2 = 0, more = 0 }
	local singles, crossings, walks, total = 0, 0, 0, 0
	for _, link in ipairs(links) do
		degree[link.a] += 1
		degree[link.b] += 1
		local key = math.min(link.a, link.b) .. "-" .. math.max(link.a, link.b)
		pairCount[key] = (pairCount[key] or 0) + 1
		if pairCount[key] == 2 then
			table.insert(doubles, key)
		end
		if link.kind == "crossing" then
			crossings += 1
		else
			walks += 1
			total += math.sqrt((nodes[link.a].x - nodes[link.b].x) ^ 2 + (nodes[link.a].z - nodes[link.b].z) ^ 2)
			if link.single then
				singles += 1
			end
			local w = link.width
			if w <= 1 then
				widths.le1 += 1
			elseif w < 1.5 then
				widths.le15 += 1
			elseif w <= 2 then
				widths.le2 += 1
			else
				widths.more += 1
			end
		end
	end
	local deadEnds = {}
	for i, d in ipairs(degree) do
		if d == 1 then
			table.insert(deadEnds, string.format("%d(%.0f,%.0f)", i, nodes[i].x, nodes[i].z))
		end
	end
	say(
		"GRAPH nodes=%d links=%d (walk %d, crossing %d, single file %d) posts=%d, %.0f studs of walk",
		#nodes,
		#links,
		walks,
		crossings,
		singles,
		#data.posts,
		total
	)
	say(
		"double links=%d %s; widths: <=1 %d, <1.5 %d, <=2 %d, wider %d",
		#doubles,
		table.concat(doubles, " "),
		widths.le1,
		widths.le15,
		widths.le2,
		widths.more
	)
	say("dead ends (%d): %s", #deadEnds, table.concat(deadEnds, " "))
	local cx, cz, cn = 0, 0, 0
	for _, link in ipairs(links) do
		if link.kind == "crossing" then
			cx += (nodes[link.a].x + nodes[link.b].x) / 2
			cz += (nodes[link.a].z + nodes[link.b].z) / 2
			cn += 1
		end
	end
	cx /= cn
	cz /= cn
	say("scramble centre (%.1f, %.1f)", cx, cz)

	-- The run --------------------------------------------------------------------------------------
	local sim = CrowdSim.new(data, Random.new(SEED))
	sim:seed(50)
	local walkers = sim.walkers
	local N = #walkers
	local prev, pathLen, hist = {}, {}, {}
	for i = 1, N do
		local w = walkers[i]
		if not w.standing then
			prev[i] = {
				link = w.link,
				from = w.from,
				to = w.to,
				speed = w.speed,
				heading = w.heading,
				x = w.x,
				z = w.z,
				wait = w.wait,
			}
			pathLen[i] = 0
			hist[i] = {}
		end
	end
	local entered, uturns, revisits = 0, 0, 0
	local awaySteps = 0
	local pauses, deadPauses, lingerTime = 0, 0, 0
	local near12, near06, pairSteps, closest, closestAt = 0, 0, 0, math.huge, ""
	local maxDV, bigDV, maxDH, bigDH = 0, 0, 0, 0
	local waitSamples, waitAway = 0, 0
	local centre2, centreSamples = 0, 0
	local byPhase = { WALK = { 0, 0 }, FLASH = { 0, 0 }, CARS = { 0, 0 }, AMBER = { 0, 0 } }
	local onCrossing = 0
	local speedSum, speedN = 0, 0
	local frames = math.round(SECONDS / DT)
	for frame = 1, frames do
		local t = frame * DT
		local phase = Cycle.at(0, t)
		sim:step(DT, { clearFor = Cycle.clearFor(0, t), cars = phase == "CARS" or phase == "AMBER", players = {} })
		for i = 1, N do
			local w = walkers[i]
			if w.standing then
				continue
			end
			if not w.shown then
				-- (out of the world between trips: it comes back somewhere else, so its baseline moves with it)
				if prev[i] then
					prev[i].x, prev[i].z, prev[i].speed, prev[i].wait = w.x, w.z, 0, 0
					prev[i].link, prev[i].from, prev[i].to = w.link, w.from, w.to
					prev[i].fresh = true
					awaySteps += 1
				end
				continue
			end
			local p = prev[i]
			if not p then
				continue
			end
			if p.speed == 0 and p.x ~= w.x and math.abs(w.x - p.x) + math.abs(w.z - p.z) > 3 then
				-- (back in the world at an end: not a step)
				p.x, p.z, p.link, p.from, p.to = w.x, w.z, w.link, w.from, w.to
				p.heading = w.heading
			end
			local dv = math.abs(w.speed - p.speed) / DT
			maxDV = math.max(maxDV, dv)
			if dv > 60 then
				bigDV += 1
			end
			local dh = math.abs(((w.heading - p.heading + math.pi) % (2 * math.pi)) - math.pi) / DT
			maxDH = math.max(maxDH, dh)
			if dh > 4 * math.pi then
				bigDH += 1
			end
			pathLen[i] += math.sqrt((w.x - p.x) ^ 2 + (w.z - p.z) ^ 2)
			if w.link ~= p.link or w.from ~= p.from then
				entered += 1
				if w.to == p.from and not p.fresh then
					uturns += 1
				end
				for _, n in ipairs(hist[i]) do
					if n == w.to then
						revisits += 1
						break
					end
				end
				table.insert(hist[i], 1, w.from)
				if #hist[i] > 6 then
					table.remove(hist[i])
				end
			end
			if w.wait > 0 and not w.waiting then
				lingerTime += DT
				if p.wait <= 0 then
					pauses += 1
					if (degree[w.to] or 0) == 1 then
						deadPauses += 1
					end
				end
			end
			if w.speed > 0.5 then
				speedSum += w.speed
				speedN += 1
			end
			if w.waiting and w.next then
				waitSamples += 1
				local onward = sim.graph.links[w.next]
				local a, b = sim.graph.nodes[onward.a], sim.graph.nodes[onward.b]
				local here = sim.graph.nodes[w.to]
				local dx, dz = b.x - a.x, b.z - a.z
				if
					math.abs(b.x - here.x) + math.abs(b.z - here.z)
					< math.abs(a.x - here.x) + math.abs(a.z - here.z)
				then
					dx, dz = -dx, -dz
				end
				local len = math.sqrt(dx * dx + dz * dz)
				local fx, fz = -math.sin(w.heading), -math.cos(w.heading)
				if (fx * dx + fz * dz) / len < 0.7 then
					waitAway += 1
				end
			end
			if sim.graph.links[w.link].kind == "crossing" then
				onCrossing += 1
			end
			prev[i] = {
				link = w.link,
				from = w.from,
				to = w.to,
				speed = w.speed,
				heading = w.heading,
				x = w.x,
				z = w.z,
				wait = w.wait,
			}
		end
		if frame % 3 == 0 then
			pairSteps += 1
			local inCentre = 0
			for i = 1, N do
				local a = walkers[i]
				if a.standing or not a.shown then
					continue
				end
				if (a.x - cx) ^ 2 + (a.z - cz) ^ 2 <= 25 then
					inCentre += 1
				end
				for j = i + 1, N do
					local b = walkers[j]
					if b.standing or not b.shown then
						continue
					end
					local d2 = (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2
					if d2 < 1.44 then
						near12 += 1
						if d2 < 0.36 then
							near06 += 1
						end
						if d2 < closest then
							closest = d2
							closestAt = string.format("%d & %d at (%.1f, %.1f) t=%.0f", i, j, a.x, a.z, t)
						end
					end
				end
			end
			centreSamples += 1
			byPhase[phase][2] += 1
			if inCentre >= 2 then
				centre2 += 1
				byPhase[phase][1] += 1
			end
		end
	end
	local span = frames * DT
	local live, walked = 0, 0
	for i = 1, N do
		local w = walkers[i]
		if not w.standing and prev[i] then
			live += 1
			walked += pathLen[i]
		end
	end
	local pairsTotal = math.max(1, pairSteps * live * (live - 1) / 2)
	say("RUN seed %d: %d walkers, %.0f s", SEED, live, span)
	say("links entered %d, u-turns %d (dead ends), revisits of a node in the last 6: %d", entered, uturns, revisits)
	say(
		"pauses %d (at a dead end %d); lingering %.0f%% of walker time",
		pauses,
		deadPauses,
		100 * lingerTime / (span * live)
	)
	say(
		"path walked %.0f studs; mean moving speed %.1f; trips finished %d (%.1f per walker a minute); out of the world %.0f%% of walker time",
		walked,
		speedSum / math.max(1, speedN),
		sim.trips,
		sim.trips / math.max(1, live) / (span / 60),
		100 * awaySteps / math.max(1, frames * live)
	)
	say(
		"pair samples closer than 1.2 studs: %d (%.3f%%), than 0.6: %d; closest %.2f at %s",
		near12,
		100 * near12 / pairsTotal,
		near06,
		math.sqrt(closest),
		closestAt
	)
	say(
		"speed change: most %.0f studs/s^2, steps over 60: %d; turning: most %.0f deg/s, steps over 720: %d",
		maxDV,
		bigDV,
		math.deg(maxDH),
		bigDH
	)
	say(
		"kerb waiting: %d samples, %.0f%% not facing the crossing",
		waitSamples,
		100 * waitAway / math.max(1, waitSamples)
	)
	say(
		"2 or more within 5 studs of the scramble's centre: %.1f%% of the time; walk %.0f%% flash %.0f%% cars %.0f%% amber %.0f%%",
		100 * centre2 / centreSamples,
		100 * byPhase.WALK[1] / math.max(1, byPhase.WALK[2]),
		100 * byPhase.FLASH[1] / math.max(1, byPhase.FLASH[2]),
		100 * byPhase.CARS[1] / math.max(1, byPhase.CARS[2]),
		100 * byPhase.AMBER[1] / math.max(1, byPhase.AMBER[2])
	)
	say("walker time on a crossing %.1f%%", 100 * onCrossing * DT / (span * live))
	return table.concat(out, "\n")
end
