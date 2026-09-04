--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local UpgradeDefinitionsModule = Shared:FindFirstChild("UpgradeDefinitions")
assert(
	UpgradeDefinitionsModule and UpgradeDefinitionsModule:IsA("ModuleScript"),
	"Shared.UpgradeDefinitions is missing"
)
local UpgradeDefinitions = require(UpgradeDefinitionsModule)

local upgradeInternal = script.Parent:FindFirstChild("Upgrade")
assert(upgradeInternal and upgradeInternal:IsA("Folder"), "Services.Upgrade is missing")
local StateBuilderModule = upgradeInternal:FindFirstChild("StateBuilder")
assert(StateBuilderModule and StateBuilderModule:IsA("ModuleScript"), "Upgrade.StateBuilder is missing")
local StateBuilder = require(StateBuilderModule)

local farmInternal = script.Parent:FindFirstChild("Farm")
assert(farmInternal and farmInternal:IsA("Folder"), "Services.Farm is missing")
local PlotBuilderModule = farmInternal:FindFirstChild("PlotBuilder")
assert(PlotBuilderModule and PlotBuilderModule:IsA("ModuleScript"), "Farm.PlotBuilder is missing")
local PlotBuilder = require(PlotBuilderModule)

local playerDataService: any = nil
local farmService: any = nil
local initialized = false
local started = false
local purchasingPlayers: { [Player]: boolean } = {}
local connectedPlots: { [Player]: Model } = {}
local upgradePurchasedEvent = Instance.new("BindableEvent")

local UpgradeService = {
	Name = "UpgradeService",
	UpgradePurchased = upgradePurchasedEvent.Event,
}

local function isNearTerminal(player: Player, terminal: BasePart, maximumDistance: number): boolean
	local character = player.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return rootPart ~= nil
		and rootPart:IsA("BasePart")
		and (rootPart.Position - terminal.Position).Magnitude <= maximumDistance
end

local function getStateFromProfile(profile: any, upgradeId: string): (any?, string?)
	local definition = UpgradeDefinitions[upgradeId]
	if definition == nil then
		return nil, "UNKNOWN_UPGRADE_ID"
	end
	return StateBuilder.Build(profile, definition), nil
end

local function refreshPlayerTerminals(player: Player)
	local profile = playerDataService.GetProfile(player)
	local plot = farmService.GetPlot(player)
	if profile == nil or plot == nil then
		return
	end

	for _, definition in UpgradeDefinitions do
		PlotBuilder.UpdateUpgradeTerminal(plot, StateBuilder.Build(profile, definition))
	end
end

local function connectPlayerPlot(player: Player)
	local plot = farmService.GetPlot(player)
	if plot == nil then
		return
	end
	if connectedPlots[player] == plot then
		refreshPlayerTerminals(player)
		return
	end
	connectedPlots[player] = plot

	local terminals = PlotBuilder.GetUpgradeTerminals(plot)
	if terminals == nil then
		return
	end

	for _, terminal in terminals:GetChildren() do
		if not terminal:IsA("BasePart") then
			continue
		end

		local upgradeId = terminal:GetAttribute("UpgradeId")
		local prompt = terminal:FindFirstChild("PurchasePrompt")
		if type(upgradeId) ~= "string" or UpgradeDefinitions[upgradeId] == nil then
			continue
		end
		if prompt == nil or not prompt:IsA("ProximityPrompt") then
			continue
		end
		local promptTerminal = terminal
		local promptUpgradeId = upgradeId
		local purchasePrompt = prompt

		prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer ~= player then
				return
			end
			if not isNearTerminal(triggeringPlayer, promptTerminal, purchasePrompt.MaxActivationDistance + 3) then
				return
			end

			local purchased, _, purchaseError = UpgradeService.PurchaseUpgrade(triggeringPlayer, promptUpgradeId)
			if not purchased and purchaseError ~= "PURCHASE_IN_PROGRESS" and purchaseError ~= "INSUFFICIENT_COINS" then
				warn(`[UpgradeService] Purchase rejected for {triggeringPlayer.UserId}: {purchaseError}`)
			end
		end)
	end

	refreshPlayerTerminals(player)
end

function UpgradeService.Init()
	assert(not initialized, "UpgradeService.Init called more than once")

	local playerDataModule = script.Parent:FindFirstChild("PlayerDataService")
	local farmServiceModule = script.Parent:FindFirstChild("FarmService")
	assert(playerDataModule and playerDataModule:IsA("ModuleScript"), "Services.PlayerDataService is missing")
	assert(farmServiceModule and farmServiceModule:IsA("ModuleScript"), "Services.FarmService is missing")

	playerDataService = require(playerDataModule)
	farmService = require(farmServiceModule)
	initialized = true
end

function UpgradeService.Start()
	assert(initialized, "UpgradeService.Init must run before Start")
	assert(not started, "UpgradeService.Start called more than once")
	started = true

	playerDataService.ProfileLoaded:Connect(function(player)
		connectPlayerPlot(player)
	end)
	playerDataService.ProfileReleasing:Connect(function(player)
		purchasingPlayers[player] = nil
		connectedPlots[player] = nil
	end)
	farmService.CoinsCollected:Connect(refreshPlayerTerminals)

	for _, player in Players:GetPlayers() do
		if playerDataService.IsLoaded(player) then
			connectPlayerPlot(player)
		end
	end
end

function UpgradeService.GetUpgradeState(player: Player, upgradeId: string): (any?, string?)
	assert(initialized, "UpgradeService.Init must run before use")
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil, "PROFILE_NOT_LOADED"
	end
	return getStateFromProfile(profile, upgradeId)
end

function UpgradeService.GetAllUpgradeStates(player: Player): ({ [string]: any }?, string?)
	assert(initialized, "UpgradeService.Init must run before use")
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil, "PROFILE_NOT_LOADED"
	end

	local states = {}
	for upgradeId, definition in UpgradeDefinitions do
		states[upgradeId] = StateBuilder.Build(profile, definition)
	end
	return states, nil
end

function UpgradeService.PurchaseUpgrade(player: Player, upgradeId: string): (boolean, any?, string?)
	assert(initialized, "UpgradeService.Init must run before use")
	if UpgradeDefinitions[upgradeId] == nil then
		return false, nil, "UNKNOWN_UPGRADE_ID"
	end
	if purchasingPlayers[player] then
		return false, nil, "PURCHASE_IN_PROGRESS"
	end
	purchasingPlayers[player] = true

	local purchasedState: any = nil
	local updated, updateError = playerDataService.UpdateProfile(player, function(profile)
		local state = StateBuilder.Build(profile, UpgradeDefinitions[upgradeId])
		if state.IsMaxed then
			return false, "MAX_LEVEL"
		end
		if state.Cost == nil or state.NextLevel == nil then
			return false, "INVALID_UPGRADE_DEFINITION"
		end
		if profile.Coins < state.Cost then
			return false, "INSUFFICIENT_COINS"
		end

		-- Accrue with the old efficiency/cap before changing either value.
		farmService.CheckpointProfileProduction(profile, os.time())
		profile.Coins -= state.Cost
		StateBuilder.ApplyLevel(profile, upgradeId, state.NextLevel)
		purchasedState = StateBuilder.Build(profile, UpgradeDefinitions[upgradeId])
		return true, nil
	end)

	purchasingPlayers[player] = nil
	if not updated then
		refreshPlayerTerminals(player)
		return false, nil, updateError
	end

	farmService.RebuildPlayerPlot(player)
	refreshPlayerTerminals(player)
	upgradePurchasedEvent:Fire(player, upgradeId, purchasedState)
	return true, purchasedState, nil
end

function UpgradeService.DebugPurchaseUpgrade(player: Player, upgradeId: string): (boolean, any?, string?)
	if not RobloxRunService:IsStudio() then
		return false, nil, "DEBUG_ONLY"
	end
	return UpgradeService.PurchaseUpgrade(player, upgradeId)
end

return table.freeze(UpgradeService)
