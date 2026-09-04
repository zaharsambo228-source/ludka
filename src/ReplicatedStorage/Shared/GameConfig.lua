--!strict

local GameConfig = {
	ConfigVersion = 1,
	GameName = "Brainrot Tower",
	PlayerData = table.freeze({
		SchemaVersion = 5,
		StoreName = "BrainrotTowerPlayerData_v1",
		KeyPrefix = "Player_",
		UseMockDataInStudio = true,
		AutosaveIntervalSeconds = 60,
		SessionLockTimeoutSeconds = 30 * 60,
		MaxDataStoreAttempts = 3,
		RetryDelaySeconds = 2,
		ShutdownSaveTimeoutSeconds = 25,
		ReleaseRetryAttempts = 2,
		ReleaseRetryDelaySeconds = 1,
		MaxOperationReceipts = 128,
		OperationWaitTimeoutSeconds = 10,
		OperationPollSeconds = 0.05,
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
	Security = table.freeze({
		MaxRemoteStringLength = 128,
		MaxRemoteTableEntries = 8,
		RejectionWarnThreshold = 25,
		RemoteRateLimits = table.freeze({
			RunAction = table.freeze({ Capacity = 4, RefillPerSecond = 2 }),
			DecisionVote = table.freeze({ Capacity = 4, RefillPerSecond = 2 }),
			RoomAction = table.freeze({ Capacity = 10, RefillPerSecond = 6 }),
			FarmAction = table.freeze({ Capacity = 4, RefillPerSecond = 2 }),
			UpgradeAction = table.freeze({ Capacity = 3, RefillPerSecond = 1 }),
			GetPlayerSnapshot = table.freeze({ Capacity = 3, RefillPerSecond = 1 }),
		}),
	}),
	Client = table.freeze({
		InitialSnapshotAttempts = 10,
		InitialSnapshotRetrySeconds = 1,
	}),
}

return table.freeze(GameConfig)
