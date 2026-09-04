--!strict

local GameConfig = {
	ConfigVersion = 1,
	GameName = "Brainrot Tower",
	PlayerData = table.freeze({
		SchemaVersion = 4,
		StoreName = "BrainrotTowerPlayerData_v1",
		KeyPrefix = "Player_",
		UseMockDataInStudio = true,
		AutosaveIntervalSeconds = 60,
		SessionLockTimeoutSeconds = 30 * 60,
		MaxDataStoreAttempts = 3,
		RetryDelaySeconds = 2,
		ShutdownSaveTimeoutSeconds = 25,
	}),
	Farm = table.freeze({
		MaxPlots = 6,
		MaxSlots = 6,
		DefaultUnlockedSlots = 2,
		PlotsPerRow = 3,
		PlotSpacingX = 48,
		PlotSpacingZ = 38,
	}),
	Run = table.freeze({
		MinPlayers = 1,
		MaxPlayers = 6,
		ClientActionCooldownSeconds = 0.25,
	}),
	Room = table.freeze({
		ClientActionCooldownSeconds = 0.12,
		MaxInteractionDistance = 12,
		HazardHitCooldownSeconds = 1,
	}),
	Reward = table.freeze({
		ClientActionCooldownSeconds = 0.25,
		MaxClaimReceipts = 64,
		MaxDustReceipts = 64,
	}),
}

return table.freeze(GameConfig)
