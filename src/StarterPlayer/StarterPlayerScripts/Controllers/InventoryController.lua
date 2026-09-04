--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local clientFolder = script.Parent.Parent:FindFirstChild("Client")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")
local UIFactory = require(clientFolder:FindFirstChild("UIFactory") :: ModuleScript)
local Theme = require(clientFolder:FindFirstChild("Theme") :: ModuleScript)
local BrainrotDefinitions = require(ReplicatedStorage.Shared.BrainrotDefinitions)

local store: any = nil
local screen: ScreenGui? = nil
local summaryLabel: TextLabel? = nil
local pendingLabel: TextLabel? = nil
local content: ScrollingFrame? = nil
local InventoryController = { Name = "InventoryController" }

local rarityOrder: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Mythic = 5,
}

local function countEntries(source: any): number
	local count = 0
	for _ in source do count += 1 end
	return count
end

local function addCard(text: string, color: Color3)
	local frame = content
	if frame == nil then return end
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.Colors.SurfaceRaised
	card.Size = UDim2.new(1, -12, 0, 92)
	local children = frame:GetChildren()
	card.LayoutOrder = #children
	card.Parent = frame
	UIFactory.Round(card, 12)
	UIFactory.Stroke(card, color, 2)
	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Size = UDim2.fromOffset(7, 92)
	accent.Parent = card
	UIFactory.Round(accent, 12)
	local label = UIFactory.Text(card, text, UDim2.new(1, -36, 1, -18), UDim2.fromOffset(22, 9), 16)
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function rebuild()
	local frame = content
	if frame == nil then return end
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
	local state = store.GetState()
	local snapshot = state.Snapshot
	if snapshot == nil then
		(summaryLabel :: TextLabel).Text = "Loading inventory…"
		return
	end
	local ownedCount = countEntries(snapshot.Inventory)
	;(summaryLabel :: TextLabel).Text = `PERMANENT COLLECTION  •  {snapshot.CollectionCount or 0}/{snapshot.DefinitionCount or 0} discovered  •  {ownedCount} owned`

	local pending = if state.Run ~= nil then state.Run.PendingReward else nil
	if pending ~= nil then
		(pendingLabel :: TextLabel).Visible = true
		(pendingLabel :: TextLabel).Text = `PENDING — NOT IN THIS INVENTORY\n{pending.DisplayName} can still be lost if the next challenge fails.`
	else
		(pendingLabel :: TextLabel).Visible = false
	end

	local entries = {}
	for instanceId, instance in snapshot.Inventory do
		local definition = BrainrotDefinitions[instance.BrainrotId]
		if definition ~= nil then
			table.insert(entries, { InstanceId = instanceId, Instance = instance, Definition = definition })
		end
	end
	table.sort(entries, function(a, b)
		local rarityA = rarityOrder[a.Definition.Rarity] or 0
		local rarityB = rarityOrder[b.Definition.Rarity] or 0
		if rarityA ~= rarityB then return rarityA > rarityB end
		if a.Definition.DisplayName ~= b.Definition.DisplayName then return a.Definition.DisplayName < b.Definition.DisplayName end
		return a.InstanceId < b.InstanceId
	end)
	if #entries == 0 then
		addCard("No permanent Brainrots yet.\nComplete a Tower room and choose CLAIM.", Theme.Colors.Disabled)
		return
	end
	for _, entry in entries do
		local definition = entry.Definition
		local location = if entry.Instance.FarmSlotId ~= nil then `WORKING IN FARM SLOT {entry.Instance.FarmSlotId}` else "READY TO PLACE ON FARM"
		addCard(
			`{definition.DisplayName}  •  {string.upper(definition.Rarity)}\nPERMANENT & SAFE  •  +{UIFactory.FormatNumber(definition.BaseProductionPerMinute)} Coins/min base  •  {location}`,
			Theme.RarityColors[definition.Rarity] or Theme.Colors.Accent
		)
	end
end

local function update()
	local isOpen = store.GetState().OpenPanel == "Inventory"
	(screen :: ScreenGui).Enabled = isOpen
	if isOpen then rebuild() end
end

function InventoryController.Init(context: any)
	store = context.Store
	screen = UIFactory.GetScreen("InventoryUI", 20)
	UIFactory.Overlay(screen :: ScreenGui)
	local panel = UIFactory.Panel(screen :: ScreenGui, "InventoryPanel", UDim2.new(0.94, 0, 0.84, 0), UDim2.fromScale(0.5, 0.5))
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 300)
	constraint.MaxSize = Vector2.new(850, 700)
	constraint.Parent = panel
	UIFactory.Text(panel, "BRAINROT INVENTORY", UDim2.new(1, -100, 0, 44), UDim2.fromOffset(22, 12), 25).Font = Enum.Font.GothamBold
	local close = UIFactory.Button(panel, "×", UDim2.fromOffset(58, 58), Theme.Colors.SurfaceRaised)
	close.Position = UDim2.new(1, -72, 0, 10)
	close.TextSize = 30
	close.Activated:Connect(function() store.SetOpenPanel(nil) end)
	summaryLabel = UIFactory.Text(panel, "Loading inventory…", UDim2.new(1, -44, 0, 36), UDim2.fromOffset(22, 58), 15, Theme.Colors.Muted)
	pendingLabel = UIFactory.Text(panel, "", UDim2.new(1, -44, 0, 64), UDim2.fromOffset(22, 96), 15, Theme.Colors.Risk)
	;(pendingLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	;(pendingLabel :: TextLabel).BackgroundColor3 = Theme.Colors.SurfaceRaised
	;(pendingLabel :: TextLabel).BackgroundTransparency = 0.15
	UIFactory.Round(pendingLabel :: TextLabel, 10)
	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(18, 170)
	content.Size = UDim2.new(1, -36, 1, -188)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.ScrollBarThickness = 7
	content.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 9)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	UIFactory.Padding(content :: ScrollingFrame, 4)
	;(screen :: ScreenGui).Enabled = false
end

function InventoryController.Start()
	store.Changed:Connect(update)
	update()
end

return table.freeze(InventoryController)
