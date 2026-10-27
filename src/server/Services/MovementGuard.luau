--!strict
-- Keeps the living to how a body can really move in free roam (2026-10-27: an exploit could speed, fly, pass through
-- walls and teleport, since each client moves its own body). Twice a second the server looks at where each living
-- player's body went since it last looked: further than the fastest legitimate move could take it in that time (a
-- teleport, a speed hack), through something solid on the way (noclip), or hanging in the air with nothing under it
-- (flying: nobody can jump in free roam) puts the body back where it last stood rightly. Legitimate moves are left
-- alone: the server's own placing (spawns, seats, phases: CharacterService.placeAt), a held (anchored) body, a seat,
-- an emote's walk, and Specters, who fly through walls by design.

local Players = game:GetService("Players")

local CharacterService = require(script.Parent.CharacterService)
local Match = require(script.Parent.Match)

local MovementGuard = {}

local CHECK = 0.5 -- seconds between looks
local SPEED = 2 -- the fastest legitimate move, as a share of the body's walk speed (strolls and emotes included)
local SLACK = 6 -- studs a second more, for lag and pushes
local PLACED_GRACE = 2 -- seconds after the server placed a body that it is left alone
local AIR_TIME = 2.5 -- seconds a body may hang off the ground (a fall comes down quickly)
local FLOOR_REACH = 9 -- studs under the root that count as ground

type Track = { at: Vector3, cframe: CFrame, time: number, air: number }
local tracks: { [Player]: Track } = {}
local placed: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- The server put this body somewhere itself (CharacterService.placeAt calls this).
function MovementGuard.placed(player: Player)
	placed[player] = os.clock()
	tracks[player] = nil
end

local function solids(character: Model): RaycastParams
	local bodies = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(bodies, other.Character)
		end
	end
	table.insert(bodies, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = bodies
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

-- What is wrong with how this body moved from `track` to `root` (nil when nothing is).
function MovementGuard.problem(
	track: Track,
	at: Vector3,
	walkSpeed: number,
	now: number,
	params: RaycastParams
): string?
	local elapsed = math.max(now - track.time, CHECK)
	local flat = Vector3.new(at.X - track.at.X, 0, at.Z - track.at.Z).Magnitude
	if flat > (math.max(walkSpeed, 16) * SPEED + SLACK) * elapsed then
		return "speed"
	end
	local step = at - track.at
	if step.Magnitude > 0.5 and workspace:Raycast(track.at, step, params) then
		return "noclip"
	end
	return nil
end

local function check(ps, now: number)
	local player = ps.player
	if typeof(player) ~= "Instance" then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not root or not root:IsA("BasePart") or not humanoid then
		tracks[player] = nil
		return
	end
	local exempt = root.Anchored
		or humanoid.Sit
		or humanoid.Health <= 0
		or character:GetAttribute("Seat") ~= nil
		or character:GetAttribute("Stroll") ~= nil
		or (placed[player] ~= nil and now - placed[player] < PLACED_GRACE)
	local at = root.Position
	local track = tracks[player]
	if exempt or not track then
		tracks[player] = { at = at, cframe = root.CFrame, time = now, air = 0 }
		return
	end
	local params = solids(character)
	local problem = MovementGuard.problem(track, at, humanoid.WalkSpeed, now, params)
	-- Flying: off the ground and not coming down.
	local ground = workspace:Raycast(at, Vector3.new(0, -FLOOR_REACH, 0), params)
	local air = if ground or root.AssemblyLinearVelocity.Y < -8 then 0 else track.air + (now - track.time)
	if not problem and air > AIR_TIME then
		problem = "flying"
	end
	if problem then
		-- Back to where it last stood rightly.
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = track.cframe
		placed[player] = now - PLACED_GRACE + CHECK
		track.time = now
		track.air = 0
		warn(string.format("[DeathsGambit] %s moved wrongly (%s): put back", player.Name, problem))
		return
	end
	tracks[player] = { at = at, cframe = if ground then root.CFrame else track.cframe, time = now, air = air }
end

function MovementGuard.init()
	task.spawn(function()
		while true do
			task.wait(CHECK)
			if Match.active and Match.phase == "Investigation" and not Match.debugPaused then
				local now = os.clock()
				for _, ps in ipairs(Match.living()) do
					local ok, err = pcall(check, ps, now)
					if not ok then
						warn("[DeathsGambit] MovementGuard: " .. tostring(err))
					end
				end
			else
				table.clear(tracks)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
	CharacterService.Placed = MovementGuard.placed
end

return MovementGuard
