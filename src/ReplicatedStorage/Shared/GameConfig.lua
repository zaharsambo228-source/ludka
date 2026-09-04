--!strict

local GameConfig = {
	ConfigVersion = 2,
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
		OperationPollSeconds = (1 / 20),
	}),
	Farm = table.freeze({
		MaxPlots = 6,
		MaxSlots = 6,
		DefaultUnlockedSlots = 2,
		PlotsPerRow = 3,
		PlotSpacingX = 58,
		PlotSpacingZ = 52,
		DistrictOrigin = Vector3.new(0, 0, -118),
		PlotSize = Vector3.new(50, 1, 44),
	}),
	World = table.freeze({
		LobbyOrigin = Vector3.new(0, 0, 24),
		LobbySize = Vector3.new(170, 4, 108),
		LobbySpawn = CFrame.new(0, 4, 18),
		FarmDistrictOrigin = Vector3.new(0, -3, -92),
		FarmDistrictSize = Vector3.new(230, 4, 142),
		TowerOrigin = Vector3.new(0, 0, 220),
		TowerTierHeight = 58,
		TowerFoundationSize = Vector3.new(104, 4, 104),
		TowerApproachLength = 142,
		TowerGateDistance = 14,
		TowerGateHoldSeconds = (7 / 20),
	}),
	Run = table.freeze({
		MinPlayers = 1,
		MaxPlayers = 6,
		ClientActionCooldownSeconds = (1 / 4),
	}),
	Room = table.freeze({
		ClientActionCooldownSeconds = (3 / 25),
		MaxInteractionDistance = 12,
		HazardHitCooldownSeconds = 1,
	}),
	Reward = table.freeze({
		ClientActionCooldownSeconds = (1 / 4),
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
