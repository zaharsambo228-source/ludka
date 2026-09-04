--!strict

local BalanceConfig = {
	ConfigVersion = 1,
	Farm = table.freeze({
		EfficiencyMultipliers = table.freeze({ 1.00, 1.10, 1.25, 1.45, 1.70 }),
		OfflineStorageSeconds = table.freeze({ 30 * 60, 60 * 60, 120 * 60, 240 * 60 }),
		SlotUnlockCosts = table.freeze({
			[3] = 500,
			[4] = 2_000,
			[5] = 7_500,
			[6] = 20_000,
		}),
		EfficiencyUpgradeCosts = table.freeze({
			[2] = 400,
			[3] = 1_800,
			[4] = 6_500,
			[5] = 18_000,
		}),
		OfflineStorageUpgradeCosts = table.freeze({
			[2] = 600,
			[3] = 3_000,
			[4] = 10_000,
		}),
	}),
	Run = table.freeze({
		RarityByStage = table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Mythic" }),
		RoomPool = table.freeze({ "ReactorRun", "SignalSequence", "LaserGrid" }),
		PreparationSeconds = 1,
		TravelSeconds = 1,
		DecisionSeconds = 12,
		ConsolationDustByRarity = table.freeze({
			Common = 5,
			Uncommon = 10,
			Rare = 20,
			Epic = 35,
			Mythic = 50,
		}),
	}),
	Rooms = table.freeze({
		ReactorRun = table.freeze({
			Tiers = table.freeze({
				table.freeze({ TimeLimitSeconds = 80, BaseCells = 2, CellsPerAdditionalPlayer = 1, HazardCount = 1, HazardDamage = 10, HazardCycleSeconds = 5.5 }),
				table.freeze({ TimeLimitSeconds = 72, BaseCells = 3, CellsPerAdditionalPlayer = 1, HazardCount = 2, HazardDamage = 15, HazardCycleSeconds = 4.8 }),
				table.freeze({ TimeLimitSeconds = 66, BaseCells = 4, CellsPerAdditionalPlayer = 1, HazardCount = 3, HazardDamage = 20, HazardCycleSeconds = 4.2 }),
				table.freeze({ TimeLimitSeconds = 60, BaseCells = 5, CellsPerAdditionalPlayer = 1, HazardCount = 4, HazardDamage = 25, HazardCycleSeconds = 3.7 }),
				table.freeze({ TimeLimitSeconds = 55, BaseCells = 6, CellsPerAdditionalPlayer = 1, HazardCount = 5, HazardDamage = 30, HazardCycleSeconds = 3.2 }),
			}),
		}),
		SignalSequence = table.freeze({
			Tiers = table.freeze({
				table.freeze({ TimeLimitSeconds = 55, PanelCount = 4, SequenceLength = 3, MemorizeSeconds = 5, MaxMistakes = 4 }),
				table.freeze({ TimeLimitSeconds = 50, PanelCount = 4, SequenceLength = 4, MemorizeSeconds = 4.5, MaxMistakes = 4 }),
				table.freeze({ TimeLimitSeconds = 46, PanelCount = 5, SequenceLength = 5, MemorizeSeconds = 4, MaxMistakes = 3 }),
				table.freeze({ TimeLimitSeconds = 42, PanelCount = 6, SequenceLength = 6, MemorizeSeconds = 3.5, MaxMistakes = 3 }),
				table.freeze({ TimeLimitSeconds = 38, PanelCount = 7, SequenceLength = 8, MemorizeSeconds = 3, MaxMistakes = 2 }),
			}),
		}),
		LaserGrid = table.freeze({
			Tiers = table.freeze({
				table.freeze({ TimeLimitSeconds = 65, LaserCount = 3, LaserDamage = 8, LaserCycleSeconds = 5.5, TravelDistance = 6, CompletionRatio = 0.5 }),
				table.freeze({ TimeLimitSeconds = 60, LaserCount = 4, LaserDamage = 12, LaserCycleSeconds = 5, TravelDistance = 8, CompletionRatio = 0.6 }),
				table.freeze({ TimeLimitSeconds = 55, LaserCount = 5, LaserDamage = 16, LaserCycleSeconds = 4.5, TravelDistance = 10, CompletionRatio = 0.75 }),
				table.freeze({ TimeLimitSeconds = 50, LaserCount = 6, LaserDamage = 20, LaserCycleSeconds = 4, TravelDistance = 12, CompletionRatio = 1 }),
				table.freeze({ TimeLimitSeconds = 45, LaserCount = 7, LaserDamage = 25, LaserCycleSeconds = 3.5, TravelDistance = 14, CompletionRatio = 1 }),
			}),
		}),
	}),
}

return table.freeze(BalanceConfig)
