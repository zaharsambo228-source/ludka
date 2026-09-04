--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local DefinitionsModule = Shared:FindFirstChild("BrainrotDefinitions")
local BalanceConfigModule = Shared:FindFirstChild("BalanceConfig")
local GameConfigModule = Shared:FindFirstChild("GameConfig")
assert(DefinitionsModule and DefinitionsModule:IsA("ModuleScript"), "Shared.BrainrotDefinitions is missing")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")

local BrainrotDefinitions = require(DefinitionsModule)
local BalanceConfig = require(BalanceConfigModule)
local GameConfig = require(GameConfigModule)

local farmInternal = script.Parent:FindFirstChild("Farm")
assert(farmInternal and farmInternal:IsA("Folder"), "Services.Farm is missing")
local PlotBuilderModule = farmInternal:FindFirstChild("PlotBuilder")
local ProductionCalculatorModule = farmInternal:FindFirstChild("ProductionCalculator")
local playerDataInternal = script.Parent:FindFirstChild("PlayerData")
assert(PlotBuilderModule and PlotBuilderModule:IsA("ModuleScript"), "Farm.PlotBuilder is missing")
assert(
	ProductionCalculatorModule and ProductionCalculatorModule:IsA("ModuleScript"),
	"Farm.ProductionCalculator is missing"
)
assert(playerDataInternal and playerDataInternal:IsA("Folder"), "Services.PlayerData is missing")
local OperationReceiptStoreModule = playerDataInternal:FindFirstChild("OperationReceiptStore")
assert(OperationReceiptStoreModule and OperationReceiptStoreModule:IsA("ModuleScript"), "PlayerData.OperationReceiptStore is missing")
local PlotBuilder = require(PlotBuilderModule)
local ProductionCalculator = require(ProductionCalculatorModule)
local OperationReceiptStore = require(OperationReceiptStoreModule)

type PlayerPlotState = {
	Index: number,
	Model: Model,
}

local FARM_CONFIG = GameConfig.Farm
local playerDataService: any = nil
local runService: any = nil
local antiExploitService: any = nil
local farmPlotsFolder: Folder? = nil
local playerPlots: { [Player]: PlayerPlotState } = {}
local usedPlotIndexes: { [number]: boolean } = {}
local collectingPlayers: { [Player]: boolean } = {}
local initialized = false
local started = false
local farmChangedEvent = Instance.new("BindableEvent")
local coinsCollectedEvent = Instance.new("BindableEvent")

local FarmService = {
	Name = "FarmService",
	FarmChanged = farmChangedEvent.Event,
	CoinsCollected = coinsCollectedEvent.Event,
}

local function validSlotIndex(slotIndex: number): boolean
	return slotIndex % 1 == 0 and slotIndex >= 1 and slotIndex <= FARM_CONFIG.MaxSlots
end

local function allocatePlotIndex(): number?
	for plotIndex = 1, FARM_CONFIG.MaxPlots do
		if not usedPlotIndexes[plotIndex] then
			usedPlotIndexes[plotIndex] = true
			return plotIndex
		end
	end
	return nil
end

local function isNearTerminal(player: Player, terminal: BasePart, maximumDistance: number): boolean
	local character = player.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return rootPart ~= nil
		and rootPart:IsA("BasePart")
		and (rootPart.Position - terminal.Position).Magnitude <= maximumDistance
end

local function connectCollectPrompt(player: Player, plot: Model)
	local terminal = PlotBuilder.GetTerminal(plot)
	if terminal == nil then
		return
	end

	local prompt = terminal:FindFirstChild("CollectPrompt")
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		return
	end

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		if not antiExploitService.AllowAction(triggeringPlayer, "FarmAction") then
			return
		end
		if not isNearTerminal(triggeringPlayer, terminal, prompt.MaxActivationDistance + 3) then
			antiExploitService.RecordRejection(triggeringPlayer, "FarmAction", "TOO_FAR_FROM_OWN_TERMINAL")
			return
		end
		if runService.GetRunForPlayer(triggeringPlayer) ~= nil then
			return
		end

		local _, collectError = FarmService.CollectCoins(triggeringPlayer)
		if collectError ~= nil and collectError ~= "COLLECT_IN_PROGRESS" then
			warn(`[FarmService] Collect rejected for {triggeringPlayer.UserId}: {collectError}`)
		end
	end)
end

local function refreshPlot(player: Player, profile: any): Model?
	local plotState = playerPlots[player]
	if plotState == nil then
		local plotIndex = allocatePlotIndex()
		if plotIndex == nil then
			warn(`[FarmService] No free personal plot for {player.Name}`)
			return nil
		end

		local folder = farmPlotsFolder
		assert(folder ~= nil, "FarmPlots folder is unavailable")
		local plot = PlotBuilder.Create(folder, player, plotIndex, FARM_CONFIG)
		connectCollectPrompt(player, plot)
		plotState = {
			Index = plotIndex,
			Model = plot,
		}
		playerPlots[player] = plotState
	end

	PlotBuilder.Refresh(plotState.Model, profile, BrainrotDefinitions, FARM_CONFIG)
	local productionSnapshot = ProductionCalculator.Preview(profile, BrainrotDefinitions, BalanceConfig, os.time())
	PlotBuilder.UpdateTerminal(plotState.Model, productionSnapshot)
	return plotState.Model
end

local function rebuildPlayerPlot(player: Player): (Model?, string?)
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil, "PROFILE_NOT_LOADED"
	end

	local plot = refreshPlot(player, profile)
	if plot == nil then
		return nil, "NO_AVAILABLE_PLOT"
	end

	return plot, nil
end

local function cleanupPlayerPlot(player: Player)
	local plotState = playerPlots[player]
	if plotState == nil then
		return
	end

	usedPlotIndexes[plotState.Index] = nil
	collectingPlayers[player] = nil
	plotState.Model:Destroy()
	playerPlots[player] = nil
end

function FarmService.Init()
	assert(not initialized, "FarmService.Init called more than once")

	local playerDataModule = script.Parent:FindFirstChild("PlayerDataService")
	local runServiceModule = script.Parent:FindFirstChild("RunService")
	local antiExploitModule = script.Parent:FindFirstChild("AntiExploitService")
	assert(playerDataModule and playerDataModule:IsA("ModuleScript"), "Services.PlayerDataService is missing")
	assert(runServiceModule and runServiceModule:IsA("ModuleScript"), "Services.RunService is missing")
	assert(antiExploitModule and antiExploitModule:IsA("ModuleScript"), "Services.AntiExploitService is missing")
	playerDataService = require(playerDataModule)
	runService = require(runServiceModule)
	antiExploitService = require(antiExploitModule)

	local folder = Workspace:FindFirstChild("FarmPlots")
	assert(folder and folder:IsA("Folder"), "Workspace.FarmPlots is missing")
	farmPlotsFolder = folder
	initialized = true
end

function FarmService.Start()
	assert(initialized, "FarmService.Init must run before Start")
	assert(not started, "FarmService.Start called more than once")
	started = true

	playerDataService.ProfileLoaded:Connect(function(player)
		local plot, plotError = rebuildPlayerPlot(player)
		if plot == nil then
			warn(`[FarmService] Failed to build plot for {player.UserId}: {plotError}`)
		end
	end)

	playerDataService.ProfileReleasing:Connect(function(player)
		cleanupPlayerPlot(player)
	end)

	Players.PlayerRemoving:Connect(cleanupPlayerPlot)

	-- Covers a fast profile load that completed before FarmService connected.
	for _, player in Players:GetPlayers() do
		if playerDataService.IsLoaded(player) then
			rebuildPlayerPlot(player)
		end
	end

	task.spawn(function()
		while started do
			task.wait(BalanceConfig.Farm.TerminalRefreshSeconds)
			for player, plotState in playerPlots do
				local profile = playerDataService.GetProfile(player)
				if profile ~= nil then
					local snapshot = ProductionCalculator.Preview(
						profile,
						BrainrotDefinitions,
						BalanceConfig,
						os.time()
					)
					PlotBuilder.UpdateTerminal(plotState.Model, snapshot)
				end
			end
		end
	end)
end

function FarmService.GetPlot(player: Player): Model?
	local plotState = playerPlots[player]
	return if plotState == nil then nil else plotState.Model
end

function FarmService.GetSlotAssignments(player: Player): { [string]: string }?
	assert(initialized, "FarmService.Init must run before use")
	local profile = playerDataService.GetProfile(player)
	return if profile == nil then nil else profile.Farm.Slots
end

function FarmService.GetSlotModel(player: Player, slotIndex: number): Model?
	if not validSlotIndex(slotIndex) then
		return nil
	end

	local plot = FarmService.GetPlot(player)
	if plot == nil then
		return nil
	end

	local slot = plot:FindFirstChild(`Slot{slotIndex}`)
	return if slot ~= nil and slot:IsA("Model") then slot else nil
end

function FarmService.PlaceBrainrot(player: Player, slotIndex: number, instanceId: string): (boolean, string?)
	assert(initialized, "FarmService.Init must run before use")
	if not validSlotIndex(slotIndex) then
		return false, "INVALID_SLOT"
	end
	if instanceId == "" then
		return false, "INVALID_INSTANCE_ID"
	end

	local slotId = tostring(slotIndex)
	local updated, updateError = playerDataService.UpdateProfile(player, function(profile)
		if slotIndex > profile.Farm.UnlockedSlots then
			return false, "SLOT_LOCKED"
		end
		if profile.Farm.Slots[slotId] ~= nil then
			return false, "SLOT_OCCUPIED"
		end

		local instance = profile.BrainrotInstances[instanceId]
		if instance == nil then
			return false, "INSTANCE_NOT_OWNED"
		end
		if BrainrotDefinitions[instance.BrainrotId] == nil then
			return false, "UNKNOWN_BRAINROT_DEFINITION"
		end
		if instance.FarmSlotId ~= nil then
			return false, "INSTANCE_ALREADY_PLACED"
		end

		for _, assignedInstanceId in profile.Farm.Slots do
			if assignedInstanceId == instanceId then
				return false, "INSTANCE_ALREADY_PLACED"
			end
		end

		ProductionCalculator.Checkpoint(profile, BrainrotDefinitions, BalanceConfig, os.time())
		profile.Farm.Slots[slotId] = instanceId
		instance.FarmSlotId = slotId
		return true, nil
	end)

	if not updated then
		return false, updateError
	end

	local profile = playerDataService.GetProfile(player)
	if profile ~= nil then
		refreshPlot(player, profile)
	end
	farmChangedEvent:Fire(player, "Placed", slotId, instanceId)
	return true, nil
end

function FarmService.RemoveBrainrot(player: Player, slotIndex: number): (string?, string?)
	assert(initialized, "FarmService.Init must run before use")
	if not validSlotIndex(slotIndex) then
		return nil, "INVALID_SLOT"
	end

	local slotId = tostring(slotIndex)
	local removedInstanceId: string? = nil
	local updated, updateError = playerDataService.UpdateProfile(player, function(profile)
		local instanceId = profile.Farm.Slots[slotId]
		if instanceId == nil then
			return false, "SLOT_EMPTY"
		end

		local instance = profile.BrainrotInstances[instanceId]
		if instance == nil then
			return false, "INSTANCE_NOT_OWNED"
		end

		ProductionCalculator.Checkpoint(profile, BrainrotDefinitions, BalanceConfig, os.time())
		profile.Farm.Slots[slotId] = nil
		if instance.FarmSlotId == slotId then
			instance.FarmSlotId = nil
		end
		removedInstanceId = instanceId
		return true, nil
	end)

	if not updated then
		return nil, updateError
	end

	local profile = playerDataService.GetProfile(player)
	if profile ~= nil then
		refreshPlot(player, profile)
	end
	farmChangedEvent:Fire(player, "Removed", slotId, removedInstanceId)
	return removedInstanceId, nil
end

function FarmService.GetProductionSnapshot(player: Player): (any?, string?)
	assert(initialized, "FarmService.Init must run before use")
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil, "PROFILE_NOT_LOADED"
	end

	return ProductionCalculator.Preview(profile, BrainrotDefinitions, BalanceConfig, os.time()), nil
end

function FarmService.CheckpointProfileProduction(profile: any, now: number): any
	assert(initialized, "FarmService.Init must run before use")
	return ProductionCalculator.Checkpoint(profile, BrainrotDefinitions, BalanceConfig, now)
end

function FarmService.CollectCoins(player: Player, requestId: string?): (number?, string?)
	assert(initialized, "FarmService.Init must run before use")
	local operationId = requestId or HttpService:GenerateGUID(false)
	if type(operationId) ~= "string" or operationId == "" or #operationId > GameConfig.Security.MaxRemoteStringLength then
		return nil, "INVALID_REQUEST_ID"
	end
	if collectingPlayers[player] then
		return nil, "COLLECT_IN_PROGRESS"
	end
	collectingPlayers[player] = true

	local collectedAmount = 0
	local replayed = false
	local updated, updateError = playerDataService.UpdateProfile(player, function(profile)
		local receipt, receiptError = OperationReceiptStore.Find(profile, operationId, "Collect", "Farm")
		if receiptError ~= nil then return false, receiptError end
		if receipt ~= nil then
			collectedAmount = receipt.Amount
			replayed = true
			return false, "OPERATION_ALREADY_APPLIED"
		end
		local snapshot = ProductionCalculator.Checkpoint(
			profile,
			BrainrotDefinitions,
			BalanceConfig,
			os.time()
		)
		collectedAmount = snapshot.ClaimableCoins
		profile.Farm.AccruedCoins = math.max(0, profile.Farm.AccruedCoins - collectedAmount)
		profile.Coins += collectedAmount
		OperationReceiptStore.Record(profile, operationId, {
			Kind = "Collect",
			Subject = "Farm",
			Amount = collectedAmount,
			TargetLevel = nil,
			CreatedAt = os.time(),
		}, GameConfig.PlayerData.MaxOperationReceipts)
		return true, nil
	end)

	collectingPlayers[player] = nil
	if not updated and not (replayed and updateError == "OPERATION_ALREADY_APPLIED") then
		return nil, updateError
	end
	local saved, saveError = playerDataService.SavePlayer(player)
	if not saved then
		warn(`[FarmService] Collect {operationId} could not be confirmed for {player.UserId}: {saveError}`)
		return nil, "TRANSACTION_SAVE_FAILED"
	end
	if replayed then return collectedAmount, nil end

	local profile = playerDataService.GetProfile(player)
	local plot = FarmService.GetPlot(player)
	if profile ~= nil and plot ~= nil then
		refreshPlot(player, profile)
		PlotBuilder.ShowCollectFeedback(plot, collectedAmount)
	end

	if collectedAmount > 0 then
		coinsCollectedEvent:Fire(player, collectedAmount)
	end
	return collectedAmount, nil
end

function FarmService.RebuildPlayerPlot(player: Player): (Model?, string?)
	assert(initialized, "FarmService.Init must run before use")
	local plot, rebuildError = rebuildPlayerPlot(player)
	if plot ~= nil then
		farmChangedEvent:Fire(player, "Rebuilt", nil, nil)
	end
	return plot, rebuildError
end

function FarmService.DebugPlaceBrainrot(
	player: Player,
	slotIndex: number,
	instanceId: string
): (boolean, string?)
	if not RobloxRunService:IsStudio() then
		return false, "DEBUG_ONLY"
	end
	return FarmService.PlaceBrainrot(player, slotIndex, instanceId)
end

function FarmService.DebugRemoveBrainrot(player: Player, slotIndex: number): (string?, string?)
	if not RobloxRunService:IsStudio() then
		return nil, "DEBUG_ONLY"
	end
	return FarmService.RemoveBrainrot(player, slotIndex)
end

function FarmService.DebugCollectCoins(player: Player): (number?, string?)
	if not RobloxRunService:IsStudio() then
		return nil, "DEBUG_ONLY"
	end
	return FarmService.CollectCoins(player)
end

return table.freeze(FarmService)
