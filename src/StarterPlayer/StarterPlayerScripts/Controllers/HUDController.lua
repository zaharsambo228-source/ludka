--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local clientFolder = script.Parent.Parent:FindFirstChild("Client")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")
local UIFactory = require(clientFolder:FindFirstChild("UIFactory") :: ModuleScript)
local Theme = require(clientFolder:FindFirstChild("Theme") :: ModuleScript)
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)

local store: any = nil
local runAction: RemoteEvent? = nil
local coinsLabel: TextLabel? = nil
local dustLabel: TextLabel? = nil
local collectionLabel: TextLabel? = nil
local productionLabel: TextLabel? = nil
local runPanel: Frame? = nil
local stageLabel: TextLabel? = nil
local roomLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local progressLabel: TextLabel? = nil
local towerButton: TextButton? = nil
local toastLabel: TextLabel? = nil
local toastVersion = 0
local HUDController = { Name = "HUDController" }

local function makePill(parent: Instance, order: number, text: string, color: Color3): TextLabel
	local label = UIFactory.Text(parent, text, UDim2.new((9 / 40), 0, 0, 42), nil, 14, color)
	label.Name = `Pill{order}`
	label.LayoutOrder = order
	label.BackgroundColor3 = Theme.Colors.Surface
	label.BackgroundTransparency = (2 / 25)
	label.TextXAlignment = Enum.TextXAlignment.Center
	UIFactory.Round(label, 12)
	UIFactory.Stroke(label, color, 1)
	return label
end

local function showToast(text: string, color: Color3?)
	local label = toastLabel
	if label == nil then return end
	toastVersion += 1
	local version = toastVersion
	label.Text = text
	label.TextColor3 = color or Theme.Colors.Text
	label.Visible = true
	task.delay(BalanceConfig.UI.ToastSeconds, function()
		if toastVersion == version and label.Parent ~= nil then label.Visible = false end
	end)
end

local function update()
	local state = store.GetState()
	local snapshot = state.Snapshot
	if snapshot ~= nil then
		(coinsLabel :: TextLabel).Text = `◉ {UIFactory.FormatNumber(snapshot.Coins or 0)} Coins`
		(dustLabel :: TextLabel).Text = `✦ {UIFactory.FormatNumber(snapshot.Dust or 0)} Dust`
		(collectionLabel :: TextLabel).Text = `Index {snapshot.CollectionCount or 0}/{snapshot.DefinitionCount or 0}`
		local production = snapshot.Production
		(productionLabel :: TextLabel).Text = if production ~= nil then `Farm +{UIFactory.FormatNumber(production.ProductionPerMinute or 0)}/min` else "Farm loading…"
	end
	local run = state.Run
	(runPanel :: Frame).Visible = run ~= nil and run.State ~= "WAITING"
	if towerButton ~= nil then
		local canStart = run == nil or run.State == "WAITING"
		towerButton.Text = if canStart then "START TOWER" else "TOWER ACTIVE"
		towerButton.Active = canStart
		towerButton.AutoButtonColor = canStart
		towerButton.BackgroundColor3 = if canStart then Theme.Colors.Risk else Theme.Colors.Disabled
	end
	if run ~= nil then
		(stageLabel :: TextLabel).Text = `STAGE {run.Stage} / {#BalanceConfig.Run.RarityByStage}  •  {string.upper(run.CurrentRarity)}  •  {#run.ParticipantUserIds} PLAYERS`
		(roomLabel :: TextLabel).Text = if state.Room ~= nil then state.Room.DisplayName else string.gsub(run.State, "_", " ")
		local room = state.Room
		if room ~= nil then
			local completed = room.Progress or 0
			local required = room.RequiredProgress or 0
			(progressLabel :: TextLabel).Text = if required > 0 then `{room.Phase or "ACTIVE"}  •  {completed}/{required}` else (room.Phase or "ACTIVE")
		else
			(progressLabel :: TextLabel).Text = ""
		end
	end
end

function HUDController.Init(context: any)
	store = context.Store
	runAction = context.Remotes:FindFirstChild("RunAction") :: RemoteEvent
	local screen = UIFactory.GetScreen("MainHUD", 10)
	local topBar = Instance.new("Frame")
	topBar.AnchorPoint = Vector2.new((1 / 2), 0)
	topBar.Position = UDim2.new((1 / 2), 0, 0, 10)
	topBar.Size = UDim2.new(1, -24, 0, 44)
	topBar.BackgroundTransparency = 1
	topBar.Parent = screen
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.Padding = UDim.new(0, 8)
	topLayout.Parent = topBar
	coinsLabel = makePill(topBar, 1, "◉ 0 Coins", Theme.Colors.Coins)
	dustLabel = makePill(topBar, 2, "✦ 0 Dust", Theme.Colors.Dust)
	collectionLabel = makePill(topBar, 3, "Index 0/0", Theme.Colors.Accent)
	productionLabel = makePill(topBar, 4, "Farm loading…", Theme.Colors.Safe)

	runPanel = UIFactory.Panel(screen, "RunHUD", UDim2.new((23 / 25), 0, 0, 118), UDim2.new((1 / 2), 0, 0, 112))
	(runPanel :: Frame).AnchorPoint = Vector2.new((1 / 2), 0)
	local runConstraint = Instance.new("UISizeConstraint")
	runConstraint.MinSize = Vector2.new(300, 118)
	runConstraint.MaxSize = Vector2.new(470, 118)
	runConstraint.Parent = runPanel
	stageLabel = UIFactory.Text(runPanel :: Frame, "STAGE", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 10), 21)
	(stageLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	roomLabel = UIFactory.Text(runPanel :: Frame, "ROOM", UDim2.new(1, -86, 0, 28), UDim2.fromOffset(16, 52), 16, Theme.Colors.Muted)
	timerLabel = UIFactory.Text(runPanel :: Frame, "", UDim2.fromOffset(64, 28), UDim2.new(1, -76, 0, 52), 18, Theme.Colors.Coins)
	(timerLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Right
	progressLabel = UIFactory.Text(runPanel :: Frame, "", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 84), 14, Theme.Colors.Muted)
	(progressLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center

	local nav = Instance.new("Frame")
	nav.AnchorPoint = Vector2.new((1 / 2), 1)
	nav.Position = UDim2.new((1 / 2), 0, 1, -14)
	nav.Size = UDim2.new(1, -24, 0, 66)
	nav.BackgroundTransparency = 1
	nav.Parent = screen
	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.Padding = UDim.new(0, 10)
	navLayout.Parent = nav
	local navigationButtons: { any } = {
		{ Label = "FARM", Panel = "Farm", Color = Theme.Colors.Safe },
		{ Label = "INVENTORY", Panel = "Inventory", Color = Theme.Colors.Accent },
		{ Label = "UPGRADES", Panel = "Upgrades", Color = Theme.Colors.Dust },
	}
	for _, data in navigationButtons do
		local button = UIFactory.Button(nav, data.Label, UDim2.new((11 / 50), 0, 0, 62), data.Color)
		button.TextSize = 14
		button.Activated:Connect(function() store.SetOpenPanel(data.Panel) end)
	end
	towerButton = UIFactory.Button(nav, "START TOWER", UDim2.new((11 / 50), 0, 0, 62), Theme.Colors.Risk)
	(towerButton :: TextButton).TextSize = 14
	(towerButton :: TextButton).Activated:Connect(function()
		store.SetOpenPanel(nil)
		(runAction :: RemoteEvent):FireServer({ Action = "RequestStart" })
	end)

	toastLabel = UIFactory.Text(screen, "", UDim2.new((9 / 10), 0, 0, 48), UDim2.new((1 / 2), 0, 1, -148), 17)
	(toastLabel :: TextLabel).AnchorPoint = Vector2.new((1 / 2), 0)
	local toastConstraint = Instance.new("UISizeConstraint")
	toastConstraint.MaxSize = Vector2.new(520, 48)
	toastConstraint.MinSize = Vector2.new(280, 48)
	toastConstraint.Parent = toastLabel
	(toastLabel :: TextLabel).BackgroundColor3 = Theme.Colors.Surface
	(toastLabel :: TextLabel).BackgroundTransparency = (3 / 50)
	(toastLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	(toastLabel :: TextLabel).Visible = false
	UIFactory.Round(toastLabel :: TextLabel, 12)
	update()
end

function HUDController.Start()
	store.Changed:Connect(update)
	RobloxRunService.RenderStepped:Connect(function()
		local room = store.GetState().Room
		if timerLabel ~= nil then
			timerLabel.Text = if room ~= nil then `{math.max(0, math.ceil(room.EndsAt - Workspace:GetServerTimeNow()))}s` else ""
		end
	end)
end

function HUDController.HandleEvent(payload: any)
	if type(payload) ~= "table" then return end
	if payload.Type == "GameActionResult" then
		if payload.Success then
			if payload.Action == "Collect" then
				showToast(`Collected +{UIFactory.FormatNumber(payload.Data.CollectedCoins or 0)} Coins`, Theme.Colors.Coins)
			elseif payload.Action == "PurchaseUpgrade" then showToast("Upgrade purchased", Theme.Colors.Safe)
			else showToast("Farm updated", Theme.Colors.Safe) end
		else showToast(payload.Error or "Action rejected", Theme.Colors.Risk) end
	elseif payload.Type == "RunActionResult" and not payload.Success then
		showToast(payload.Error or "Could not start run", Theme.Colors.Risk)
	end
end

return table.freeze(HUDController)
