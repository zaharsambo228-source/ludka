--!strict

export type RunId = string
export type DecisionId = string
export type DecisionVoteChoice = "CLAIM" | "UPGRADE"
export type DecisionResult = "CLAIM" | "UPGRADE"
export type RunState =
	"WAITING"
	| "PREPARATION"
	| "TRAVEL"
	| "ROOM"
	| "DECISION"
	| "RESULTS"
	| "RETURN_TO_LOBBY"
export type BrainrotInstanceId = string
export type BrainrotRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic"
export type RoomStatus = "ACTIVE" | "SUCCESS" | "FAILED" | "CANCELLED"
export type PendingReward = {
	PendingRewardId: string,
	BrainrotId: string,
	DisplayName: string,
	Rarity: BrainrotRarity,
	BaseProductionPerMinute: number,
	Stage: number,
	SourceRoomId: string,
	CreatedAt: number,
}

export type ClaimReceipt = {
	InstanceId: BrainrotInstanceId,
	BrainrotId: string,
	ClaimedAt: number,
}

export type DustReceipt = {
	Amount: number,
	GrantedAt: number,
}

export type OperationReceipt = {
	Kind: "Collect" | "Upgrade",
	Subject: string,
	Amount: number,
	TargetLevel: number?,
	CreatedAt: number,
}

export type DecisionSnapshot = {
	DecisionId: DecisionId,
	StartedAt: number,
	EndsAt: number,
	ClaimVotes: number,
	UpgradeVotes: number,
	EligibleVoterCount: number,
	VotedUserIds: { number },
	CanUpgrade: boolean,
}

export type ClaimResult = {
	RunId: RunId,
	DecisionId: DecisionId,
	PendingRewardId: string,
	BrainrotId: string,
	DisplayName: string,
	Rarity: BrainrotRarity,
	InstanceId: BrainrotInstanceId,
	AlreadyGranted: boolean,
	ClaimedAt: number,
}

export type RoomSnapshot = {
	RunId: RunId,
	RoomId: string,
	RoomType: string,
	DisplayName: string,
	ObjectiveText: string,
	Status: RoomStatus,
	Tier: number,
	RequiredCells: number,
	DepositedCells: number,
	Progress: number,
	RequiredProgress: number,
	Phase: string,
	TimeLimitSeconds: number,
	StartedAt: number,
	EndsAt: number,
	ResolutionReason: string?,
}

export type RunSnapshot = {
	RunId: RunId,
	State: RunState,
	ParticipantUserIds: { number },
	Stage: number,
	CurrentRarity: BrainrotRarity,
	PendingReward: PendingReward?,
	DecisionId: DecisionId?,
	Decision: DecisionSnapshot?,
	ActiveRoomId: string?,
	CreatedAt: number,
	StateChangedAt: number,
	LastTransitionReason: string,
}

export type BrainrotDefinition = {
	Id: string,
	DisplayName: string,
	Rarity: BrainrotRarity,
	BaseProductionPerMinute: number,
	ModelName: string,
	IconAssetId: string,
	AnimationSet: string,
	CollectionGroup: string,
	FlavorText: string?,
}

export type BrainrotInstance = {
	BrainrotId: string,
	Variant: string,
	AcquiredAt: number,
	Source: string,
	IsLocked: boolean,
	FarmSlotId: string?,
}

export type CollectionIndexEntry = {
	FirstDiscoveredAt: number,
	LifetimeObtained: number,
	BestVariant: string?,
}

export type FarmData = {
	UnlockedSlots: number,
	Slots: { [string]: BrainrotInstanceId },
	LastCollectTimestamp: number,
	AccruedCoins: number,
}

export type FarmChangeAction = "Placed" | "Removed" | "Rebuilt"

export type FarmProductionSnapshot = {
	ProductionPerMinute: number,
	EfficiencyMultiplier: number,
	OfflineCapSeconds: number,
	ElapsedSeconds: number,
	CappedElapsedSeconds: number,
	AccruedCoins: number,
	ClaimableCoins: number,
}

export type UpgradeId = "SlotUnlock" | "FarmEfficiency" | "OfflineStorage"

export type UpgradeDefinition = {
	Id: UpgradeId,
	DisplayName: string,
	Description: string,
	InitialLevel: number,
	MaxLevel: number,
	Values: { [number]: number },
	Costs: { [number]: number },
	ValueKind: "Slots" | "Multiplier" | "Minutes",
}

export type UpgradeState = {
	Id: UpgradeId,
	DisplayName: string,
	Description: string,
	CurrentLevel: number,
	MaxLevel: number,
	CurrentValue: number,
	CurrentValueText: string,
	NextLevel: number?,
	NextValue: number?,
	NextValueText: string?,
	Cost: number?,
	CanAfford: boolean,
	IsMaxed: boolean,
}

export type UpgradeData = {
	FarmEfficiency: number,
	OfflineStorage: number,
}

export type PlayerStats = {
	Runs: number,
	Claims: number,
	HighestStage: number,
}

export type PlayerSettings = { [string]: boolean | number | string }

export type PlayerProfile = {
	SchemaVersion: number,
	Coins: number,
	Dust: number,
	BrainrotInstances: { [BrainrotInstanceId]: BrainrotInstance },
	CollectionIndex: { [string]: CollectionIndexEntry },
	Farm: FarmData,
	Upgrades: UpgradeData,
	Stats: PlayerStats,
	Settings: PlayerSettings,
	ClaimReceipts: { [string]: ClaimReceipt },
	DustReceipts: { [string]: DustReceipt },
	OperationReceipts: { [string]: OperationReceipt },
}

return table.freeze({})
