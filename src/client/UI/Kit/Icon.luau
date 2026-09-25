--!strict
-- A hand-inked icon from the UiIcons atlas (art/scripts/ui/textures.py draws them; names are
-- in Shared/UI/Icons). Until the atlas loads, a small letter in a ring stands in.
--
--   Icon.new({ name = "vote", size = 28, color = Tokens.color.bone, Parent = row })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Icons"))

local Base = require(script.Parent.Base)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local Icon = {}

type Props = { [string]: any }

-- True when the atlas has an icon with this name.
function Icon.exists(name: string): boolean
	return (Icons :: any).cells[name] ~= nil
end

-- Props: name, size (px, default 24), color, transparency, plus frame properties.
-- Returns the ImageLabel; call Icon.set(label, name) to change it.
function Icon.new(props: Props): ImageLabel
	local size = props.size or 24
	local image = Base.make("ImageLabel", {
		Name = props.Name or "Icon",
		BackgroundTransparency = 1,
		ImageColor3 = props.color or Tokens.color.bone,
		ImageTransparency = props.transparency or 0,
		Size = UDim2.fromOffset(size, size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	image:SetAttribute("IconName", props.name)
	Icon.refresh(image)
	if not Textures.isReady() then
		local connection
		connection = Textures.Ready:Connect(function()
			if image.Parent then
				Icon.refresh(image)
			end
			connection:Disconnect()
		end)
		image.Destroying:Once(function()
			connection:Disconnect()
		end)
	end
	return image
end

-- Redraws an icon made by Icon.new (after its name changed or the atlas arrived).
function Icon.refresh(image: ImageLabel)
	local name = image:GetAttribute("IconName")
	local cell = if type(name) == "string" then (Icons :: any).cells[name] else nil
	local id = Textures.id((Icons :: any).atlas)
	local fallback = image:FindFirstChild("Fallback")
	if cell and id ~= "" then
		image.Image = id
		image.ImageRectOffset = Vector2.new(cell[1], cell[2])
		image.ImageRectSize = Vector2.new((Icons :: any).cell, (Icons :: any).cell)
		if fallback then
			fallback:Destroy()
		end
		return
	end
	image.Image = ""
	if not fallback then
		fallback = Base.label({
			Name = "Fallback",
			font = "bodyBold",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			ZIndex = image.ZIndex,
			Parent = image,
		})
		Base.round(fallback :: Instance)
		Base.stroke(fallback :: Instance, image.ImageColor3, 1, 0.4)
	end
	local label = fallback :: TextLabel
	label.Text = if type(name) == "string" then string.upper(string.sub(name, 1, 1)) else "?"
	label.TextColor3 = image.ImageColor3
end

function Icon.set(image: ImageLabel, name: string)
	image:SetAttribute("IconName", name)
	Icon.refresh(image)
end

return Icon
