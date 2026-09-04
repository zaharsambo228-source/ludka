--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RobloxRunService = game:GetService("RunService")
local clientFolder = script.Parent.Parent:FindFirstChild("Client")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")
local UIFactory = require(clientFolder:FindFirstChild("UIFactory") :: ModuleScript)
local Theme = require(clientFolder:FindFirstChild("Theme") :: ModuleScript)
local ProductionProjection = require(clientFolder:FindFirstChild("ProductionProjection") :: ModuleScript)
local BrainrotDefinitions = require(ReplicatedStorage.Shared.BrainrotDefinitions)
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local store: any = nil
local farmRemote: RemoteEvent? = nil
local screen: ScreenGui? = nil
local content: ScrollingFrame? = nil
local productionCard: TextButton? = nil
local selectedInstanceId: string? = nil
local collectRequestId: string? = nil
local collectPending = false
local FarmController = { Name = "FarmController" }

local function makeSection(text: string): TextLabel
	local label = UIFactory.Text(content :: ScrollingFrame, text, UDim2.new(1, -12, 0, 38), nil, 20, Theme.Colors.Text)
	label.Font = Enum.Font.GothamBold
	local children = (content :: ScrollingFrame):GetChildren()
	label.LayoutOrder = #children
	return label
end

local function addCard(text: string, color: Color3, callback: (() -> ())?): TextButton
	local button = UIFactory.Button(content :: ScrollingFrame, text, UDim2.new(1, -12, 0, 70), color)
	local children = (content :: ScrollingFrame):GetChildren()
	button.LayoutOrder = #children
	button.TextXAlignment = Enum.TextXAlignment.Left
	UIFactory.Padding(button, 14)
	if callback ~= nil then button.Activated:Connect(callback) else button.Active = false end
	return button
end

local function definitionFor(snapshot: any, instanceId: string): any?
	local instance = snapshot.Inventory[instanceId]
	return if instance ~= nil then BrainrotDefinitions[instance.BrainrotId] else nil
end

local function refreshProductionCard()
	local card = productionCard
	local snapshot = store.GetState().Snapshot
	if card == nil or card.Parent == nil or snapshot == nil then return end
	local production = snapshot.Production
	card.Text = `+{UIFactory.FormatNumber(production.ProductionPerMinute or 0)} Coins/min   •   Ready: {UIFactory.FormatNumber(ProductionProjection.EstimateClaimable(snapshot))} Coins\nEfficiency {string.format("%.2fx", production.EfficiencyMultiplier or 1)}   •   Offline cap {math.floor((production.OfflineCapSeconds or 0) / 60)} min`
end

local function rebuild()
	local frame = content
	if frame == nil then return end
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
	productionCard = nil
	local snapshot = store.GetState().Snapshot
	if snapshot == nil then
		makeSection("Loading farm…")
		return
	end
	makeSection("FARM PRODUCTION")
	productionCard = addCard("Calculating production…", Theme.Colors.SurfaceRaised, nil)
	refreshProductionCard()
	local collectText = if collectPending
		then "SAVING COLLECTION…"
		elseif collectRequestId ~= nil then "RETRY COLLECTION"
		else "COLLECT COINS"
	addCard(collectText, if collectPending then Theme.Colors.Disabled else Theme.Colors.Coins, if collectPending then nil else function()
		if collectRequestId == nil then collectRequestId = HttpService:GenerateGUID(false) end
		local sentRequestId = collectRequestId
		collectPending = true
		(farmRemote :: RemoteEvent):FireServer({ Action = "Collect", RequestId = sentRequestId })
		rebuild()
		task.delay(BalanceConfig.UI.TransactionRetrySeconds, function()
			if collectPending and collectRequestId == sentRequestId then
				collectPending = false
				rebuild()
			end
		end)
	end).TextXAlignment = Enum.TextXAlignment.Center

	makeSection(`PHYSICAL SLOTS  •  {snapshot.Farm.UnlockedSlots}/{GameConfig.Farm.MaxSlots} UNLOCKED`)
	for slotIndex = 1, GameConfig.Farm.MaxSlots do
		local instanceId = snapshot.Farm.Slots[tostring(slotIndex)]
		if slotIndex > snapshot.Farm.UnlockedSlots then
			addCard(`SLOT {slotIndex}  •  LOCKED\nUnlock it in Upgrades`, Theme.Colors.Disabled, nil)
		elseif instanceId ~= nil then
			local definition = definitionFor(snapshot, instanceId)
			local name = if definition ~= nil then definition.DisplayName else "Unknown Brainrot"
			local rarity = if definition ~= nil then definition.Rarity else "Common"
			addCard(`SLOT {slotIndex}  •  {name}\n{string.upper(rarity)}  •  Tap to remove`, Theme.RarityColors[rarity] or Theme.Colors.Accent, function()
				(farmRemote :: RemoteEvent):FireServer({ Action = "RemoveBrainrot", SlotIndex = slotIndex })
			end)
		else
			local selected = selectedInstanceId
			addCard(`SLOT {slotIndex}  •  EMPTY\n{if selected ~= nil then "Tap to place selected Brainrot" else "Select a permanent Brainrot below"}`, Theme.Colors.SurfaceRaised, function()
				if selectedInstanceId ~= nil then
					(farmRemote :: RemoteEvent):FireServer({ Action = "PlaceBrainrot", SlotIndex = slotIndex, InstanceId = selectedInstanceId })
				end
			end)
		end
	end

	makeSection(`PERMANENT INVENTORY  •  SELECT TO PLACE`)
	local instanceIds = {}
	for instanceId, instance in snapshot.Inventory do
		if instance.FarmSlotId == nil then table.insert(instanceIds, instanceId) end
	end
	table.sort(instanceIds)
	if #instanceIds == 0 then addCard("No unassigned Brainrots yet. Claim one from the Tower.", Theme.Colors.Disabled, nil) end
	for _, instanceId in instanceIds do
		local definition = definitionFor(snapshot, instanceId)
		if definition ~= nil then
			local selected = selectedInstanceId == instanceId
			addCard(
				`{if selected then "✓ SELECTED  •  " else ""}{definition.DisplayName}\nPERMANENT • {string.upper(definition.Rarity)} • +{definition.BaseProductionPerMinute} Coins/min`,
				if selected then Theme.Colors.Safe else (Theme.RarityColors[definition.Rarity] or Theme.Colors.Accent),
				function()
					selectedInstanceId = instanceId
					rebuild()
				end
			)
		end
	end
end

local function update()
	local shouldOpen = store.GetState().OpenPanel == "Farm"
	(screen :: ScreenGui).Enabled = shouldOpen
	if shouldOpen then rebuild() end
end

function FarmController.Init(context: any)
	store = context.Store
	farmRemote = context.Remotes:FindFirstChild("FarmAction") :: RemoteEvent
	screen = UIFactory.GetScreen("FarmUI", 20)
	UIFactory.Overlay(screen :: ScreenGui)
	local panel = UIFactory.Panel(screen :: ScreenGui, "FarmPanel", UDim2.new((47 / 50), 0, (21 / 25), 0), UDim2.fromScale((1 / 2), (1 / 2)))
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 300)
	constraint.MaxSize = Vector2.new(850, 700)
	constraint.Parent = panel
	UIFactory.Text(panel, "MY FARM", UDim2.new(1, -100, 0, 48), UDim2.fromOffset(22, 14), 28).Font = Enum.Font.GothamBold
	local close = UIFactory.Button(panel, "×", UDim2.fromOffset(58, 58), Theme.Colors.SurfaceRaised)
	close.Position = UDim2.new(1, -72, 0, 10)
	close.TextSize = 30
	close.Activated:Connect(function() store.SetOpenPanel(nil) end)
	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(18, 76)
	content.Size = UDim2.new(1, -36, 1, -94)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.ScrollBarThickness = 7
	content.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 9)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	UIFactory.Padding(content :: ScrollingFrame, 4)
	(screen :: ScreenGui).Enabled = false
end

function FarmController.Start()
	store.Changed:Connect(update)
	local elapsed = 0
	RobloxRunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= BalanceConfig.UI.FarmProjectionRefreshSeconds then
			elapsed = 0
			if screen ~= nil and screen.Enabled then refreshProductionCard() end
		end
	end)
	update()
end

function FarmController.HandleEvent(payload: any)
	if type(payload) ~= "table" or payload.Type ~= "GameActionResult" then return end
	if payload.Action == "Collect" then
		collectPending = false
		if payload.Success or (payload.Error ~= "TRANSACTION_SAVE_FAILED" and payload.Error ~= "COLLECT_IN_PROGRESS") then
			collectRequestId = nil
		end
		rebuild()
	elseif payload.Success and payload.Action == "PlaceBrainrot" then
		selectedInstanceId = nil
		rebuild()
	end
end

return table.freeze(FarmController)
