--!strict
-- In Studio only: a plain notice over the top of the screen while any import is older than the scripts expect
-- (ModelLibrary.install() keeps the list on the assets store as "StaleImports"). On 2026-10-24 the owner imported
-- files from a checkout 96 commits behind and saw none of the new props, with nothing on screen to say why.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ImportNotice = {}

local gui: ScreenGui? = nil

local function show(text: string?)
	if gui then
		gui:Destroy()
		gui = nil
	end
	if not text or text == "" then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "DGImportNotice"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 1000
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 44)
	label.Size = UDim2.new(0.9, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromRGB(255, 214, 120)
	label.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	label.TextSize = 15
	label.TextWrapped = true
	label.Text = "STUDIO ONLY: these imports are missing or old, so their props show as plain stand-ins: "
		.. text
		.. ". In your Lgame folder run git pull, then in Studio use Import 3D on each of these files from"
		.. " Lgame/art/export (delete the old copy of each first). This notice goes away when they are all in."
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = label
	label.Parent = screen
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
end

function ImportNotice.init()
	-- (not in the play-test harness either, whose place has no imports at all and whose pictures it would cover)
	if not RunService:IsStudio() or workspace:GetAttribute("DGEmoteHarness") then
		return
	end
	task.spawn(function()
		local store = ReplicatedStorage:WaitForChild("DeathsGambitAssets", 60)
		if not store then
			return
		end
		local function changed()
			local value = store:GetAttribute("StaleImports")
			show(if type(value) == "string" then value else nil)
		end
		store:GetAttributeChangedSignal("StaleImports"):Connect(changed)
		changed()
	end)
end

return ImportNotice
