--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local BalanceConfigModule = Shared:FindFirstChild("BalanceConfig")
local GameConfigModule = Shared:FindFirstChild("GameConfig")
local TypesModule = Shared:FindFirstChild("Types")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local BalanceConfig = require(BalanceConfigModule)
local GameConfig = require(GameConfigModule)
local Types = require(TypesModule)

local runInternal = script.Parent:FindFirstChild("Run")
assert(runInternal and runInternal:IsA("Folder"), "Services.Run is missing")
local StateMachineModule = runInternal:FindFirstChild("StateMachine")
assert(StateMachineModule and StateMachineModule:IsA("ModuleScript"), "Run.StateMachine is missing")
local StateMachine = require(StateMachineModule)

type BrainrotRarity = Types.BrainrotRarity
type DecisionSnapshot = Types.DecisionSnapshot
type DecisionVoteChoice = Types.DecisionVoteChoice
type PendingReward = Types.PendingReward
type RunId = Types.RunId
type RunSnapshot = Types.RunSnapshot
type RunState = Types.RunState

type RunSession = {
	RunId: RunId,
	State: RunState,
	Participants: { [number]: Player },
	Stage: number,
	CurrentRarity: BrainrotRarity,
	PendingReward: PendingReward?,
	DecisionId: string?,
	Votes: { [number]: DecisionVoteChoice },
	DecisionStartedAt: number?,
	DecisionEndsAt: number?,
	DecisionEligibleUserIds: { [number]: boolean },
	DecisionCanUpgrade: boolean,
	CompletedDecisionIds: { [string]: boolean },
	ActiveRoomId: string?,
	CreatedAt: number,
	StateChangedAt: number,
	LastTransitionReason: string,
}

local RUN_CONFIG = GameConfig.Run
local activeRun: RunSession? = nil
local playerRunIds: { [Player]: RunId } = {}
local playerDataService: any = nil
local antiExploitService: any = nil
local runActionRemote: RemoteEvent? = nil
local uiEventRemote: RemoteEvent? = nil
local initialized = false
local started = false

local RUN_ACTION_KEYS: { [string]: boolean } = { Action = true }
local ABANDON_ACTION_KEYS: { [string]: boolean } = { Action = true, RunId = true }

local runCreatedEvent = Instance.new("BindableEvent")
local runStateChangedEvent = Instance.new("BindableEvent")
local participantsChangedEvent = Instance.new("BindableEvent")
local runClosedEvent = Instance.new("BindableEvent")

local RunService = {
	Name = "RunService",
	RunCreated = runCreatedEvent.Event,
	RunStateChanged = runStateChangedEvent.Event,
	ParticipantsChanged = participantsChangedEvent.Event,
	RunClosed = runClosedEvent.Event,
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

local function makeDecisionSnapshot(session: RunSession): DecisionSnapshot?
	local decisionId = session.DecisionId
	local startedAt = session.DecisionStartedAt
	local endsAt = session.DecisionEndsAt
	if decisionId == nil or startedAt == nil or endsAt == nil then
		return nil
	end

	local claimVotes = 0
	local upgradeVotes = 0
	local eligibleVoterCount = 0
	local votedUserIds = {}
	for _ in session.DecisionEligibleUserIds do
		eligibleVoterCount += 1
	end
	for userId, vote in session.Votes do
		table.insert(votedUserIds, userId)
		if vote == "CLAIM" then
			claimVotes += 1
		else
			upgradeVotes += 1
		end
	end
	table.sort(votedUserIds)

	return {
		DecisionId = decisionId,
		StartedAt = startedAt,
		EndsAt = endsAt,
		ClaimVotes = claimVotes,
		UpgradeVotes = upgradeVotes,
		EligibleVoterCount = eligibleVoterCount,
		VotedUserIds = votedUserIds,
		CanUpgrade = session.DecisionCanUpgrade,
	}
end

local function makeSnapshot(session: RunSession): RunSnapshot
	local participantUserIds = {}
	for userId in session.Participants do
		table.insert(participantUserIds, userId)
	end
	table.sort(participantUserIds)

	return {
		RunId = session.RunId,
		State = session.State,
		ParticipantUserIds = participantUserIds,
		Stage = session.Stage,
		CurrentRarity = session.CurrentRarity,
		PendingReward = cloneSerializable(session.PendingReward),
		DecisionId = session.DecisionId,
		Decision = makeDecisionSnapshot(session),
		ActiveRoomId = session.ActiveRoomId,
		CreatedAt = session.CreatedAt,
		StateChangedAt = session.StateChangedAt,
		LastTransitionReason = session.LastTransitionReason,
	}
end

local function clearDecision(session: RunSession)
	session.DecisionId = nil
	session.Votes = {}
	session.DecisionStartedAt = nil
	session.DecisionEndsAt = nil
	session.DecisionEligibleUserIds = {}
	session.DecisionCanUpgrade = false
end

local function openDecision(session: RunSession, canUpgrade: boolean)
	local now = Workspace:GetServerTimeNow()
	session.DecisionId = HttpService:GenerateGUID(false)
	session.Votes = {}
	session.DecisionStartedAt = now
	session.DecisionEndsAt = now + BalanceConfig.Run.DecisionSeconds
	session.DecisionEligibleUserIds = {}
	for userId in session.Participants do
		session.DecisionEligibleUserIds[userId] = true
	end
	session.DecisionCanUpgrade = canUpgrade
end

local function participantCount(session: RunSession): number
	local count = 0
	for _ in session.Participants do
		count += 1
	end
	return count
end

local function sendToParticipants(session: RunSession, eventType: string, snapshot: RunSnapshot)
	local remote = uiEventRemote
	if remote == nil then
		return
	end

	for _, player in session.Participants do
		if player.Parent == Players then
			remote:FireClient(player, {
				Type = eventType,
				Run = snapshot,
			})
		end
	end
end

local function sendActionResult(
	player: Player,
	action: string,
	success: boolean,
	errorCode: string?,
	snapshot: RunSnapshot?
)
	local remote = uiEventRemote
	if remote == nil or player.Parent ~= Players then
		return
	end

	remote:FireClient(player, {
		Type = "RunActionResult",
		Action = action,
		Success = success,
		Error = errorCode,
		Run = snapshot,
	})
end

local function clearActiveRun(session: RunSession)
	for _, player in session.Participants do
		if playerRunIds[player] == session.RunId then
			playerRunIds[player] = nil
		end
	end

	if activeRun == session then
		activeRun = nil
	end
end

local closeRun: (runId: RunId, reason: string) -> ()

function RunService.Init()
	assert(not initialized, "RunService.Init called more than once")

	local playerDataModule = script.Parent:FindFirstChild("PlayerDataService")
	local antiExploitModule = script.Parent:FindFirstChild("AntiExploitService")
	assert(playerDataModule and playerDataModule:IsA("ModuleScript"), "Services.PlayerDataService is missing")
	assert(antiExploitModule and antiExploitModule:IsA("ModuleScript"), "Services.AntiExploitService is missing")
	playerDataService = require(playerDataModule)
	antiExploitService = require(antiExploitModule)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	assert(remotes and remotes:IsA("Folder"), "ReplicatedStorage.Remotes is missing")
	local runAction = remotes:FindFirstChild("RunAction")
	local uiEvent = remotes:FindFirstChild("UIEvent")
	assert(runAction and runAction:IsA("RemoteEvent"), "Remotes.RunAction is missing")
	assert(uiEvent and uiEvent:IsA("RemoteEvent"), "Remotes.UIEvent is missing")
	runActionRemote = runAction
	uiEventRemote = uiEvent
	initialized = true
end

function RunService.GetActiveRun(): RunSnapshot?
	return if activeRun == nil then nil else makeSnapshot(activeRun)
end

function RunService.GetRunForPlayer(player: Player): RunSnapshot?
	local session = activeRun
	local expectedRunId = playerRunIds[player]
	if session == nil or expectedRunId == nil or session.RunId ~= expectedRunId then
		return nil
	end
	return makeSnapshot(session)
end

function RunService.GetParticipants(runId: RunId): ({ Player }?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end

	local participants = {}
	for _, player in session.Participants do
		if player.Parent == Players then
			table.insert(participants, player)
		end
	end
	table.sort(participants, function(left, right)
		return left.UserId < right.UserId
	end)
	return participants, nil
end

function RunService.IsParticipant(player: Player, runId: RunId): boolean
	local session = activeRun
	return session ~= nil
		and session.RunId == runId
		and session.Participants[player.UserId] == player
		and playerRunIds[player] == runId
end

function RunService.Transition(runId: RunId, nextState: RunState, reason: string): (RunSnapshot?, string?)
	assert(initialized, "RunService.Init must run before use")
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if not StateMachine.IsValidState(nextState) then
		return nil, "INVALID_STATE"
	end
	if not StateMachine.CanTransition(session.State, nextState) then
		return nil, `INVALID_TRANSITION_{session.State}_TO_{nextState}`
	end

	local previousState = session.State
	session.State = nextState
	session.StateChangedAt = os.time()
	session.LastTransitionReason = if reason == "" then "Unspecified" else reason

	local snapshot = makeSnapshot(session)
	runStateChangedEvent:Fire(snapshot, previousState)
	sendToParticipants(session, "RunStateChanged", snapshot)

	if nextState == "WAITING" then
		clearActiveRun(session)
		runClosedEvent:Fire(snapshot)
	end

	return snapshot, nil
end

function RunService.SetActiveRoom(runId: RunId, roomId: string?): (RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if roomId ~= nil and roomId == "" then
		return nil, "INVALID_ROOM_ID"
	end
	if roomId ~= nil and session.State ~= "TRAVEL" and session.State ~= "DECISION" and session.State ~= "ROOM" then
		return nil, "INVALID_RUN_STATE"
	end
	if roomId ~= nil and session.ActiveRoomId ~= nil and session.ActiveRoomId ~= roomId then
		return nil, "ROOM_ALREADY_ACTIVE"
	end

	session.ActiveRoomId = roomId
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "RunUpdated", snapshot)
	return snapshot, nil
end

function RunService.SetPendingReward(runId: RunId, pendingReward: PendingReward): (RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.State ~= "DECISION" then
		return nil, "INVALID_RUN_STATE"
	end
	if session.DecisionId ~= nil then
		return nil, "PENDING_REWARD_ALREADY_EXISTS"
	end
	if type(pendingReward) ~= "table"
		or type(pendingReward.PendingRewardId) ~= "string"
		or pendingReward.PendingRewardId == ""
		or type(pendingReward.BrainrotId) ~= "string"
		or type(pendingReward.DisplayName) ~= "string"
		or type(pendingReward.Rarity) ~= "string"
		or type(pendingReward.BaseProductionPerMinute) ~= "number"
		or type(pendingReward.Stage) ~= "number"
		or type(pendingReward.SourceRoomId) ~= "string"
		or type(pendingReward.CreatedAt) ~= "number"
	then
		return nil, "INVALID_PENDING_REWARD"
	end
	if pendingReward.BrainrotId == ""
		or pendingReward.DisplayName == ""
		or pendingReward.SourceRoomId == ""
		or pendingReward.BaseProductionPerMinute <= 0
		or pendingReward.BaseProductionPerMinute ~= pendingReward.BaseProductionPerMinute
		or pendingReward.Stage < 1
		or pendingReward.Stage % 1 ~= 0
		or pendingReward.CreatedAt < 0
		or pendingReward.CreatedAt % 1 ~= 0
	then
		return nil, "INVALID_PENDING_REWARD_VALUES"
	end
	if session.PendingReward ~= nil and session.PendingReward.Stage >= pendingReward.Stage then
		return nil, "PENDING_REWARD_ALREADY_EXISTS"
	end
	if pendingReward.Stage ~= session.Stage or pendingReward.Rarity ~= session.CurrentRarity then
		return nil, "PENDING_REWARD_TIER_MISMATCH"
	end

	session.PendingReward = cloneSerializable(pendingReward)
	openDecision(session, session.Stage < #BalanceConfig.Run.RarityByStage)
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "PendingRewardCreated", snapshot)
	return snapshot, nil
end

function RunService.SubmitDecisionVote(
	player: Player,
	runId: RunId,
	decisionId: string,
	choice: DecisionVoteChoice
): (RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.State ~= "DECISION" or session.PendingReward == nil then
		return nil, "INVALID_RUN_STATE"
	end
	if session.CompletedDecisionIds[decisionId] then
		return nil, "DECISION_ALREADY_COMPLETED"
	end
	if session.DecisionId ~= decisionId then
		return nil, "STALE_DECISION_ID"
	end
	if session.DecisionEndsAt == nil or Workspace:GetServerTimeNow() > session.DecisionEndsAt then
		return nil, "DECISION_EXPIRED"
	end
	if not RunService.IsParticipant(player, runId) or not session.DecisionEligibleUserIds[player.UserId] then
		return nil, "NOT_AN_ELIGIBLE_VOTER"
	end
	if choice ~= "CLAIM" and choice ~= "UPGRADE" then
		return nil, "INVALID_VOTE"
	end
	if choice == "UPGRADE" and not session.DecisionCanUpgrade then
		return nil, "MAX_TIER_REQUIRES_CLAIM"
	end
	if session.Votes[player.UserId] ~= nil then
		return nil, "VOTE_ALREADY_CAST"
	end

	session.Votes[player.UserId] = choice
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "DecisionVoteUpdated", snapshot)
	return snapshot, nil
end

function RunService.BeginUpgrade(runId: RunId, decisionId: string): (RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.CompletedDecisionIds[decisionId] then
		return nil, "DECISION_ALREADY_COMPLETED"
	end
	if session.State ~= "DECISION" or session.DecisionId ~= decisionId or session.PendingReward == nil then
		return nil, "STALE_DECISION_ID"
	end
	if not session.DecisionCanUpgrade or session.Stage >= #BalanceConfig.Run.RarityByStage then
		return nil, "MAX_TIER_REQUIRES_CLAIM"
	end

	session.CompletedDecisionIds[decisionId] = true
	clearDecision(session)
	session.Stage += 1
	session.CurrentRarity = BalanceConfig.Run.RarityByStage[session.Stage] :: BrainrotRarity
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "UpgradeCommitted", snapshot)
	return snapshot, nil
end

function RunService.CreateRecoveryClaimDecision(runId: RunId): (RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.State ~= "DECISION" or session.PendingReward == nil or session.DecisionId ~= nil then
		return nil, "RECOVERY_NOT_AVAILABLE"
	end

	openDecision(session, false)
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "DecisionRecovery", snapshot)
	return snapshot, nil
end

function RunService.LosePendingReward(runId: RunId): (PendingReward?, RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, nil, "STALE_RUN_ID"
	end
	if session.State ~= "RESULTS" then
		return nil, nil, "INVALID_RUN_STATE"
	end
	if session.PendingReward == nil then
		return nil, makeSnapshot(session), "NO_PENDING_REWARD"
	end

	local lostReward = cloneSerializable(session.PendingReward)
	session.PendingReward = nil
	clearDecision(session)
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "PendingRewardLost", snapshot)
	return lostReward, snapshot, nil
end

function RunService.CompleteClaim(runId: RunId, decisionId: string): (RunSnapshot?, string?)
	local session = activeRun
	if session == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.CompletedDecisionIds[decisionId] then
		return makeSnapshot(session), "DECISION_ALREADY_COMPLETED"
	end
	if session.State ~= "DECISION" then
		return nil, "INVALID_RUN_STATE"
	end
	if session.DecisionId ~= decisionId then
		return nil, "STALE_DECISION_ID"
	end
	if session.PendingReward == nil then
		return nil, "NO_PENDING_REWARD"
	end

	session.CompletedDecisionIds[decisionId] = true
	session.PendingReward = nil
	clearDecision(session)
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "ClaimCommitted", snapshot)
	return snapshot, nil
end

function RunService.StartRun(participants: { Player }): (RunSnapshot?, string?)
	assert(initialized, "RunService.Init must run before use")
	if activeRun ~= nil then
		return nil, "RUN_ALREADY_ACTIVE"
	end

	local participantMap: { [number]: Player } = {}
	local count = 0
	for _, player in participants do
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
			return nil, "INVALID_PARTICIPANT"
		end
		if not playerDataService.IsLoaded(player) then
			return nil, "PARTICIPANT_PROFILE_NOT_LOADED"
		end
		if participantMap[player.UserId] == nil then
			participantMap[player.UserId] = player
			count += 1
		end
	end

	if count < RUN_CONFIG.MinPlayers then
		return nil, "NOT_ENOUGH_PARTICIPANTS"
	end
	if count > RUN_CONFIG.MaxPlayers then
		return nil, "TOO_MANY_PARTICIPANTS"
	end

	local now = os.time()
	local runId = HttpService:GenerateGUID(false)
	local firstRarity = BalanceConfig.Run.RarityByStage[1] :: BrainrotRarity
	local session: RunSession = {
		RunId = runId,
		State = "WAITING",
		Participants = participantMap,
		Stage = 1,
		CurrentRarity = firstRarity,
		PendingReward = nil,
		DecisionId = nil,
		Votes = {},
		DecisionStartedAt = nil,
		DecisionEndsAt = nil,
		DecisionEligibleUserIds = {},
		DecisionCanUpgrade = false,
		CompletedDecisionIds = {},
		ActiveRoomId = nil,
		CreatedAt = now,
		StateChangedAt = now,
		LastTransitionReason = "RunCreated",
	}

	activeRun = session
	for _, player in participantMap do
		playerRunIds[player] = runId
	end

	local waitingSnapshot = makeSnapshot(session)
	runCreatedEvent:Fire(waitingSnapshot)
	sendToParticipants(session, "RunCreated", waitingSnapshot)

	local preparationSnapshot, transitionError = RunService.Transition(runId, "PREPARATION", "RunStarted")
	if preparationSnapshot == nil then
		clearActiveRun(session)
		return nil, transitionError
	end
	for _, player in participantMap do
		local updated, statsError = playerDataService.UpdateProfile(player, function(profile)
			profile.Stats.Runs += 1
			return true, nil
		end)
		if not updated then
			warn(`[RunService] Could not record run start for {player.UserId}: {statsError}`)
		end
	end
	return preparationSnapshot, nil
end

closeRun = function(runId: RunId, reason: string)
	local session = activeRun
	if session == nil or session.RunId ~= runId then
		return
	end

	if session.State ~= "RESULTS" and session.State ~= "RETURN_TO_LOBBY" then
		RunService.Transition(runId, "RESULTS", reason)
	end
	if activeRun ~= nil and activeRun.RunId == runId and activeRun.State == "RESULTS" then
		RunService.Transition(runId, "RETURN_TO_LOBBY", reason)
	end
	if activeRun ~= nil and activeRun.RunId == runId and activeRun.State == "RETURN_TO_LOBBY" then
		RunService.Transition(runId, "WAITING", reason)
	end
end

function RunService.FinishRun(runId: RunId, reason: string): (boolean, string?)
	local session = activeRun
	if session == nil then
		return false, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return false, "STALE_RUN_ID"
	end

	closeRun(runId, if reason == "" then "RunFinished" else reason)
	if activeRun ~= nil and activeRun.RunId == runId then
		return false, "RUN_DID_NOT_CLOSE"
	end
	return true, nil
end

function RunService.RequestAbandon(player: Player, runId: RunId, reason: string?): (boolean, RunSnapshot?, string?)
	assert(initialized, "RunService.Init must run before use")
	local session = activeRun
	if session == nil then
		return false, nil, "NO_ACTIVE_RUN"
	end
	if session.RunId ~= runId then
		return false, nil, "STALE_RUN_ID"
	end
	if not RunService.IsParticipant(player, runId) then
		return false, nil, "NOT_A_PARTICIPANT"
	end

	session.Participants[player.UserId] = nil
	playerRunIds[player] = nil
	if session.State == "DECISION" then
		session.DecisionEligibleUserIds[player.UserId] = nil
		session.Votes[player.UserId] = nil
	end
	local snapshot = makeSnapshot(session)
	sendToParticipants(session, "RunParticipantsChanged", snapshot)
	participantsChangedEvent:Fire(snapshot, player.UserId, reason or "Abandoned")

	if participantCount(session) == 0 then
		closeRun(runId, "AllParticipantsLeft")
		return true, nil, nil
	end
	return true, snapshot, nil
end

local function handleClientAction(player: Player, payload: any)
	if not antiExploitService.AllowAction(player, "RunAction") then
		sendActionResult(player, "Unknown", false, "RATE_LIMITED", RunService.GetRunForPlayer(player))
		return
	end
	local validBase = antiExploitService.ValidatePayload(payload, ABANDON_ACTION_KEYS)
	if not validBase or not antiExploitService.IsBoundedString(if type(payload) == "table" then payload.Action else nil) then
		antiExploitService.RecordRejection(player, "RunAction", "INVALID_PAYLOAD")
		sendActionResult(player, "Unknown", false, "INVALID_PAYLOAD", RunService.GetRunForPlayer(player))
		return
	end

	local action = payload.Action
	if action == "RequestStart" then
		local valid = antiExploitService.ValidatePayload(payload, RUN_ACTION_KEYS)
		if not valid then
			antiExploitService.RecordRejection(player, "RunAction", "INVALID_START_PAYLOAD")
			sendActionResult(player, action, false, "INVALID_PAYLOAD", RunService.GetRunForPlayer(player))
			return
		end
		local snapshot, startError = RunService.StartRun({ player })
		sendActionResult(player, action, snapshot ~= nil, startError, snapshot)
	elseif action == "RequestAbandon" then
		local valid = antiExploitService.ValidatePayload(payload, ABANDON_ACTION_KEYS)
		if not valid or not antiExploitService.IsBoundedString(payload.RunId) then
			antiExploitService.RecordRejection(player, "RunAction", "INVALID_RUN_ID")
			sendActionResult(player, action, false, "INVALID_RUN_ID", RunService.GetRunForPlayer(player))
			return
		end

		local abandoned, snapshot, abandonError = RunService.RequestAbandon(player, payload.RunId, "Abandoned")
		sendActionResult(player, action, abandoned, abandonError, snapshot)
	else
		sendActionResult(player, action, false, "UNKNOWN_ACTION", RunService.GetRunForPlayer(player))
	end
end

function RunService.Start()
	assert(initialized, "RunService.Init must run before Start")
	assert(not started, "RunService.Start called more than once")
	started = true

	local remote = runActionRemote
	assert(remote ~= nil, "RunAction remote is unavailable")
	remote.OnServerEvent:Connect(handleClientAction)

	Players.PlayerRemoving:Connect(function(player)
		local runId = playerRunIds[player]
		if runId ~= nil then
			RunService.RequestAbandon(player, runId, "Disconnected")
		end
	end)
end

function RunService.DebugStartRun(participants: { Player }?): (RunSnapshot?, string?)
	if not RobloxRunService:IsStudio() then
		return nil, "DEBUG_ONLY"
	end
	return RunService.StartRun(participants or Players:GetPlayers())
end

function RunService.DebugTransition(runId: RunId, nextState: RunState): (RunSnapshot?, string?)
	if not RobloxRunService:IsStudio() then
		return nil, "DEBUG_ONLY"
	end
	return RunService.Transition(runId, nextState, "StudioDebug")
end

function RunService.DebugCloseRun(runId: RunId): boolean
	if not RobloxRunService:IsStudio() then
		return false
	end
	local session = activeRun
	if session == nil or session.RunId ~= runId then
		return false
	end
	closeRun(runId, "StudioDebugClose")
	return true
end

return table.freeze(RunService)
