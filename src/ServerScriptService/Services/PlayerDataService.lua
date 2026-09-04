--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local GameConfigModule = Shared:FindFirstChild("GameConfig")
local TypesModule = Shared:FindFirstChild("Types")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local GameConfig = require(GameConfigModule)
local Types = require(TypesModule)

local internalFolder = script.Parent:FindFirstChild("PlayerData")
assert(internalFolder and internalFolder:IsA("Folder"), "Services.PlayerData is missing")

local ProfileSchemaModule = internalFolder:FindFirstChild("ProfileSchema")
local DataStoreBackendModule = internalFolder:FindFirstChild("DataStoreBackend")
local MemoryBackendModule = internalFolder:FindFirstChild("MemoryBackend")
assert(ProfileSchemaModule and ProfileSchemaModule:IsA("ModuleScript"), "PlayerData.ProfileSchema is missing")
assert(DataStoreBackendModule and DataStoreBackendModule:IsA("ModuleScript"), "PlayerData.DataStoreBackend is missing")
assert(MemoryBackendModule and MemoryBackendModule:IsA("ModuleScript"), "PlayerData.MemoryBackend is missing")

local ProfileSchema = require(ProfileSchemaModule)
local DataStoreBackend = require(DataStoreBackendModule)
local MemoryBackend = require(MemoryBackendModule)

type PlayerProfile = Types.PlayerProfile
type ProfileState = {
	Profile: PlayerProfile,
	Revision: number,
	Dirty: boolean,
	Saving: boolean,
	Updating: boolean,
	Releasing: boolean,
}

local DATA_CONFIG = GameConfig.PlayerData
local SERVER_SESSION_ID = if game.JobId ~= ""
	then game.JobId
	else `studio-{HttpService:GenerateGUID(false)}`

local profiles: { [Player]: ProfileState } = {}
local loading: { [Player]: boolean } = {}
local backend: any = nil
local mode = "Uninitialized"
local initialized = false
local started = false
local shuttingDown = false

local profileLoadedEvent = Instance.new("BindableEvent")
local profileReleasingEvent = Instance.new("BindableEvent")

local PlayerDataService = {
	Name = "PlayerDataService",
	ProfileLoaded = profileLoadedEvent.Event,
	ProfileReleasing = profileReleasingEvent.Event,
}

local function waitForOperation(state: ProfileState, timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	while state.Saving or state.Updating do
		if os.clock() >= deadline then
			return false
		end
		task.wait(DATA_CONFIG.OperationPollSeconds)
	end
	return true
end

local function saveState(player: Player, state: ProfileState, releaseLock: boolean): (boolean, string?)
	if state.Saving then
		return false, "SAVE_IN_PROGRESS"
	end

	state.Saving = true
	local savedRevision = state.Revision
	local snapshot = ProfileSchema.Clone(state.Profile)
	local success, saveError

	if releaseLock then
		success, saveError = backend:Release(player.UserId, snapshot)
	else
		success, saveError = backend:Save(player.UserId, snapshot)
	end

	state.Saving = false
	if success and state.Revision == savedRevision then
		state.Dirty = false
	end

	return success, saveError
end

local function loadPlayer(player: Player)
	if shuttingDown or profiles[player] ~= nil or loading[player] then
		return
	end

	loading[player] = true
	local profile, loadError = backend:Load(player.UserId)
	loading[player] = nil

	if player.Parent ~= Players then
		if profile ~= nil then
			local released, releaseError = backend:Release(player.UserId, profile)
			if not released then
				warn(`[PlayerDataService] Failed to release departed player {player.UserId}: {releaseError}`)
			end
		end
		return
	end

	if profile == nil then
		warn(`[PlayerDataService] Failed to load {player.UserId}: {loadError}`)
		if loadError == "PROFILE_LOCKED" then
			player:Kick("Your data is active on another server. Please wait a moment and reconnect.")
		else
			player:Kick("Your data could not be loaded safely. Please reconnect.")
		end
		return
	end

	profiles[player] = {
		Profile = profile,
		Revision = 0,
		Dirty = false,
		Saving = false,
		Updating = false,
		Releasing = false,
	}

	profileLoadedEvent:Fire(player, ProfileSchema.Clone(profile))
end

local function releasePlayer(player: Player)
	local state = profiles[player]
	if state == nil or state.Releasing then
		return
	end

	state.Releasing = true
	profileReleasingEvent:Fire(player, ProfileSchema.Clone(state.Profile))

	if not waitForOperation(state, DATA_CONFIG.OperationWaitTimeoutSeconds) then
		warn(`[PlayerDataService] Timed out waiting for profile operations for {player.UserId}`)
	end

	local success = false
	local saveError: string? = nil
	for attempt = 1, DATA_CONFIG.ReleaseRetryAttempts do
		success, saveError = saveState(player, state, true)
		if success or saveError == "SESSION_LOCK_LOST" then break end
		if attempt < DATA_CONFIG.ReleaseRetryAttempts then
			task.wait(DATA_CONFIG.ReleaseRetryDelaySeconds * attempt)
		end
	end
	if not success then
		warn(`[PlayerDataService] Failed to save/release {player.UserId} after retries: {saveError}`)
	end

	profiles[player] = nil
end

function PlayerDataService.Init()
	assert(not initialized, "PlayerDataService.Init called more than once")
	initialized = true

	if RobloxRunService:IsStudio() and DATA_CONFIG.UseMockDataInStudio then
		backend = MemoryBackend.new(DATA_CONFIG, SERVER_SESSION_ID)
		mode = "StudioMock"
		warn("[PlayerDataService] Studio memory mock enabled; data lasts for this server session only")
	else
		backend = DataStoreBackend.new(DATA_CONFIG, SERVER_SESSION_ID)
		mode = "DataStore"
	end
end

function PlayerDataService.Start()
	assert(initialized, "PlayerDataService.Init must run before Start")
	assert(not started, "PlayerDataService.Start called more than once")
	started = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)

	Players.PlayerRemoving:Connect(releasePlayer)

	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	task.spawn(function()
		while not shuttingDown do
			task.wait(DATA_CONFIG.AutosaveIntervalSeconds)
			if shuttingDown then
				break
			end

			for player, state in profiles do
				if not state.Releasing and not state.Saving and not state.Updating then
					task.spawn(function()
						local success, saveError = saveState(player, state, false)
						if not success and saveError ~= "SAVE_IN_PROGRESS" then
							warn(`[PlayerDataService] Autosave failed for {player.UserId}: {saveError}`)
						end
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		local pending = 0

		for player in profiles do
			pending += 1
			task.spawn(function()
				releasePlayer(player)
				pending -= 1
			end)
		end

		local deadline = os.clock() + DATA_CONFIG.ShutdownSaveTimeoutSeconds
		while pending > 0 and os.clock() < deadline do
			task.wait(DATA_CONFIG.OperationPollSeconds)
		end

		if pending > 0 then
			warn(`[PlayerDataService] Shutdown ended with {pending} profile save(s) unfinished`)
		end
	end)
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.GetProfile(player: Player): PlayerProfile?
	local state = profiles[player]
	if state == nil or state.Releasing then
		return nil
	end

	return ProfileSchema.Clone(state.Profile)
end

function PlayerDataService.UpdateProfile(
	player: Player,
	mutator: (profile: PlayerProfile) -> (boolean?, string?)
): (boolean, string?)
	local state = profiles[player]
	if state == nil then
		return false, "PROFILE_NOT_LOADED"
	end
	if state.Releasing then
		return false, "PROFILE_RELEASING"
	end
	if state.Updating then
		return false, "PROFILE_UPDATE_IN_PROGRESS"
	end

	state.Updating = true
	local workingCopy = ProfileSchema.Clone(state.Profile)
	local mutateSuccess, shouldCommit, rejectReason = pcall(mutator, workingCopy)

	if not mutateSuccess then
		state.Updating = false
		return false, `PROFILE_MUTATOR_FAILED: {tostring(shouldCommit)}`
	end

	if shouldCommit == false then
		state.Updating = false
		return false, rejectReason or "PROFILE_UPDATE_REJECTED"
	end

	local valid, validationError = ProfileSchema.Validate(workingCopy)
	if not valid then
		state.Updating = false
		return false, `PROFILE_VALIDATION_FAILED: {validationError}`
	end

	state.Profile = workingCopy
	state.Revision += 1
	state.Dirty = true
	state.Updating = false
	return true, nil
end

function PlayerDataService.SavePlayer(player: Player): (boolean, string?)
	local state = profiles[player]
	if state == nil then
		return false, "PROFILE_NOT_LOADED"
	end
	if state.Saving or state.Updating then
		if not waitForOperation(state, DATA_CONFIG.OperationWaitTimeoutSeconds) then
			return false, "PROFILE_OPERATION_TIMEOUT"
		end
	end
	if state.Releasing then return false, "PROFILE_RELEASING" end
	if not state.Dirty then return true, nil end

	return saveState(player, state, false)
end

function PlayerDataService.GetMode(): string
	return mode
end

return table.freeze(PlayerDataService)
