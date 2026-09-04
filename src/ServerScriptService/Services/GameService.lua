--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")
local BrainrotDefinitionsModule = Shared:FindFirstChild("BrainrotDefinitions")
local GameConfigModule = Shared:FindFirstChild("GameConfig")
assert(BrainrotDefinitionsModule and BrainrotDefinitionsModule:IsA("ModuleScript"), "Shared.BrainrotDefinitions is missing")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
local BrainrotDefinitions = require(BrainrotDefinitionsModule)
local GameConfig = require(GameConfigModule)

local playerDataService: any = nil
local farmService: any = nil
local inventoryService: any = nil
local economyService: any = nil
local upgradeService: any = nil
local runService: any = nil
local roomService: any = nil
local antiExploitService: any = nil
local uiEventRemote: RemoteEvent? = nil
local farmActionRemote: RemoteEvent? = nil
local upgradeActionRemote: RemoteEvent? = nil
local snapshotRemote: RemoteFunction? = nil
local initialized = false
local started = false

local FARM_KEYS: { [string]: boolean } = { Action = true, SlotIndex = true, InstanceId = true, RequestId = true }
local COLLECT_KEYS: { [string]: boolean } = { Action = true, RequestId = true }
local PLACE_KEYS: { [string]: boolean } = { Action = true, SlotIndex = true, InstanceId = true }
local REMOVE_KEYS: { [string]: boolean } = { Action = true, SlotIndex = true }
local UPGRADE_KEYS: { [string]: boolean } = { Action = true, UpgradeId = true, RequestId = true }

local GameService = {
	Name = "GameService",
}

local function cloneSerializable<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local clone = {}
	for key, child in value :: any do
		(clone :: any)[cloneSerializable(key)] = cloneSerializable(child)
	end
	return clone :: T
end

local function countEntries(source: { [any]: any }): number
	local count = 0
	for _ in source do
		count += 1
	end
	return count
end

local function buildPlayerSnapshot(player: Player): (any?, string?)
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil, "PROFILE_NOT_LOADED"
	end
	local production, productionError = farmService.GetProductionSnapshot(player)
	if production == nil then
		return nil, productionError
	end
	local upgrades, upgradesError = upgradeService.GetAllUpgradeStates(player)
	if upgrades == nil then
		return nil, upgradesError
	end

	local run = runService.GetRunForPlayer(player)
	local room = roomService.GetActiveRoom()
	if run == nil or room == nil or room.RunId ~= run.RunId then
		room = nil
	end
	return {
		ServerTime = Workspace:GetServerTimeNow(),
		Coins = profile.Coins,
		Dust = profile.Dust,
		Inventory = cloneSerializable(profile.BrainrotInstances),
		CollectionIndex = cloneSerializable(profile.CollectionIndex),
		CollectionCount = countEntries(profile.CollectionIndex),
		DefinitionCount = countEntries(BrainrotDefinitions),
		Farm = cloneSerializable(profile.Farm),
		Production = production,
		Upgrades = upgrades,
		Stats = cloneSerializable(profile.Stats),
		Run = run,
		Room = room,
	}, nil
end

local function fireSnapshot(player: Player): any?
	local snapshot = buildPlayerSnapshot(player)
	local remote = uiEventRemote
	if snapshot ~= nil and remote ~= nil and player.Parent == Players then
		remote:FireClient(player, { Type = "PlayerSnapshot", Snapshot = snapshot })
	end
	return snapshot
end

local function sendActionResult(player: Player, action: string, success: boolean, errorCode: string?, data: any?)
	local remote = uiEventRemote
	if remote == nil or player.Parent ~= Players then
		return
	end
	remote:FireClient(player, {
		Type = "GameActionResult",
		Action = action,
		Success = success,
		Error = errorCode,
		Data = data,
		Snapshot = if success then buildPlayerSnapshot(player) else nil,
	})
end

local function rejectMalformed(player: Player, route: string, action: string, errorCode: string)
	antiExploitService.RecordRejection(player, route, errorCode)
	sendActionResult(player, action, false, errorCode, nil)
end

local function handleFarmAction(player: Player, payload: any)
	local action = if type(payload) == "table" and type(payload.Action) == "string" and #payload.Action <= 64 then payload.Action else "Unknown"
	if not antiExploitService.AllowAction(player, "FarmAction") then
		sendActionResult(player, action, false, "RATE_LIMITED", nil)
		return
	end
	local shapeValid, shapeError = antiExploitService.ValidatePayload(payload, FARM_KEYS)
	if not shapeValid or not antiExploitService.IsBoundedString(if type(payload) == "table" then payload.Action else nil) then
		rejectMalformed(player, "FarmAction", action, shapeError or "INVALID_ACTION")
		return
	end
	if runService.GetRunForPlayer(player) ~= nil then
		sendActionResult(player, action, false, "PLAYER_IN_RUN", nil)
		return
	end

	if action == "Collect" then
		local valid = antiExploitService.ValidatePayload(payload, COLLECT_KEYS)
		if not valid or not antiExploitService.IsBoundedString(payload.RequestId) then
			rejectMalformed(player, "FarmAction", action, "INVALID_COLLECT_PAYLOAD")
			return
		end
		local amount, collectError = farmService.CollectCoins(player, payload.RequestId)
		sendActionResult(player, action, amount ~= nil, collectError, { CollectedCoins = amount })
	elseif action == "PlaceBrainrot" then
		local valid = antiExploitService.ValidatePayload(payload, PLACE_KEYS)
		if not valid
			or not antiExploitService.IsFiniteInteger(payload.SlotIndex, 1, GameConfig.Farm.MaxSlots)
			or not antiExploitService.IsBoundedString(payload.InstanceId)
		then
			rejectMalformed(player, "FarmAction", action, "INVALID_PLACE_PAYLOAD")
			return
		end
		local placed, placeError = farmService.PlaceBrainrot(player, payload.SlotIndex, payload.InstanceId)
		sendActionResult(player, action, placed, placeError, nil)
	elseif action == "RemoveBrainrot" then
		local valid = antiExploitService.ValidatePayload(payload, REMOVE_KEYS)
		if not valid or not antiExploitService.IsFiniteInteger(payload.SlotIndex, 1, GameConfig.Farm.MaxSlots) then
			rejectMalformed(player, "FarmAction", action, "INVALID_REMOVE_PAYLOAD")
			return
		end
		local removedId, removeError = farmService.RemoveBrainrot(player, payload.SlotIndex)
		sendActionResult(player, action, removedId ~= nil, removeError, { InstanceId = removedId })
	else
		sendActionResult(player, action, false, "UNKNOWN_ACTION", nil)
	end
end

local function handleUpgradeAction(player: Player, payload: any)
	local action = if type(payload) == "table" and type(payload.Action) == "string" and #payload.Action <= 64 then payload.Action else "Unknown"
	if not antiExploitService.AllowAction(player, "UpgradeAction") then
		sendActionResult(player, action, false, "RATE_LIMITED", nil)
		return
	end
	local valid = antiExploitService.ValidatePayload(payload, UPGRADE_KEYS)
	if not valid
		or not antiExploitService.IsBoundedString(if type(payload) == "table" then payload.Action else nil)
		or action ~= "PurchaseUpgrade"
		or not antiExploitService.IsBoundedString(payload.UpgradeId)
		or not antiExploitService.IsBoundedString(payload.RequestId)
	then
		rejectMalformed(player, "UpgradeAction", action, "INVALID_UPGRADE_PAYLOAD")
		return
	end
	if runService.GetRunForPlayer(player) ~= nil then
		sendActionResult(player, action, false, "PLAYER_IN_RUN", nil)
		return
	end
	local purchased, state, purchaseError = upgradeService.PurchaseUpgrade(player, payload.UpgradeId, payload.RequestId)
	sendActionResult(player, action, purchased, purchaseError, state)
end

function GameService.Init()
	assert(not initialized, "GameService.Init called more than once")
	local services = script.Parent
	local function requireService(name: string): any
		local module = services:FindFirstChild(name)
		assert(module and module:IsA("ModuleScript"), `Services.{name} is missing`)
		return require(module)
	end
	playerDataService = requireService("PlayerDataService")
	farmService = requireService("FarmService")
	inventoryService = requireService("InventoryService")
	economyService = requireService("EconomyService")
	upgradeService = requireService("UpgradeService")
	runService = requireService("RunService")
	roomService = requireService("RoomService")
	antiExploitService = requireService("AntiExploitService")

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	assert(remotes and remotes:IsA("Folder"), "ReplicatedStorage.Remotes is missing")
	local uiEvent = remotes:FindFirstChild("UIEvent")
	local farmAction = remotes:FindFirstChild("FarmAction")
	local upgradeAction = remotes:FindFirstChild("UpgradeAction")
	local getPlayerSnapshot = remotes:FindFirstChild("GetPlayerSnapshot")
	assert(uiEvent and uiEvent:IsA("RemoteEvent"), "Remotes.UIEvent is missing")
	assert(farmAction and farmAction:IsA("RemoteEvent"), "Remotes.FarmAction is missing")
	assert(upgradeAction and upgradeAction:IsA("RemoteEvent"), "Remotes.UpgradeAction is missing")
	assert(getPlayerSnapshot and getPlayerSnapshot:IsA("RemoteFunction"), "Remotes.GetPlayerSnapshot is missing")
	uiEventRemote = uiEvent
	farmActionRemote = farmAction
	upgradeActionRemote = upgradeAction
	snapshotRemote = getPlayerSnapshot
	initialized = true
end

function GameService.Start()
	assert(initialized, "GameService.Init must run before Start")
	assert(not started, "GameService.Start called more than once")
	started = true
	local farmRemote = farmActionRemote
	local upgradeRemote = upgradeActionRemote
	local getSnapshot = snapshotRemote
	assert(farmRemote and upgradeRemote and getSnapshot, "GameService remotes are unavailable")
	farmRemote.OnServerEvent:Connect(handleFarmAction)
	upgradeRemote.OnServerEvent:Connect(handleUpgradeAction)
	getSnapshot.OnServerInvoke = function(player)
		if not antiExploitService.AllowAction(player, "GetPlayerSnapshot") then
			return { Success = false, Snapshot = nil, Error = "RATE_LIMITED" }
		end
		local snapshot, snapshotError = buildPlayerSnapshot(player)
		return { Success = snapshot ~= nil, Snapshot = snapshot, Error = snapshotError }
	end

	local function refresh(player: Player)
		task.defer(fireSnapshot, player)
	end
	playerDataService.ProfileLoaded:Connect(refresh)
	inventoryService.InventoryChanged:Connect(refresh)
	farmService.FarmChanged:Connect(refresh)
	farmService.CoinsCollected:Connect(refresh)
	economyService.DustChanged:Connect(refresh)
	upgradeService.UpgradePurchased:Connect(refresh)
end

return table.freeze(GameService)
