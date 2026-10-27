--!strict
-- The "lifespan" look over a name (2026-10-27, the owner's reference: the Shinigami eyes' view): the name scrawled in
-- glowing red by hand, and under it a row of letters that never settles, each one flickering to another as if counting
-- something down. Only this player sees it, over the heads of their friends (a Roblox friend or someone in their lobby
-- party: World/NameTags), and in the flash of a real name learned by staring (UI/WorldFx).

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)

local Lifespan = {}

local LOCAL = Players.LocalPlayer
local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local ROW = 8 -- letters under the name
local HOT = Color3.fromRGB(255, 132, 104) -- the scrawl's lit core
local GLOW = Color3.fromRGB(226, 24, 36) -- its halo
local COUNT = Color3.fromRGB(255, 104, 82)

-- Fired when who counts as a friend may have changed (a Roblox friendship found, the party changed).
Lifespan.Changed = Signal.new()

local friends: { [number]: boolean } = {} -- Roblox friendships, asked once per player
local asking: { [number]: boolean } = {}

local function scrawl(): Font
	local font = Font.fromEnum(Enum.Font.Kalam)
	font.Weight = Enum.FontWeight.Bold
	return font
end

local function inParty(userId: number): boolean
	local party = ClientState.party
	if type(party) ~= "table" or type(party.members) ~= "table" then
		return false
	end
	for _, member in ipairs(party.members) do
		if type(member) == "table" and member.userId == userId then
			return true
		end
	end
	return false
end

-- (debug runs: LocalPlayer attribute DGFriends, user ids separated by commas, counts those players as friends)
local function debugFriend(userId: number): boolean
	local list = LOCAL:GetAttribute("DGFriends")
	if type(list) ~= "string" then
		return false
	end
	for id in string.gmatch(list, "%-?%d+") do
		if tonumber(id) == userId then
			return true
		end
	end
	return false
end

-- Is this player one of this player's friends (Roblox friend, lobby party member)? A Roblox friendship is looked up
-- once in the background: false until it is known, then Changed fires.
function Lifespan.isFriend(userId: number): boolean
	if userId == LOCAL.UserId or userId <= 0 then
		return false
	end
	if inParty(userId) or debugFriend(userId) then
		return true
	end
	local known = friends[userId]
	if known ~= nil then
		return known
	end
	if not asking[userId] then
		asking[userId] = true
		task.spawn(function()
			local ok, result = pcall(function()
				return LOCAL:IsFriendsWith(userId)
			end)
			friends[userId] = ok and result == true
			asking[userId] = nil
			if friends[userId] then
				Lifespan.Changed:Fire()
			end
		end)
	end
	return false
end

export type Handle = {
	frame: Frame,
	setName: (text: string) -> (),
	destroy: () -> (),
}

-- Draws the look into `parent` (a BillboardGui, sized by the caller): the name across the top two thirds, the letters
-- under it. `size` is the name's text size in pixels (the letters are two thirds of it).
function Lifespan.draw(parent: Instance, name: string, size: number?): Handle
	local textSize = size or 22
	local frame = Instance.new("Frame")
	frame.Name = "Lifespan"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Size = UDim2.fromScale(1, 0.62)
	label.FontFace = scrawl()
	label.TextSize = textSize
	label.TextColor3 = HOT
	label.TextStrokeTransparency = 1
	label.Text = name
	label.Rotation = -3
	label.Parent = frame
	local halo = Instance.new("UIStroke")
	halo.Color = GLOW
	halo.Thickness = math.max(1.5, textSize / 11)
	halo.Transparency = 0.25
	halo.Parent = label

	local row = Instance.new("Frame")
	row.Name = "Count"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.fromScale(0.5, 1)
	row.Size = UDim2.fromScale(0.7, 0.4)
	row.Parent = frame
	local cells: { TextLabel } = {}
	for k = 1, ROW do
		local cell = Instance.new("TextLabel")
		cell.BackgroundTransparency = 1
		cell.AnchorPoint = Vector2.new(0.5, 0.5)
		-- (scattered like a hand's figures: a little up or down, each at its own slant)
		cell.Position = UDim2.new((k - 0.5) / ROW, 0, 0.5, math.random(-3, 3))
		cell.Size = UDim2.fromScale(1 / ROW, 1)
		cell.FontFace = scrawl()
		cell.TextSize = math.floor(textSize * 0.66)
		cell.TextColor3 = COUNT
		cell.TextTransparency = 0.1
		cell.Rotation = math.random(-14, 14)
		cell.Text = string.char(64 + math.random(1, 26))
		cell.Parent = row
		local edge = Instance.new("UIStroke")
		edge.Color = GLOW
		edge.Thickness = 1
		edge.Transparency = 0.45
		edge.Parent = cell
		table.insert(cells, cell)
	end

	local alive = true
	-- The letters reshuffle for as long as the look is up, a few at a time; the scrawl's glow breathes.
	task.spawn(function()
		local still = Motion.isReduced()
		local tick = 0
		while alive and frame.Parent do
			tick += 1
			local shown = true
			local gui = frame:FindFirstAncestorWhichIsA("BillboardGui")
			if gui and not gui.Enabled then
				shown = false
			end
			if shown then
				for _ = 1, if still then 1 else math.random(2, 4) do
					local cell = cells[math.random(1, #cells)]
					local r = math.random(1, #LETTERS)
					cell.Text = string.sub(LETTERS, r, r)
					cell.TextTransparency = math.random() * 0.35
				end
				halo.Transparency = 0.2 + 0.15 * math.sin(tick * 0.6)
			end
			task.wait(if still then 0.4 else 0.08)
		end
	end)

	return {
		frame = frame,
		setName = function(text: string)
			label.Text = text
		end,
		destroy = function()
			alive = false
			frame:Destroy()
		end,
	}
end

function Lifespan.init()
	ClientState.PartyChanged:Connect(function()
		Lifespan.Changed:Fire()
	end)
	LOCAL:GetAttributeChangedSignal("DGFriends"):Connect(function()
		Lifespan.Changed:Fire()
	end)
end

return Lifespan
