--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)
local WorldGeometry = require(ReplicatedStorage.Shared.WorldGeometry)

local RARITY_COLORS = {
	Common = Color3.fromRGB(168, 168, 168),
	Uncommon = Color3.fromRGB(83, 190, 104),
	Rare = Color3.fromRGB(70, 135, 235),
	Epic = Color3.fromRGB(175, 84, 235),
	Mythic = Color3.fromRGB(255, 167, 46),
}

local UPGRADE_TERMINAL_LAYOUT = {
	{ UpgradeId = "SlotUnlock", X = -14 },
	{ UpgradeId = "FarmEfficiency", X = 0 },
	{ UpgradeId = "OfflineStorage", X = 14 },
}

local PlotBuilder = {}

local function createBillboard(
	adornee: BasePart,
	name: string,
	text: string,
	offset: Vector3,
	size: UDim2
): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = (7 / 20)
	label.Parent = billboard

	return label
end

local function slotOffset(slotIndex: number): Vector3
	local column = (slotIndex - 1) % 3
	local row = math.floor((slotIndex - 1) / 3)
	return Vector3.new((column - 1) * 13, (2 / 5), -6 + row * 12)
end

local function createSlot(plot: Model, ownerUserId: number, slotIndex: number, origin: Vector3)
	local slotModel = Instance.new("Model")
	slotModel.Name = `Slot{slotIndex}`
	slotModel:SetAttribute("OwnerUserId", ownerUserId)
	slotModel:SetAttribute("SlotIndex", slotIndex)
	slotModel.Parent = plot

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.SmoothPlastic
	pad.Size = Vector3.new(8, (4 / 5), 8)
	pad.Position = origin + slotOffset(slotIndex)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = slotModel

	createBillboard(
		pad,
		"StatusGui",
		`SLOT {slotIndex}`,
		Vector3.new(0, (6 / 5), 0),
		UDim2.fromOffset(170, 48)
	)
end

function PlotBuilder.GetOrigin(plotIndex: number, _config: any): Vector3
	return WorldGeometry.GetFarmPlotOrigin(plotIndex)
end

function PlotBuilder.Create(parent: Instance, player: Player, plotIndex: number, config: any): Model
	local origin = PlotBuilder.GetOrigin(plotIndex, config)

	local plot = Instance.new("Model")
	plot.Name = `FarmPlot_{player.UserId}`
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("PlotIndex", plotIndex)

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = true
	base.Color = Color3.fromRGB(56, 80, 58)
	base.Material = Enum.Material.Grass
	base.Size = config.PlotSize
	base.Position = origin + Vector3.new(0, -(1 / 2), 0)
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = plot
	plot.PrimaryPart = base

	createBillboard(
		base,
		"OwnerGui",
		`{player.DisplayName}'s Farm`,
		Vector3.new(0, 7, 0),
		UDim2.fromOffset(300, 70)
	)

	for slotIndex = 1, config.MaxSlots do
		createSlot(plot, player.UserId, slotIndex, origin)
	end

	local terminal = Instance.new("Part")
	terminal.Name = "FarmTerminal"
	terminal.Anchored = true
	terminal.CanCollide = true
	terminal.Color = Color3.fromRGB(35, 43, 54)
	terminal.Material = Enum.Material.Metal
	terminal.Size = Vector3.new(8, 4, 2)
	terminal.Position = origin + Vector3.new(0, 2, 18)
	terminal:SetAttribute("OwnerUserId", player.UserId)
	terminal.Parent = plot

	local collectPrompt = Instance.new("ProximityPrompt")
	collectPrompt.Name = "CollectPrompt"
	collectPrompt.ActionText = "Collect Coins"
	collectPrompt.ObjectText = "Farm Terminal"
	collectPrompt.HoldDuration = BalanceConfig.Farm.PromptHoldDuration
	collectPrompt.MaxActivationDistance = BalanceConfig.Farm.PromptMaxActivationDistance
	collectPrompt.RequiresLineOfSight = false
	collectPrompt.Parent = terminal

	createBillboard(
		terminal,
		"TerminalGui",
		"FARM TERMINAL",
		Vector3.new(0, 3, 0),
		UDim2.fromOffset(240, 56)
	)

	local upgradeTerminals = Instance.new("Folder")
	upgradeTerminals.Name = "UpgradeTerminals"
	upgradeTerminals.Parent = plot

	for _, terminalLayout in UPGRADE_TERMINAL_LAYOUT do
		local upgradeTerminal = Instance.new("Part")
		upgradeTerminal.Name = `{terminalLayout.UpgradeId}Terminal`
		upgradeTerminal.Anchored = true
		upgradeTerminal.CanCollide = true
		upgradeTerminal.Color = Color3.fromRGB(42, 48, 66)
		upgradeTerminal.Material = Enum.Material.Metal
		upgradeTerminal.Size = Vector3.new(8, 4, 2)
		upgradeTerminal.Position = origin + Vector3.new(terminalLayout.X, 2, -18)
		upgradeTerminal:SetAttribute("OwnerUserId", player.UserId)
		upgradeTerminal:SetAttribute("UpgradeId", terminalLayout.UpgradeId)
		upgradeTerminal.Parent = upgradeTerminals

		local purchasePrompt = Instance.new("ProximityPrompt")
		purchasePrompt.Name = "PurchasePrompt"
		purchasePrompt.ActionText = "Buy Upgrade"
		purchasePrompt.ObjectText = terminalLayout.UpgradeId
		purchasePrompt.HoldDuration = BalanceConfig.Farm.PromptHoldDuration
		purchasePrompt.MaxActivationDistance = BalanceConfig.Farm.PromptMaxActivationDistance
		purchasePrompt.RequiresLineOfSight = false
		purchasePrompt.Parent = upgradeTerminal

		createBillboard(
			upgradeTerminal,
			"UpgradeGui",
			"UPGRADE LOADING...",
			Vector3.new(0, (7 / 2), 0),
			UDim2.fromOffset(280, 100)
		)
	end

	plot.Parent = parent
	return plot
end

function PlotBuilder.GetUpgradeTerminals(plot: Model): Folder?
	local terminals = plot:FindFirstChild("UpgradeTerminals")
	return if terminals ~= nil and terminals:IsA("Folder") then terminals else nil
end

function PlotBuilder.UpdateUpgradeTerminal(plot: Model, state: any)
	local terminals = PlotBuilder.GetUpgradeTerminals(plot)
	if terminals == nil then
		return
	end

	local terminal = terminals:FindFirstChild(`{state.Id}Terminal`)
	if terminal == nil or not terminal:IsA("BasePart") then
		return
	end

	local prompt = terminal:FindFirstChild("PurchasePrompt")
	local upgradeGui = terminal:FindFirstChild("UpgradeGui")
	local label = if upgradeGui ~= nil then upgradeGui:FindFirstChild("Label") else nil

	if state.IsMaxed then
		terminal.Color = Color3.fromRGB(71, 128, 91)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
		end
		if label ~= nil and label:IsA("TextLabel") then
			label.Text = `{state.DisplayName}\n{state.CurrentValueText}\nMAX LEVEL`
			label.TextColor3 = Color3.fromRGB(167, 255, 184)
		end
		return
	end

	terminal.Color = if state.CanAfford then Color3.fromRGB(57, 101, 73) else Color3.fromRGB(91, 57, 61)
	if prompt ~= nil and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
		prompt.ActionText = `Buy · {state.Cost} Coins`
		prompt.ObjectText = state.DisplayName
	end
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = `{state.DisplayName}\n{state.CurrentValueText} → {state.NextValueText}\nCost: {state.Cost} Coins`
		label.TextColor3 = if state.CanAfford
			then Color3.fromRGB(184, 255, 194)
			else Color3.fromRGB(255, 188, 188)
	end
end

function PlotBuilder.GetTerminal(plot: Model): BasePart?
	local terminal = plot:FindFirstChild("FarmTerminal")
	return if terminal ~= nil and terminal:IsA("BasePart") then terminal else nil
end

function PlotBuilder.UpdateTerminal(plot: Model, snapshot: any)
	local terminal = PlotBuilder.GetTerminal(plot)
	if terminal == nil then
		return
	end

	local terminalGui = terminal:FindFirstChild("TerminalGui")
	local label = if terminalGui ~= nil then terminalGui:FindFirstChild("Label") else nil
	if label ~= nil and label:IsA("TextLabel") then
		local rateText = string.format("%.1f", snapshot.ProductionPerMinute)
		label.Text = `FARM TERMINAL\n{snapshot.ClaimableCoins} ready · {rateText} Coins/min`
	end
end

function PlotBuilder.ShowCollectFeedback(plot: Model, amount: number)
	if amount <= 0 then
		return
	end

	local terminal = PlotBuilder.GetTerminal(plot)
	if terminal == nil then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CollectFeedback"
	billboard.Adornee = terminal
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(260, 70)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.Parent = terminal

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = `+{amount} Coins`
	label.TextColor3 = Color3.fromRGB(255, 226, 71)
	label.TextScaled = true
	label.TextStrokeTransparency = (1 / 4)
	label.Parent = billboard

	TweenService:Create(
		billboard,
		TweenInfo.new((7 / 5), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 7, 0) }
	):Play()
	TweenService:Create(
		label,
		TweenInfo.new((7 / 5), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	Debris:AddItem(billboard, (3 / 2))
end


local function createDisplayModel(
	slotModel: Model,
	pad: BasePart,
	instanceId: string,
	instanceData: any,
	definition: any
)
	local display = Instance.new("Model")
	display.Name = "Display"
	display:SetAttribute("BrainrotId", definition.Id)
	display:SetAttribute("InstanceId", instanceId)
	display:SetAttribute("Variant", instanceData.Variant)

	local body = Instance.new("Part")
	body.Name = definition.ModelName
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.Color = RARITY_COLORS[definition.Rarity] or Color3.new(1, 1, 1)
	body.Material = Enum.Material.SmoothPlastic
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new((17 / 5), (17 / 5), (17 / 5))
	body.CFrame = pad.CFrame * CFrame.new(0, (11 / 5), 0)
	body.Parent = display
	display.PrimaryPart = body

	createBillboard(
		body,
		"BrainrotGui",
		`{definition.DisplayName}\n{string.upper(definition.Rarity)}\n+{definition.BaseProductionPerMinute} Coins/min`,
		Vector3.new(0, (14 / 5), 0),
		UDim2.fromOffset(250, 100)
	)

	display.Parent = slotModel
end

function PlotBuilder.Refresh(plot: Model, profile: any, definitions: any, config: any)
	for slotIndex = 1, config.MaxSlots do
		local slotModel = plot:FindFirstChild(`Slot{slotIndex}`)
		if slotModel == nil or not slotModel:IsA("Model") then
			continue
		end

		local pad = slotModel:FindFirstChild("Pad")
		if pad == nil or not pad:IsA("BasePart") then
			continue
		end

		local oldDisplay = slotModel:FindFirstChild("Display")
		if oldDisplay ~= nil then
			oldDisplay:Destroy()
		end

		local unlocked = slotIndex <= profile.Farm.UnlockedSlots
		local instanceId = profile.Farm.Slots[tostring(slotIndex)]
		slotModel:SetAttribute("Unlocked", unlocked)
		slotModel:SetAttribute("OccupiedInstanceId", instanceId)

		local statusGui = pad:FindFirstChild("StatusGui")
		local statusLabel = if statusGui ~= nil then statusGui:FindFirstChild("Label") else nil

		if not unlocked then
			pad.Color = Color3.fromRGB(72, 72, 78)
			if statusLabel ~= nil and statusLabel:IsA("TextLabel") then
				statusLabel.Text = `SLOT {slotIndex}\nLOCKED`
			end
			continue
		end

		if instanceId == nil then
			pad.Color = Color3.fromRGB(73, 139, 110)
			if statusLabel ~= nil and statusLabel:IsA("TextLabel") then
				statusLabel.Text = `SLOT {slotIndex}\nEMPTY`
			end
			continue
		end

		local instanceData = profile.BrainrotInstances[instanceId]
		local definition = if instanceData ~= nil then definitions[instanceData.BrainrotId] else nil
		if instanceData == nil or definition == nil then
			pad.Color = Color3.fromRGB(180, 70, 70)
			if statusLabel ~= nil and statusLabel:IsA("TextLabel") then
				statusLabel.Text = `SLOT {slotIndex}\nINVALID DATA`
			end
			continue
		end

		pad.Color = RARITY_COLORS[definition.Rarity] or Color3.fromRGB(90, 90, 90)
		if statusLabel ~= nil and statusLabel:IsA("TextLabel") then
			statusLabel.Text = `SLOT {slotIndex}\nOCCUPIED`
		end
		createDisplayModel(slotModel, pad, instanceId, instanceData, definition)
	end
end

return table.freeze(PlotBuilder)
