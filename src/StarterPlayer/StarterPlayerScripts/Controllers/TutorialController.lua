--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local clientFolder = script.Parent.Parent:FindFirstChild("Client")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")
local UIFactory = require(clientFolder:FindFirstChild("UIFactory") :: ModuleScript)
local Theme = require(clientFolder:FindFirstChild("Theme") :: ModuleScript)
local ProductionProjection = require(clientFolder:FindFirstChild("ProductionProjection") :: ModuleScript)
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)

local store: any = nil
local runAction: RemoteEvent? = nil
local screen: ScreenGui? = nil
local panel: Frame? = nil
local hintLabel: TextLabel? = nil
local actionButton: TextButton? = nil
local currentAction: string? = nil
local completionVersion = 0
local completionActive = false
local TutorialController = { Name = "TutorialController" }

local function countOccupiedSlots(snapshot: any): number
	local count = 0
	for _ in snapshot.Farm.Slots do count += 1 end
	return count
end

local function hasPurchasedUpgrade(snapshot: any): boolean
	local upgrades = snapshot.Upgrades
	return upgrades.SlotUnlock.CurrentLevel > UpgradeDefinitions.SlotUnlock.InitialLevel
		or upgrades.FarmEfficiency.CurrentLevel > UpgradeDefinitions.FarmEfficiency.InitialLevel
		or upgrades.OfflineStorage.CurrentLevel > UpgradeDefinitions.OfflineStorage.InitialLevel
end

local function cheapestAvailableUpgrade(snapshot: any): number?
	local cheapest: number? = nil
	for _, upgrade in snapshot.Upgrades do
		if not upgrade.IsMaxed and upgrade.Cost ~= nil and (cheapest == nil or upgrade.Cost < cheapest) then
			cheapest = upgrade.Cost
		end
	end
	return cheapest
end

local function showHint(text: string, actionLabel: string?, action: string?)
	(screen :: ScreenGui).Enabled = true
	(panel :: Frame).Visible = true
	(hintLabel :: TextLabel).Text = text
	currentAction = action
	(actionButton :: TextButton).Visible = actionLabel ~= nil
	(actionButton :: TextButton).Text = actionLabel or ""
end

local function hideHint()
	currentAction = nil
	if screen ~= nil then screen.Enabled = false end
end

local function update()
	if completionActive then return end
	local state = store.GetState()
	local snapshot = state.Snapshot
	if snapshot == nil then
		showHint("FIRST STEPS\nLoading your farm…", nil, nil)
		return
	end

	local run = state.Run
	if run ~= nil and run.State ~= "WAITING" then
		if run.State == "ROOM" and state.Room ~= nil then
			showHint(`TOWER OBJECTIVE\n{state.Room.ObjectiveText}`, nil, nil)
		elseif run.State == "DECISION" then
			hideHint()
		else
			showHint(`TOWER RUN\n{string.gsub(run.State, "_", " ")} — Stage {run.Stage} reward: {string.upper(run.CurrentRarity)}`, nil, nil)
		end
		return
	end

	if (snapshot.Stats.Claims or 0) < BalanceConfig.Tutorial.RequiredClaims then
		showHint("FIRST STEP\nStart the Tower, finish a challenge, then CLAIM your first permanent Brainrot.", "START FIRST RUN", "StartRun")
		return
	end
	if countOccupiedSlots(snapshot) == 0 then
		showHint("PLACE YOUR REWARD\nOpen Farm, select a PERMANENT Brainrot, then tap an empty unlocked slot.", "OPEN FARM", "OpenFarm")
		return
	end
	if hasPurchasedUpgrade(snapshot) then
		hideHint()
		return
	end

	local claimable = ProductionProjection.EstimateClaimable(snapshot)
	local cheapest = cheapestAvailableUpgrade(snapshot)
	if claimable >= BalanceConfig.Tutorial.MinimumCollectableCoins then
		showHint(`COLLECT FARM COINS\nYour Brainrots produced {UIFactory.FormatNumber(claimable)} Coins. The server confirms the final amount.`, "OPEN FARM & COLLECT", "OpenFarm")
	elseif cheapest ~= nil and snapshot.Coins >= cheapest then
		showHint(`BUY A GUARANTEED UPGRADE\nYou have {UIFactory.FormatNumber(snapshot.Coins)} Coins. Every upgrade shows its exact before → after effect.`, "OPEN UPGRADES", "OpenUpgrades")
	elseif (snapshot.Coins or 0) == 0 then
		showHint(`FARM IS WORKING\nProduction: +{UIFactory.FormatNumber(snapshot.Production.ProductionPerMinute or 0)} Coins/min. Wait briefly, then collect.`, "OPEN FARM", "OpenFarm")
	else
		showHint(`GROW TOWARD AN UPGRADE\nYou have {UIFactory.FormatNumber(snapshot.Coins)} Coins; the cheapest upgrade costs {UIFactory.FormatNumber(cheapest or 0)}. Your farm keeps working during another run.`, "START ANOTHER RUN", "StartRun")
	end
end

local function runCurrentAction()
	if currentAction == "OpenFarm" then
		store.SetOpenPanel("Farm")
	elseif currentAction == "OpenUpgrades" then
		store.SetOpenPanel("Upgrades")
	elseif currentAction == "StartRun" then
		completionActive = false
		hideHint()
		store.SetOpenPanel(nil)
		(runAction :: RemoteEvent):FireServer({ Action = "RequestStart" })
	end
end

local function showCompletion()
	completionVersion += 1
	local version = completionVersion
	completionActive = true
	showHint("FIRST LOOP COMPLETE\nYour permanent Brainrot now powers an upgraded farm. Start another Tower run to grow faster.", "START NEXT RUN", "StartRun")
	task.delay(BalanceConfig.UI.TutorialCompletionSeconds, function()
		if completionVersion == version then
			completionActive = false
			update()
		end
	end)
end

function TutorialController.Init(context: any)
	store = context.Store
	runAction = context.Remotes:FindFirstChild("RunAction") :: RemoteEvent
	screen = UIFactory.GetScreen("TutorialUI", 15)
	panel = UIFactory.Panel(screen :: ScreenGui, "TutorialPanel", UDim2.new(0.9, 0, 0, 132), UDim2.new(0.5, 0, 1, -92))
	(panel :: Frame).AnchorPoint = Vector2.new(0.5, 1)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(300, 132)
	constraint.MaxSize = Vector2.new(520, 132)
	constraint.Parent = panel
	hintLabel = UIFactory.Text(panel :: Frame, "FIRST STEPS", UDim2.new(1, -28, 0, 72), UDim2.fromOffset(14, 7), 15)
	(hintLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	actionButton = UIFactory.Button(panel :: Frame, "CONTINUE", UDim2.new(1, -28, 0, 46), Theme.Colors.Accent)
	(actionButton :: TextButton).Position = UDim2.fromOffset(14, 80)
	(actionButton :: TextButton).TextSize = 15
	(actionButton :: TextButton).Activated:Connect(runCurrentAction)
	(screen :: ScreenGui).Enabled = false
end

function TutorialController.Start()
	store.Changed:Connect(update)
	local elapsed = 0
	RobloxRunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= BalanceConfig.UI.TutorialRefreshSeconds then
			elapsed = 0
			update()
		end
	end)
	update()
end

function TutorialController.HandleEvent(payload: any)
	if type(payload) == "table" and payload.Type == "GameActionResult" and payload.Success and payload.Action == "PurchaseUpgrade" then
		showCompletion()
	end
end

return table.freeze(TutorialController)
