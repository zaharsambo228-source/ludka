--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local clientFolder = script.Parent.Parent:FindFirstChild("Client")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")
local UIFactory = require(clientFolder:FindFirstChild("UIFactory") :: ModuleScript)
local Theme = require(clientFolder:FindFirstChild("Theme") :: ModuleScript)
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)

local store: any = nil
local upgradeRemote: RemoteEvent? = nil
local screen: ScreenGui? = nil
local coinsLabel: TextLabel? = nil
local content: ScrollingFrame? = nil
local purchasePending = false
local purchaseRequestId: string? = nil
local purchaseUpgradeId: string? = nil
local UpgradeController = { Name = "UpgradeController" }
local rebuild: () -> ()

local upgradeOrder = { "SlotUnlock", "FarmEfficiency", "OfflineStorage" }
local effectText: { [string]: string } = {
	SlotUnlock = "Adds one usable physical pedestal to your farm.",
	FarmEfficiency = "Multiplies the combined production of all placed Brainrots.",
	OfflineStorage = "Raises the maximum production time stored while you are away.",
}

local function addUpgradeCard(upgradeId: string, state: any, coins: number)
	local frame = content
	if frame == nil then return end
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.Colors.SurfaceRaised
	card.Size = UDim2.new(1, -12, 0, 184)
	local children = frame:GetChildren()
	card.LayoutOrder = #children
	card.Parent = frame
	UIFactory.Round(card, 14)
	UIFactory.Stroke(card, if state.IsMaxed then Theme.Colors.Safe else Theme.Colors.Dust, 2)

	local title = UIFactory.Text(card, state.DisplayName, UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 10), 21)
	title.Font = Enum.Font.GothamBold
	local levelText = if state.IsMaxed then `LEVEL {state.CurrentLevel}/{state.MaxLevel}  •  MAX` else `LEVEL {state.CurrentLevel}/{state.MaxLevel}`
	UIFactory.Text(card, levelText, UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 40), 14, if state.IsMaxed then Theme.Colors.Safe else Theme.Colors.Muted)
	local values = if state.IsMaxed then `CURRENT EFFECT: {state.CurrentValueText}` else `EFFECT: {state.CurrentValueText}  →  {state.NextValueText}`
	local valuesLabel = UIFactory.Text(card, values, UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 64), 18, Theme.Colors.Coins)
	valuesLabel.Font = Enum.Font.GothamBold
	UIFactory.Text(card, effectText[upgradeId] or state.Description, UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 94), 14, Theme.Colors.Muted)

	local buttonText: string
	local buttonColor: Color3
	local isRetry = purchaseRequestId ~= nil and purchaseUpgradeId == upgradeId
	local canBuy = not purchasePending and (isRetry or (not state.IsMaxed and state.Cost ~= nil and coins >= state.Cost))
	if purchasePending then
		buttonText = "PURCHASE PENDING…"
		buttonColor = Theme.Colors.Disabled
	elseif isRetry then
		buttonText = "RETRY PURCHASE SAVE"
		buttonColor = Theme.Colors.Dust
	elseif state.IsMaxed then
		buttonText = "MAXIMUM UPGRADE REACHED"
		buttonColor = Theme.Colors.Safe
	elseif canBuy then
		buttonText = `BUY FOR {UIFactory.FormatNumber(state.Cost)} COINS`
		buttonColor = Theme.Colors.Dust
	else
		buttonText = `NEED {UIFactory.FormatNumber(state.Cost or 0)} COINS`
		buttonColor = Theme.Colors.Disabled
	end
	local purchase = UIFactory.Button(card, buttonText, UDim2.new(1, -32, 0, 48), buttonColor)
	purchase.Position = UDim2.fromOffset(16, 130)
	purchase.TextSize = 15
	purchase.Active = canBuy
	purchase.AutoButtonColor = canBuy
	if canBuy then
		purchase.Activated:Connect(function()
			if purchasePending then return end
			if purchaseRequestId == nil or purchaseUpgradeId ~= upgradeId then
				purchaseRequestId = HttpService:GenerateGUID(false)
				purchaseUpgradeId = upgradeId
			end
			local sentRequestId = purchaseRequestId
			purchasePending = true
			(upgradeRemote :: RemoteEvent):FireServer({
				Action = "PurchaseUpgrade",
				UpgradeId = upgradeId,
				RequestId = sentRequestId,
			})
			rebuild()
			task.delay(BalanceConfig.UI.TransactionRetrySeconds, function()
				if purchasePending and purchaseRequestId == sentRequestId then
					purchasePending = false
					rebuild()
				end
			end)
		end)
	end
end

rebuild = function()
	local frame = content
	if frame == nil then return end
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
	local snapshot = store.GetState().Snapshot
	if snapshot == nil then
		(coinsLabel :: TextLabel).Text = "Loading upgrades…"
		return
	end
	local coins = snapshot.Coins or 0
	(coinsLabel :: TextLabel).Text = `BALANCE  •  {UIFactory.FormatNumber(coins)} COINS`
	for _, upgradeId in upgradeOrder do
		local state = snapshot.Upgrades[upgradeId]
		if state ~= nil then addUpgradeCard(upgradeId, state, coins) end
	end
end

local function update()
	local isOpen = store.GetState().OpenPanel == "Upgrades"
	(screen :: ScreenGui).Enabled = isOpen
	if isOpen then rebuild() end
end

function UpgradeController.Init(context: any)
	store = context.Store
	upgradeRemote = context.Remotes:FindFirstChild("UpgradeAction") :: RemoteEvent
	screen = UIFactory.GetScreen("UpgradeUI", 20)
	UIFactory.Overlay(screen :: ScreenGui)
	local panel = UIFactory.Panel(screen :: ScreenGui, "UpgradePanel", UDim2.new(0.94, 0, 0.84, 0), UDim2.fromScale(0.5, 0.5))
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 300)
	constraint.MaxSize = Vector2.new(760, 700)
	constraint.Parent = panel
	UIFactory.Text(panel, "FARM UPGRADES", UDim2.new(1, -100, 0, 44), UDim2.fromOffset(22, 12), 26).Font = Enum.Font.GothamBold
	local close = UIFactory.Button(panel, "×", UDim2.fromOffset(58, 58), Theme.Colors.SurfaceRaised)
	close.Position = UDim2.new(1, -72, 0, 10)
	close.TextSize = 30
	close.Activated:Connect(function() store.SetOpenPanel(nil) end)
	coinsLabel = UIFactory.Text(panel, "Loading upgrades…", UDim2.new(1, -44, 0, 32), UDim2.fromOffset(22, 58), 16, Theme.Colors.Coins)
	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(18, 96)
	content.Size = UDim2.new(1, -36, 1, -114)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.ScrollBarThickness = 7
	content.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	UIFactory.Padding(content :: ScrollingFrame, 4)
	(screen :: ScreenGui).Enabled = false
end

function UpgradeController.Start()
	store.Changed:Connect(update)
	update()
end

function UpgradeController.HandleEvent(payload: any)
	if type(payload) == "table" and payload.Type == "GameActionResult" and payload.Action == "PurchaseUpgrade" then
		purchasePending = false
		if payload.Success or (payload.Error ~= "TRANSACTION_SAVE_FAILED" and payload.Error ~= "PURCHASE_IN_PROGRESS") then
			purchaseRequestId = nil
			purchaseUpgradeId = nil
		end
		rebuild()
	end
end

return table.freeze(UpgradeController)
