--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local BalanceConfig = require(Shared:FindFirstChild("BalanceConfig") :: ModuleScript)
local BrainrotDefinitions = require(Shared:FindFirstChild("BrainrotDefinitions") :: ModuleScript)
local GameConfig = require(Shared:FindFirstChild("GameConfig") :: ModuleScript)
local Types = require(Shared:FindFirstChild("Types") :: ModuleScript)

type BrainrotDefinition = Types.BrainrotDefinition
type BrainrotRarity = Types.BrainrotRarity
type ClaimResult = Types.ClaimResult
type DecisionResult = Types.DecisionResult
type DecisionVoteChoice = Types.DecisionVoteChoice
type PendingReward = Types.PendingReward
type RoomSnapshot = Types.RoomSnapshot
type RunSnapshot = Types.RunSnapshot
type GrantedReward = { InstanceId: string, AlreadyGranted: boolean }

local REWARD_CONFIG = GameConfig.Reward
local rewardRandom = Random.new()
local poolsByRarity: { [string]: { BrainrotDefinition } } = {}
local runService: any = nil
local roomService: any = nil
local inventoryService: any = nil
local economyService: any = nil
local decisionRemote: RemoteEvent? = nil
local uiEventRemote: RemoteEvent? = nil
local processedRoomRunIds: { [string]: string } = {}
local claimingDecisionIds: { [string]: boolean } = {}
local resolvingDecisionIds: { [string]: boolean } = {}
local decisionTimers: { [string]: thread } = {}
local processingLossRunIds: { [string]: boolean } = {}
local lastClientActionAt: { [Player]: number } = {}
local initialized = false
local started = false

local pendingRewardCreatedEvent = Instance.new("BindableEvent")
local claimCompletedEvent = Instance.new("BindableEvent")
local decisionResolvedEvent = Instance.new("BindableEvent")
local pendingRewardLostEvent = Instance.new("BindableEvent")

local RewardService = {
	Name = "RewardService",
	PendingRewardCreated = pendingRewardCreatedEvent.Event,
	ClaimCompleted = claimCompletedEvent.Event,
	DecisionResolved = decisionResolvedEvent.Event,
	PendingRewardLost = pendingRewardLostEvent.Event,
}

local resolveDecision: (runId: string, decisionId: string, reason: string, force: boolean) -> ()

local function decisionKey(runId: string, decisionId: string): string
	return `{runId}:{decisionId}`
end

local function buildRewardPools()
	for _, definition in BrainrotDefinitions do
		local pool = poolsByRarity[definition.Rarity]
		if pool == nil then
			pool = {}
			poolsByRarity[definition.Rarity] = pool
		end
		table.insert(pool, definition)
	end
	for _, pool in poolsByRarity do
		table.sort(pool, function(left, right)
			return left.Id < right.Id
		end)
		table.freeze(pool)
	end
end

local function chooseReward(rarity: BrainrotRarity): BrainrotDefinition?
	local pool = poolsByRarity[rarity]
	if pool == nil or #pool == 0 then
		return nil
	end
	return pool[rewardRandom:NextInteger(1, #pool)]
end

local function fireToParticipants(runId: string, payload: any)
	local remote = uiEventRemote
	if remote == nil then
		return
	end
	local participants = runService.GetParticipants(runId)
	if participants == nil then
		return
	end
	for _, player in participants do
		if player.Parent == Players then
			remote:FireClient(player, payload)
		end
	end
end

local function sendClaimResult(player: Player, success: boolean, errorCode: string?, result: ClaimResult?)
	local remote = uiEventRemote
	if remote ~= nil and player.Parent == Players then
		remote:FireClient(player, { Type = "ClaimActionResult", Success = success, Error = errorCode, Claim = result })
	end
end

local function sendVoteResult(player: Player, choice: DecisionVoteChoice?, success: boolean, errorCode: string?, run: RunSnapshot?)
	local remote = uiEventRemote
	if remote ~= nil and player.Parent == Players then
		remote:FireClient(player, {
			Type = "DecisionVoteResult",
			Choice = choice,
			Success = success,
			Error = errorCode,
			Run = run,
		})
	end
end

local function clientActionAllowed(player: Player): boolean
	local now = os.clock()
	local previous = lastClientActionAt[player]
	if previous ~= nil and now - previous < REWARD_CONFIG.ClientActionCooldownSeconds then
		return false
	end
	lastClientActionAt[player] = now
	return true
end

local function cancelDecisionTimer(runId: string, decisionId: string)
	local key = decisionKey(runId, decisionId)
	local timer = decisionTimers[key]
	decisionTimers[key] = nil
	if timer ~= nil and timer ~= coroutine.running() then
		pcall(task.cancel, timer)
	end
end

local function startDecisionTimer(run: RunSnapshot)
	local decision = run.Decision
	if decision == nil then
		return
	end
	local key = decisionKey(run.RunId, decision.DecisionId)
	cancelDecisionTimer(run.RunId, decision.DecisionId)
	local delaySeconds = math.max(0, decision.EndsAt - Workspace:GetServerTimeNow())
	decisionTimers[key] = task.delay(delaySeconds, function()
		decisionTimers[key] = nil
		resolveDecision(run.RunId, decision.DecisionId, "TIMEOUT", true)
	end)
end

local function determineOutcome(run: RunSnapshot, force: boolean): DecisionResult?
	local decision = run.Decision
	if decision == nil then
		return nil
	end
	local majority = math.floor(decision.EligibleVoterCount / 2) + 1
	if decision.CanUpgrade and decision.UpgradeVotes >= majority then
		return "UPGRADE"
	end
	if decision.ClaimVotes >= majority then
		return "CLAIM"
	end
	if #decision.VotedUserIds >= decision.EligibleVoterCount or force then
		-- Missing votes count as the safe CLAIM default. UPGRADE only wins
		-- after reaching an absolute majority of eligible voters above.
		return "CLAIM"
	end
	return nil
end

local function claimDecision(runId: string, decisionId: string): (boolean, string?)
	local run = runService.GetActiveRun()
	if run == nil then
		return false, "NO_ACTIVE_RUN"
	end
	if run.RunId ~= runId then
		return false, "STALE_RUN_ID"
	end
	if run.State ~= "DECISION" or run.DecisionId ~= decisionId or run.PendingReward == nil then
		return false, "STALE_DECISION_ID"
	end

	local claimKey = decisionKey(runId, decisionId)
	if claimingDecisionIds[claimKey] then
		return false, "CLAIM_IN_PROGRESS"
	end
	claimingDecisionIds[claimKey] = true
	local pending = run.PendingReward
	local participants, participantsError = runService.GetParticipants(runId)
	if participants == nil or #participants == 0 then
		claimingDecisionIds[claimKey] = nil
		return false, participantsError or "NO_PARTICIPANTS"
	end

	local grantedByUserId: { [number]: GrantedReward } = {}
	for _, participant in participants do
		local instanceId, grantError, alreadyGranted = inventoryService.GrantBrainrotOnce(
			participant,
			pending.BrainrotId,
			`Tower:{runId}:Stage{pending.Stage}`,
			claimKey,
			pending.Stage
		)
		if instanceId == nil then
			claimingDecisionIds[claimKey] = nil
			warn(`[RewardService] Claim grant failed for {participant.UserId}, decision {decisionId}: {grantError}`)
			return false, `GRANT_FAILED_{participant.UserId}_{grantError}`
		end
		grantedByUserId[participant.UserId] = { InstanceId = instanceId, AlreadyGranted = alreadyGranted }
	end

	local _, completeError = runService.CompleteClaim(runId, decisionId)
	if completeError ~= nil and completeError ~= "DECISION_ALREADY_COMPLETED" then
		claimingDecisionIds[claimKey] = nil
		return false, completeError
	end

	local claimedAt = os.time()
	for _, participant in participants do
		local grant = grantedByUserId[participant.UserId]
		if grant ~= nil then
			local result: ClaimResult = {
				RunId = runId,
				DecisionId = decisionId,
				PendingRewardId = pending.PendingRewardId,
				BrainrotId = pending.BrainrotId,
				DisplayName = pending.DisplayName,
				Rarity = pending.Rarity,
				InstanceId = grant.InstanceId,
				AlreadyGranted = grant.AlreadyGranted,
				ClaimedAt = claimedAt,
			}
			sendClaimResult(participant, true, nil, result)
		end
	end

	claimCompletedEvent:Fire(runId, decisionId, pending, grantedByUserId)
	claimingDecisionIds[claimKey] = nil
	local finished, finishError = runService.FinishRun(runId, "RewardClaimed")
	if not finished then
		warn(`[RewardService] Claim committed but run {runId} did not close: {finishError}`)
	end
	return true, nil
end

local function recoverUpgradeFailure(runId: string, startError: string?)
	local recovery, recoveryError = runService.CreateRecoveryClaimDecision(runId)
	if recovery == nil or recovery.DecisionId == nil then
		warn(`[RewardService] Upgrade recovery failed for {runId}: {recoveryError}`)
		runService.FinishRun(runId, "UpgradeRoomRecoveryFailed")
		return
	end
	fireToParticipants(runId, { Type = "UpgradeRoomRecovery", Error = startError, Run = recovery })
	local claimed, claimError = claimDecision(runId, recovery.DecisionId)
	if not claimed then
		warn(`[RewardService] Safe recovery Claim failed for {runId}: {claimError}`)
	end
end

resolveDecision = function(runId: string, decisionId: string, reason: string, force: boolean)
	local key = decisionKey(runId, decisionId)
	if resolvingDecisionIds[key] then
		return
	end
	local run = runService.GetActiveRun()
	if run == nil or run.RunId ~= runId or run.State ~= "DECISION" or run.DecisionId ~= decisionId then
		return
	end
	local outcome = determineOutcome(run, force)
	if outcome == nil then
		return
	end

	resolvingDecisionIds[key] = true
	if outcome == "CLAIM" then
		fireToParticipants(runId, { Type = "DecisionResolved", Choice = "CLAIM", Reason = reason, Run = run })
		local claimed, claimError = claimDecision(runId, decisionId)
		if claimed then
			cancelDecisionTimer(runId, decisionId)
			decisionResolvedEvent:Fire(runId, decisionId, "CLAIM", reason)
		else
			warn(`[RewardService] Decision Claim failed for {runId}: {claimError}`)
			fireToParticipants(runId, {
				Type = "DecisionResolutionFailed",
				Choice = "CLAIM",
				Error = claimError,
				Run = runService.GetActiveRun(),
			})
		end
	else
		local upgraded, upgradeError = runService.BeginUpgrade(runId, decisionId)
		if upgraded == nil then
			warn(`[RewardService] Decision Upgrade failed for {runId}: {upgradeError}`)
		else
			cancelDecisionTimer(runId, decisionId)
			fireToParticipants(runId, { Type = "DecisionResolved", Choice = "UPGRADE", Reason = reason, Run = upgraded })
			decisionResolvedEvent:Fire(runId, decisionId, "UPGRADE", reason)
			local callSuccess, room, startError = pcall(roomService.Start, runId)
			if not callSuccess or room == nil then
				local errorCode = if callSuccess then startError else "ROOM_START_ERROR"
				warn(`[RewardService] Upgraded room failed to start for {runId}: {tostring(if callSuccess then startError else room)}`)
				recoverUpgradeFailure(runId, errorCode)
			end
		end
	end
	resolvingDecisionIds[key] = nil
end

local function handleRoomFailure(room: RoomSnapshot)
	if processingLossRunIds[room.RunId] then
		return
	end
	processingLossRunIds[room.RunId] = true
	local run = runService.GetActiveRun()
	if run == nil or run.RunId ~= room.RunId or run.State ~= "RESULTS" then
		processingLossRunIds[room.RunId] = nil
		return
	end

	local participants = runService.GetParticipants(room.RunId) or {}
	local lostReward, _, lossError = runService.LosePendingReward(room.RunId)
	if lostReward ~= nil then
		local dustAmount = BalanceConfig.Run.ConsolationDustByRarity[lostReward.Rarity] or 0
		local receiptKey = `PendingLoss:{room.RunId}:{lostReward.PendingRewardId}`
		for _, participant in participants do
			local granted, _, grantError = economyService.GrantDustOnce(participant, dustAmount, receiptKey)
			if not granted then
				warn(`[RewardService] Consolation Dust failed for {participant.UserId}: {grantError}`)
			end
		end
		fireToParticipants(room.RunId, {
			Type = "PendingRewardLost",
			LostPendingReward = lostReward,
			ConsolationDust = dustAmount,
			Room = room,
		})
		pendingRewardLostEvent:Fire(room.RunId, lostReward, dustAmount)
	elseif lossError ~= "NO_PENDING_REWARD" then
		warn(`[RewardService] Pending loss failed for {room.RunId}: {lossError}`)
	end

	runService.FinishRun(room.RunId, if lostReward ~= nil then "PendingRewardLost" else "RoomFailed")
	processingLossRunIds[room.RunId] = nil
end

function RewardService.Init()
	assert(not initialized, "RewardService.Init called more than once")
	buildRewardPools()
	local runModule = script.Parent:FindFirstChild("RunService")
	local roomModule = script.Parent:FindFirstChild("RoomService")
	local inventoryModule = script.Parent:FindFirstChild("InventoryService")
	local economyModule = script.Parent:FindFirstChild("EconomyService")
	assert(runModule and roomModule and inventoryModule and economyModule, "RewardService dependencies are missing")
	runService = require(runModule :: ModuleScript)
	roomService = require(roomModule :: ModuleScript)
	inventoryService = require(inventoryModule :: ModuleScript)
	economyService = require(economyModule :: ModuleScript)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	assert(remotes and remotes:IsA("Folder"), "ReplicatedStorage.Remotes is missing")
	local decisionVote = remotes:FindFirstChild("DecisionVote")
	local uiEvent = remotes:FindFirstChild("UIEvent")
	assert(decisionVote and decisionVote:IsA("RemoteEvent"), "Remotes.DecisionVote is missing")
	assert(uiEvent and uiEvent:IsA("RemoteEvent"), "Remotes.UIEvent is missing")
	decisionRemote = decisionVote
	uiEventRemote = uiEvent
	initialized = true
end

function RewardService.CreatePendingReward(room: RoomSnapshot): (PendingReward?, string?)
	assert(initialized, "RewardService.Init must run before use")
	if room.Status ~= "SUCCESS" then
		return nil, "ROOM_NOT_SUCCESSFUL"
	end
	if processedRoomRunIds[room.RoomId] ~= nil then
		local current = runService.GetActiveRun()
		if current ~= nil and current.RunId == room.RunId and current.PendingReward ~= nil
			and current.PendingReward.SourceRoomId == room.RoomId then
			return current.PendingReward, nil
		end
		return nil, "ROOM_REWARD_ALREADY_PROCESSED"
	end

	local run = runService.GetActiveRun()
	if run == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if run.RunId ~= room.RunId then
		return nil, "STALE_RUN_ID"
	end
	if run.State ~= "DECISION" or run.Stage ~= room.Tier then
		return nil, "INVALID_RUN_STATE_OR_TIER"
	end
	local definition = chooseReward(run.CurrentRarity)
	if definition == nil then
		return nil, "EMPTY_RARITY_POOL"
	end
	local pending: PendingReward = {
		PendingRewardId = HttpService:GenerateGUID(false),
		BrainrotId = definition.Id,
		DisplayName = definition.DisplayName,
		Rarity = definition.Rarity,
		BaseProductionPerMinute = definition.BaseProductionPerMinute,
		Stage = run.Stage,
		SourceRoomId = room.RoomId,
		CreatedAt = os.time(),
	}
	local updatedRun, updateError = runService.SetPendingReward(run.RunId, pending)
	if updatedRun == nil then
		return nil, updateError
	end
	processedRoomRunIds[room.RoomId] = room.RunId
	pendingRewardCreatedEvent:Fire(updatedRun, pending)
	startDecisionTimer(updatedRun)
	return pending, nil
end

function RewardService.Claim(player: Player, runId: string, decisionId: string): (boolean, string?)
	assert(initialized, "RewardService.Init must run before use")
	if not runService.IsParticipant(player, runId) then
		return false, "NOT_A_PARTICIPANT"
	end
	return claimDecision(runId, decisionId)
end

local function handleDecisionRemote(player: Player, payload: any)
	if not clientActionAllowed(player) then
		sendVoteResult(player, nil, false, "RATE_LIMITED", runService.GetRunForPlayer(player))
		return
	end
	if type(payload) ~= "table" or payload.Action ~= "Vote"
		or type(payload.RunId) ~= "string" or type(payload.DecisionId) ~= "string"
		or (payload.Choice ~= "CLAIM" and payload.Choice ~= "UPGRADE") then
		sendVoteResult(player, nil, false, "INVALID_PAYLOAD", runService.GetRunForPlayer(player))
		return
	end
	local choice = payload.Choice :: DecisionVoteChoice
	local run, voteError = runService.SubmitDecisionVote(player, payload.RunId, payload.DecisionId, choice)
	if run == nil then
		sendVoteResult(player, choice, false, voteError, runService.GetRunForPlayer(player))
		return
	end
	sendVoteResult(player, choice, true, nil, run)
	resolveDecision(payload.RunId, payload.DecisionId, "MAJORITY", false)
end

function RewardService.Start()
	assert(initialized, "RewardService.Init must run before Start")
	assert(not started, "RewardService.Start called more than once")
	started = true
	local remote = decisionRemote
	assert(remote ~= nil, "DecisionVote remote is unavailable")
	remote.OnServerEvent:Connect(handleDecisionRemote)

	roomService.RoomResolved:Connect(function(room: RoomSnapshot, success: boolean)
		if success then
			local created, createError = RewardService.CreatePendingReward(room)
			if created == nil then
				warn(`[RewardService] Pending reward failed for room {room.RoomId}: {createError}`)
				runService.FinishRun(room.RunId, "PendingRewardCreationFailed")
			end
		else
			local handled, handleError = pcall(handleRoomFailure, room)
			if not handled then
				warn(`[RewardService] Room failure handling crashed for {room.RunId}: {handleError}`)
				runService.FinishRun(room.RunId, "RoomFailureHandlingError")
			end
		end
	end)

	runService.RunClosed:Connect(function(run: RunSnapshot)
		if run.DecisionId ~= nil then
			local key = decisionKey(run.RunId, run.DecisionId)
			cancelDecisionTimer(run.RunId, run.DecisionId)
			claimingDecisionIds[key] = nil
			resolvingDecisionIds[key] = nil
		end
		processingLossRunIds[run.RunId] = nil
		local roomIdsToClear = {}
		for roomId, runId in processedRoomRunIds do
			if runId == run.RunId then
				table.insert(roomIdsToClear, roomId)
			end
		end
		for _, roomId in roomIdsToClear do
			processedRoomRunIds[roomId] = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastClientActionAt[player] = nil
	end)
end

return table.freeze(RewardService)
