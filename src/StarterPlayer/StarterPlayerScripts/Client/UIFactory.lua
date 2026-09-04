--!strict

local Players = game:GetService("Players")
local ThemeModule = script.Parent:FindFirstChild("Theme")
assert(ThemeModule and ThemeModule:IsA("ModuleScript"), "Client.Theme is missing")
local Theme = require(ThemeModule)

local UIFactory = {}

function UIFactory.GetScreen(name: string, displayOrder: number): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	assert(playerGui ~= nil, "LocalPlayer.PlayerGui is missing")
	local existing = playerGui:FindFirstChild(name)
	local screen: ScreenGui
	if existing ~= nil and existing:IsA("ScreenGui") then
		screen = existing
		for _, child in screen:GetChildren() do
			child:Destroy()
		end
	else
		screen = Instance.new("ScreenGui")
		screen.Name = name
		screen.Parent = playerGui
	end
	screen.Enabled = true
	screen.IgnoreGuiInset = false
	screen.ResetOnSpawn = false
	screen.DisplayOrder = displayOrder
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return screen
end

function UIFactory.Round(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 14)
	corner.Parent = instance
end

function UIFactory.Stroke(instance: GuiObject, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.SurfaceRaised
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.15
	stroke.Parent = instance
end

function UIFactory.Padding(instance: GuiObject, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = instance
end

function UIFactory.Text(parent: Instance, text: string, size: UDim2, position: UDim2?, textSize: number?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.fromOffset(0, 0)
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color or Theme.Colors.Text
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function UIFactory.Button(parent: Instance, text: string, size: UDim2, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or Theme.Colors.Accent
	button.Size = size
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Theme.Colors.Text
	button.TextSize = 17
	button.TextWrapped = true
	button.Parent = parent
	UIFactory.Round(button, 12)
	return button
end

function UIFactory.Panel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Theme.Colors.Surface
	panel.Size = size
	panel.Position = position
	panel.Parent = parent
	UIFactory.Round(panel, 18)
	UIFactory.Stroke(panel, Theme.Colors.SurfaceRaised, 2)
	return panel
end

function UIFactory.Overlay(screen: ScreenGui): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.28
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Active = true
	overlay.Parent = screen
	return overlay
end

function UIFactory.FormatNumber(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(rounded)
	while true do
		local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return text
end

return table.freeze(UIFactory)
