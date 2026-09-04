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
local RoomDefinitionsModule = Shared:FindFirstChild("RoomDefinitions")
local TypesModule = Shared:FindFirstChild("Types")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
assert(RoomDefinitionsModule and RoomDefinitionsModule:IsA("ModuleScript"), "Shared.RoomDefinitions is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local BalanceConfig = require(BalanceConfigModule)
local GameConfig = require(GameConfigModule)
local RoomDefinitions = require(RoomDefinitionsModule)
local Types = require(TypesModule)
local WorldGeometry = require(Shared:FindFirstChild("WorldGeometry") :: ModuleScript)

local roomInternal = script.Parent:FindFirstChild("Room")
assert(roomInternal and roomInternal:IsA("Folder"), "Services.Room is missing")
local ReactorBuilderModule = roomInternal:FindFirstChild("ReactorBuilder")
local SignalSequenceBuilderModule = roomInternal:FindFirstChild("SignalSequenceBuilder")
local LaserGridBuilderModule = roomInternal:FindFirstChild("LaserGridBuilder")
assert(ReactorBuilderModule and ReactorBuilderModule:IsA("ModuleScript"), "Room.ReactorBuilder is missing")
assert(SignalSequenceBuilderModule and SignalSequenceBuilderModule:IsA("ModuleScript"), "Room.SignalSequenceBuilder is missing")
assert(LaserGridBuilderModule and LaserGridBuilderModule:IsA("ModuleScript"), "Room.LaserGridBuilder is missing")
local ReactorBuilder = require(ReactorBuilderModule)
local SignalSequenceBuilder = require(SignalSequenceBuilderModule)
local LaserGridBuilder = require(LaserGridBuilderModule)

type RoomSnapshot = Types.RoomSnapshot
type RoomStatus = Types.RoomStatus

type CellState = {
	Id: string,
	Part: Part,
	Prompt: ProximityPrompt,
	Pedestal: Part,
	StartCFrame: CFrame,
	State: "AVAILABLE" | "CARRIED" | "DEPOSITED",
	CarrierUserId: number?,
	Weld: WeldConstraint?,
}

type RoomSession = {
	RunId: string,
	RoomId: string,
	RoomType: string,
	DisplayName: string,
	ObjectiveText: string,
	Status: RoomStatus,
	Tier: number,
	RequiredCells: number,
	DepositedCells: number,
	TimeLimitSeconds: number,
	StartedAt: number,
	EndsAt: number,
	ResolutionReason: string?,
	Participants: { Player },
	Build: any,
	Cells: { [string]: CellState },
	CarriedByUserId: { [number]: string },
	Connections: { RBXScriptConnection },
	HeartbeatConnection: RBXScriptConnection?,
	DeadlineThread: thread?,
	OriginalPivots: { [number]: CFrame },
	LastActionAt: { [Player]: number },
	HazardLastHitAt: { [number]: number },
	LastDisplayedSecond: number,
	Phase: string,
	PhaseThread: thread?,
	Sequence: { string },
	SequencePosition: number,
	SequenceMistakes: number,
	SequenceInputEnabled: boolean,
	FinishedUserIds: { [number]: boolean },
	Active: boolean,
}

local ROOM_CONFIG = GameConfig.Room
local runService: any = nil
local antiExploitService: any = nil
local roomActionRemote: RemoteEvent? = nil
local uiEventRemote: RemoteEvent? = nil
local activeRoomsFolder: Folder? = nil
local activeRoom: RoomSession? = nil
local roomRandom = Random.new()
local lastRoomTypeByRunId: { [string]: string } = {}
local initialized = false
local started = false

local ROOM_ACTION_KEYS: { [string]: boolean } = {
	Action = true,
	RunId = true,
	RoomId = true,
	CellId = true,
	PanelId = true,
}
local PICKUP_ACTION_KEYS: { [string]: boolean } = { Action = true, RunId = true, RoomId = true, CellId = true }
local ROOM_BASE_ACTION_KEYS: { [string]: boolean } = { Action = true, RunId = true, RoomId = true }
local SIGNAL_ACTION_KEYS: { [string]: boolean } = { Action = true, RunId = true, RoomId = true, PanelId = true }

local roomStartedEvent = Instance.new("BindableEvent")
local roomProgressedEvent = Instance.new("BindableEvent")
local roomResolvedEvent = Instance.new("BindableEvent")
local roomCancelledEvent = Instance.new("BindableEvent")
local roomCleanedEvent = Instance.new("BindableEvent")

local RoomService = {
	Name = "RoomService",
	RoomStarted = roomStartedEvent.Event,
	RoomProgressed = roomProgressedEvent.Event,
	RoomResolved = roomResolvedEvent.Event,
	RoomCancelled = roomCancelledEvent.Event,
	RoomCleaned = roomCleanedEvent.Event,
}

local function makeSnapshot(session: RoomSession): RoomSnapshot
	return {
		RunId = session.RunId,
		RoomId = session.RoomId,
		RoomType = session.RoomType,
		DisplayName = session.DisplayName,
		ObjectiveText = session.ObjectiveText,
		Status = session.Status,
		Tier = session.Tier,
		RequiredCells = session.RequiredCells,
		DepositedCells = session.DepositedCells,
		Progress = session.DepositedCells,
		RequiredProgress = session.RequiredCells,
		Phase = session.Phase,
		TimeLimitSeconds = session.TimeLimitSeconds,
		StartedAt = session.StartedAt,
		EndsAt = session.EndsAt,
		ResolutionReason = session.ResolutionReason,
	}
end

local function chooseRandomRoomType(runId: string): string
	local previous = lastRoomTypeByRunId[runId]
	local choices = {}
	for _, roomType in BalanceConfig.Run.RoomPool do
		if roomType ~= previous then
			table.insert(choices, roomType)
		end
	end
	local selected = choices[roomRandom:NextInteger(1, #choices)]
	lastRoomTypeByRunId[runId] = selected
	return selected
end

local function definitionForTier(authoredDefinition: any, tier: number): any
	local definition = {}
	for key, value in authoredDefinition do definition[key] = value end
	definition.ArenaOrigin = WorldGeometry.GetTowerTierOrigin(tier)
	return definition
end

local function trackConnection(session: RoomSession, connection: RBXScriptConnection)
	table.insert(session.Connections, connection)
end

local function sendRoomEvent(session: RoomSession, eventType: string, snapshot: RoomSnapshot, details: any?)
	local remote = uiEventRemote
	if remote == nil then
		return
	end

	local payload: any = {
		Type = eventType,
		Room = snapshot,
	}
	if type(details) == "table" then
		for key, value in details do
			payload[key] = value
		end
	end

	for _, player in session.Participants do
		if player.Parent == Players and runService.IsParticipant(player, session.RunId) then
			remote:FireClient(player, payload)
		end
	end
end

local function sendActionResult(
	player: Player,
	action: string,
	success: boolean,
	errorCode: string?,
	snapshot: RoomSnapshot?
)
	local remote = uiEventRemote
	if remote == nil or player.Parent ~= Players then
		return
	end
	remote:FireClient(player, {
		Type = "RoomActionResult",
		Action = action,
		Success = success,
		Error = errorCode,
		Room = snapshot,
	})
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function isWithinDistance(player: Player, target: BasePart): boolean
	local root = getCharacterRoot(player)
	return root ~= nil and (root.Position - target.Position).Magnitude <= ROOM_CONFIG.MaxInteractionDistance
end

local function resetCell(session: RoomSession, cell: CellState)
	if cell.State == "DEPOSITED" then
		return
	end
	if cell.CarrierUserId ~= nil then
		session.CarriedByUserId[cell.CarrierUserId] = nil
	end
	if cell.Weld ~= nil then
		cell.Weld:Destroy()
		cell.Weld = nil
	end

	cell.CarrierUserId = nil
	cell.State = "AVAILABLE"
	if cell.Part.Parent ~= nil then
		cell.Part.Anchored = true
		cell.Part.AssemblyLinearVelocity = Vector3.zero
		cell.Part.AssemblyAngularVelocity = Vector3.zero
		cell.Part.CFrame = cell.StartCFrame
		cell.Prompt.Enabled = true
	end
end

local function resetCarriedCellForUser(session: RoomSession, userId: number)
	local cellId = session.CarriedByUserId[userId]
	if cellId == nil then
		return
	end
	local cell = session.Cells[cellId]
	if cell ~= nil then
		resetCell(session, cell)
	else
		session.CarriedByUserId[userId] = nil
	end
end

local function teleportCharacter(session: RoomSession, player: Player, character: Model, participantIndex: number)
	if not session.Active or not runService.IsParticipant(player, session.RunId) then
		return
	end
	local spawnCFrames = session.Build.SpawnCFrames
	local spawnCFrame = spawnCFrames[((participantIndex - 1) % #spawnCFrames) + 1]
	character:PivotTo(spawnCFrame)
end

local function connectParticipant(session: RoomSession, player: Player, participantIndex: number)
	local character = player.Character
	if character ~= nil then
		session.OriginalPivots[player.UserId] = character:GetPivot()
		teleportCharacter(session, player, character, participantIndex)
	end

	trackConnection(session, player.CharacterAdded:Connect(function(newCharacter)
		task.defer(function()
			local root = newCharacter:WaitForChild("HumanoidRootPart", 5)
			if root ~= nil and session.Active then
				teleportCharacter(session, player, newCharacter, participantIndex)
			end
		end)
	end))
	trackConnection(session, player.CharacterRemoving:Connect(function()
		resetCarriedCellForUser(session, player.UserId)
	end))
end

local function getHazardPlayer(session: RoomSession, hit: BasePart): (Player?, Model?)
	if not session.Active or session.Status ~= "ACTIVE" then
		return nil, nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player == nil or not runService.IsParticipant(player, session.RunId) then
		return nil, nil
	end

	local now = os.clock()
	local previous = session.HazardLastHitAt[player.UserId]
	if previous ~= nil and now - previous < ROOM_CONFIG.HazardHitCooldownSeconds then
		return nil, nil
	end
	session.HazardLastHitAt[player.UserId] = now
	return player, character
end

local function onReactorHazardTouched(session: RoomSession, hit: BasePart)
	local player, character = getHazardPlayer(session, hit)
	if player == nil or character == nil then
		return
	end

	resetCarriedCellForUser(session, player.UserId)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid.Health > 0 then
		local tiers = BalanceConfig.Rooms.ReactorRun.Tiers
		local difficulty = tiers[session.Tier]
		humanoid:TakeDamage(difficulty.HazardDamage)
	end

	sendRoomEvent(session, "RoomHazardHit", makeSnapshot(session), {
		PlayerUserId = player.UserId,
	})
end

local function onLaserTouched(session: RoomSession, hit: BasePart)
	local player, character = getHazardPlayer(session, hit)
	if player == nil or character == nil then
		return
	end
	local difficulty = BalanceConfig.Rooms.LaserGrid.Tiers[session.Tier]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid.Health > 0 then
		humanoid:TakeDamage(difficulty.LaserDamage)
	end
	for index, participant in session.Participants do
		if participant == player and character.Parent ~= nil then
			teleportCharacter(session, player, character, index)
			break
		end
	end
	sendRoomEvent(session, "RoomHazardHit", makeSnapshot(session), { PlayerUserId = player.UserId })
end

local function updateRoomDisplay(session: RoomSession, remainingSeconds: number)
	if session.RoomType == "ReactorRun" then
		ReactorBuilder.UpdateTimer(session.Build, remainingSeconds, session.DepositedCells, session.RequiredCells)
	elseif session.RoomType == "SignalSequence" then
		SignalSequenceBuilder.Update(session.Build, session.SequencePosition, session.RequiredCells, session.SequenceMistakes, remainingSeconds)
	elseif session.RoomType == "LaserGrid" then
		LaserGridBuilder.Update(session.Build, session.DepositedCells, session.RequiredCells, remainingSeconds)
	end
end

local function startRoomHeartbeat(session: RoomSession, definition: any, difficulty: any)
	if session.RoomType == "ReactorRun" then
		for _, hazardData in session.Build.Hazards do
			trackConnection(session, hazardData.Part.Touched:Connect(function(hit)
				if hit:IsA("BasePart") then
					onReactorHazardTouched(session, hit)
				end
			end))
		end
	elseif session.RoomType == "LaserGrid" then
		for _, laserData in session.Build.Lasers do
			trackConnection(session, laserData.Part.Touched:Connect(function(hit)
				if hit:IsA("BasePart") then
					onLaserTouched(session, hit)
				end
			end))
		end
	end

	local startedAt = Workspace:GetServerTimeNow()
	session.HeartbeatConnection = RobloxRunService.Heartbeat:Connect(function()
		if not session.Active then
			return
		end
		local elapsed = Workspace:GetServerTimeNow() - startedAt
		if session.RoomType == "ReactorRun" then
			local radians = elapsed * (2 * math.pi / difficulty.HazardCycleSeconds)
			for _, hazardData in session.Build.Hazards do
				local xOffset = math.sin(radians + hazardData.Phase) * definition.HazardTravelX
				local basePosition = hazardData.BasePosition
				hazardData.Part.Position = Vector3.new(definition.ArenaOrigin.X + xOffset, basePosition.Y, basePosition.Z)
			end
		elseif session.RoomType == "LaserGrid" then
			local radians = elapsed * (2 * math.pi / difficulty.LaserCycleSeconds)
			for _, laserData in session.Build.Lasers do
				local offset = math.sin(radians + laserData.Phase) * difficulty.TravelDistance
				local basePosition = laserData.BasePosition
				laserData.Part.Position = if laserData.Vertical
					then Vector3.new(basePosition.X + offset, basePosition.Y, basePosition.Z)
					else Vector3.new(basePosition.X, math.max(1, basePosition.Y + offset * (1 / 4)), basePosition.Z)
			end
		end

		local remainingSeconds = math.max(0, math.ceil(session.EndsAt - Workspace:GetServerTimeNow()))
		if remainingSeconds ~= session.LastDisplayedSecond then
			session.LastDisplayedSecond = remainingSeconds
			updateRoomDisplay(session, remainingSeconds)
		end
	end)
end

local function actionAllowed(session: RoomSession, player: Player): boolean
	local now = os.clock()
	local previous = session.LastActionAt[player]
	if previous ~= nil and now - previous < ROOM_CONFIG.ClientActionCooldownSeconds then
		return false
	end
	session.LastActionAt[player] = now
	return true
end

function RoomService.Init()
	assert(not initialized, "RoomService.Init called more than once")

	local runServiceModule = script.Parent:FindFirstChild("RunService")
	local antiExploitModule = script.Parent:FindFirstChild("AntiExploitService")
	assert(runServiceModule and runServiceModule:IsA("ModuleScript"), "Services.RunService is missing")
	assert(antiExploitModule and antiExploitModule:IsA("ModuleScript"), "Services.AntiExploitService is missing")
	runService = require(runServiceModule)
	antiExploitService = require(antiExploitModule)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	assert(remotes and remotes:IsA("Folder"), "ReplicatedStorage.Remotes is missing")
	local roomAction = remotes:FindFirstChild("RoomAction")
	local uiEvent = remotes:FindFirstChild("UIEvent")
	assert(roomAction and roomAction:IsA("RemoteEvent"), "Remotes.RoomAction is missing")
	assert(uiEvent and uiEvent:IsA("RemoteEvent"), "Remotes.UIEvent is missing")
	roomActionRemote = roomAction
	uiEventRemote = uiEvent

	local tower = Workspace:FindFirstChild("Tower")
	assert(tower and tower:IsA("Folder"), "Workspace.Tower is missing")
	local biome = tower:FindFirstChild("Biome01")
	assert(biome and biome:IsA("Folder"), "Workspace.Tower.Biome01 is missing")
	local existing = biome:FindFirstChild("ActiveRooms")
	if existing ~= nil then
		assert(existing:IsA("Folder"), "Workspace.Tower.Biome01.ActiveRooms must be a Folder")
		activeRoomsFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "ActiveRooms"
		folder.Parent = biome
		activeRoomsFolder = folder
	end

	initialized = true
end

function RoomService.GetActiveRoom(): RoomSnapshot?
	return if activeRoom == nil then nil else makeSnapshot(activeRoom)
end

function RoomService.Start(runId: string, roomType: string?): (RoomSnapshot?, string?)
	assert(initialized, "RoomService.Init must run before use")
	if activeRoom ~= nil then
		return nil, "ROOM_ALREADY_ACTIVE"
	end

	local run = runService.GetActiveRun()
	if run == nil then
		return nil, "NO_ACTIVE_RUN"
	end
	if run.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if run.State ~= "TRAVEL" and run.State ~= "DECISION" then
		return nil, "INVALID_RUN_STATE"
	end

	local selectedRoomType = roomType or chooseRandomRoomType(runId)
	local authoredDefinition = RoomDefinitions[selectedRoomType]
	local roomBalance = BalanceConfig.Rooms[selectedRoomType]
	if authoredDefinition == nil or roomBalance == nil then
		return nil, "UNKNOWN_ROOM_TYPE"
	end

	local participants, participantError = runService.GetParticipants(runId)
	if participants == nil then
		return nil, participantError
	end
	if #participants == 0 then
		return nil, "NO_PARTICIPANTS"
	end

	local tier = math.clamp(run.Stage, 1, #roomBalance.Tiers)
	local difficulty = roomBalance.Tiers[tier]
	local definition = definitionForTier(authoredDefinition, tier)
	local requiredProgress = if selectedRoomType == "ReactorRun"
		then difficulty.BaseCells + math.max(#participants - 1, 0) * difficulty.CellsPerAdditionalPlayer
		elseif selectedRoomType == "SignalSequence"
		then difficulty.SequenceLength
		else math.max(1, math.ceil(#participants * difficulty.CompletionRatio))
	local roomId = HttpService:GenerateGUID(false)
	local startedAt = Workspace:GetServerTimeNow()
	local parent = activeRoomsFolder
	assert(parent ~= nil, "ActiveRooms folder is unavailable")

	local buildSuccess, buildOrError = pcall(function()
		if selectedRoomType == "ReactorRun" then
			return ReactorBuilder.Create(parent, runId, roomId, definition, difficulty, #participants, requiredProgress)
		elseif selectedRoomType == "SignalSequence" then
			return SignalSequenceBuilder.Create(parent, runId, roomId, definition, difficulty, #participants)
		end
		return LaserGridBuilder.Create(parent, runId, roomId, definition, difficulty, #participants, requiredProgress)
	end)
	if not buildSuccess then
		warn(`[RoomService] {selectedRoomType} build failed for {runId}: {tostring(buildOrError)}`)
		return nil, "ROOM_BUILD_FAILED"
	end

	local cells: { [string]: CellState } = {}
	if selectedRoomType == "ReactorRun" then
		for cellId, cellData in buildOrError.Cells do
			cellData.State = "AVAILABLE"
			cellData.CarrierUserId = nil
			cellData.Weld = nil
			cells[cellId] = cellData
		end
	end
	local sequence = {}
	if selectedRoomType == "SignalSequence" then
		for _ = 1, difficulty.SequenceLength do
			table.insert(sequence, `Signal{roomRandom:NextInteger(1, difficulty.PanelCount)}`)
		end
	end

	local session: RoomSession = {
		RunId = runId,
		RoomId = roomId,
		RoomType = selectedRoomType,
		DisplayName = definition.DisplayName,
		ObjectiveText = definition.ObjectiveText,
		Status = "ACTIVE",
		Tier = tier,
		RequiredCells = requiredProgress,
		DepositedCells = 0,
		TimeLimitSeconds = difficulty.TimeLimitSeconds,
		StartedAt = startedAt,
		EndsAt = startedAt + difficulty.TimeLimitSeconds,
		ResolutionReason = nil,
		Participants = participants,
		Build = buildOrError,
		Cells = cells,
		CarriedByUserId = {},
		Connections = {},
		HeartbeatConnection = nil,
		DeadlineThread = nil,
		OriginalPivots = {},
		LastActionAt = {},
		HazardLastHitAt = {},
		LastDisplayedSecond = difficulty.TimeLimitSeconds,
		Phase = if selectedRoomType == "SignalSequence" then "MEMORIZE" else "ACTIVE",
		PhaseThread = nil,
		Sequence = sequence,
		SequencePosition = 0,
		SequenceMistakes = 0,
		SequenceInputEnabled = false,
		FinishedUserIds = {},
		Active = true,
	}
	activeRoom = session

	local _, setRoomError = runService.SetActiveRoom(runId, roomId)
	if setRoomError ~= nil then
		RoomService.Cleanup(runId, roomId, false)
		return nil, setRoomError
	end
	local _, transitionError = runService.Transition(runId, "ROOM", "RoomStarted")
	if transitionError ~= nil then
		RoomService.Cleanup(runId, roomId, false)
		return nil, transitionError
	end

	if selectedRoomType == "ReactorRun" then
		for cellId, cell in session.Cells do
			trackConnection(session, cell.Prompt.Triggered:Connect(function(player)
				local success, snapshot, actionError = RoomService.Action(player, { Action = "PickupCell", RunId = runId, RoomId = roomId, CellId = cellId })
				sendActionResult(player, "PickupCell", success, actionError, snapshot)
			end))
		end
		trackConnection(session, session.Build.DepositPrompt.Triggered:Connect(function(player)
			local success, snapshot, actionError = RoomService.Action(player, { Action = "DepositCell", RunId = runId, RoomId = roomId })
			sendActionResult(player, "DepositCell", success, actionError, snapshot)
		end))
	elseif selectedRoomType == "SignalSequence" then
		for panelId, panel in session.Build.Panels do
			trackConnection(session, panel.Prompt.Triggered:Connect(function(player)
				local success, snapshot, actionError = RoomService.Action(player, { Action = "ActivateSignal", RunId = runId, RoomId = roomId, PanelId = panelId })
				sendActionResult(player, "ActivateSignal", success, actionError, snapshot)
			end))
		end
		SignalSequenceBuilder.ShowSequence(session.Build, session.Sequence, difficulty.MemorizeSeconds)
		session.PhaseThread = task.delay(difficulty.MemorizeSeconds, function()
			session.PhaseThread = nil
			if activeRoom == session and session.Active and session.Status == "ACTIVE" then
				session.Phase = "INPUT"
				session.SequenceInputEnabled = true
				SignalSequenceBuilder.BeginInput(session.Build)
				sendRoomEvent(session, "RoomPhaseChanged", makeSnapshot(session), { Phase = "INPUT" })
			end
		end)
	else
		trackConnection(session, session.Build.ExitPrompt.Triggered:Connect(function(player)
			local success, snapshot, actionError = RoomService.Action(player, { Action = "ReachExit", RunId = runId, RoomId = roomId })
			sendActionResult(player, "ReachExit", success, actionError, snapshot)
		end))
	end

	for index, player in session.Participants do
		connectParticipant(session, player, index)
	end
	startRoomHeartbeat(session, definition, difficulty)

	session.DeadlineThread = task.delay(session.TimeLimitSeconds, function()
		session.DeadlineThread = nil
		if activeRoom == session and session.Active and session.Status == "ACTIVE" then
			RoomService.Resolve(runId, roomId, false, "TIME_EXPIRED")
		end
	end)

	local snapshot = makeSnapshot(session)
	roomStartedEvent:Fire(snapshot)
	sendRoomEvent(session, "RoomStarted", snapshot)
	return snapshot, nil
end

function RoomService.Action(player: Player, payload: any): (boolean, RoomSnapshot?, string?)
	if type(payload) ~= "table"
		or type(payload.Action) ~= "string"
		or type(payload.RunId) ~= "string"
		or type(payload.RoomId) ~= "string"
	then
		return false, nil, "INVALID_PAYLOAD"
	end

	local session = activeRoom
	if session == nil then
		return false, nil, "NO_ACTIVE_ROOM"
	end
	if session.RunId ~= payload.RunId then
		return false, nil, "STALE_RUN_ID"
	end
	if session.RoomId ~= payload.RoomId then
		return false, nil, "STALE_ROOM_ID"
	end
	if not session.Active or session.Status ~= "ACTIVE" then
		return false, makeSnapshot(session), "ROOM_NOT_ACTIVE"
	end
	if not runService.IsParticipant(player, session.RunId) then
		return false, nil, "NOT_A_PARTICIPANT"
	end
	local run = runService.GetRunForPlayer(player)
	if run == nil or run.State ~= "ROOM" or run.ActiveRoomId ~= session.RoomId then
		return false, makeSnapshot(session), "INVALID_RUN_STATE"
	end
	if not actionAllowed(session, player) then
		return false, makeSnapshot(session), "RATE_LIMITED"
	end
	local difficulty = BalanceConfig.Rooms[session.RoomType].Tiers[session.Tier]

	if session.RoomType == "ReactorRun" and payload.Action == "PickupCell" then
		if type(payload.CellId) ~= "string" then
			return false, makeSnapshot(session), "INVALID_CELL_ID"
		end
		if session.CarriedByUserId[player.UserId] ~= nil then
			return false, makeSnapshot(session), "ALREADY_CARRYING"
		end
		local cell = session.Cells[payload.CellId]
		if cell == nil then
			return false, makeSnapshot(session), "UNKNOWN_CELL"
		end
		if cell.State ~= "AVAILABLE" then
			return false, makeSnapshot(session), "CELL_UNAVAILABLE"
		end
		if not isWithinDistance(player, cell.Part) then
			return false, makeSnapshot(session), "TOO_FAR"
		end

		local root = getCharacterRoot(player)
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if root == nil or humanoid == nil or humanoid.Health <= 0 then
			return false, makeSnapshot(session), "CHARACTER_UNAVAILABLE"
		end

		cell.State = "CARRIED"
		cell.CarrierUserId = player.UserId
		session.CarriedByUserId[player.UserId] = cell.Id
		cell.Prompt.Enabled = false
		cell.Part.Anchored = false
		cell.Part.CanCollide = false
		cell.Part.CFrame = root.CFrame * RoomDefinitions.ReactorRun.CarryOffset
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = root
		weld.Part1 = cell.Part
		weld.Parent = cell.Part
		cell.Weld = weld

		local snapshot = makeSnapshot(session)
		sendRoomEvent(session, "RoomCellState", snapshot, {
			CellId = cell.Id,
			CellState = "CARRIED",
			CarrierUserId = player.UserId,
		})
		return true, snapshot, nil
	elseif session.RoomType == "ReactorRun" and payload.Action == "DepositCell" then
		local cellId = session.CarriedByUserId[player.UserId]
		if cellId == nil then
			return false, makeSnapshot(session), "NOT_CARRYING"
		end
		if not isWithinDistance(player, session.Build.Reactor) then
			return false, makeSnapshot(session), "TOO_FAR"
		end

		local cell = session.Cells[cellId]
		if cell == nil or cell.State ~= "CARRIED" or cell.CarrierUserId ~= player.UserId then
			return false, makeSnapshot(session), "INVALID_CARRIED_CELL"
		end
		if cell.Weld ~= nil then
			cell.Weld:Destroy()
			cell.Weld = nil
		end
		cell.State = "DEPOSITED"
		cell.CarrierUserId = nil
		session.CarriedByUserId[player.UserId] = nil
		cell.Part:Destroy()
		session.DepositedCells += 1
		ReactorBuilder.UpdateProgress(session.Build, session.DepositedCells, session.RequiredCells)
		ReactorBuilder.UpdateTimer(
			session.Build,
			session.LastDisplayedSecond,
			session.DepositedCells,
			session.RequiredCells
		)

		local progressSnapshot = makeSnapshot(session)
		roomProgressedEvent:Fire(progressSnapshot, player.UserId, cellId)
		sendRoomEvent(session, "RoomProgress", progressSnapshot, {
			PlayerUserId = player.UserId,
			CellId = cellId,
		})

		if session.DepositedCells >= session.RequiredCells then
			local resolvedSnapshot, resolveError = RoomService.Resolve(
				session.RunId,
				session.RoomId,
				true,
				"OBJECTIVE_COMPLETE"
			)
			return resolvedSnapshot ~= nil, resolvedSnapshot, resolveError
		end
		return true, progressSnapshot, nil
	elseif session.RoomType == "SignalSequence" and payload.Action == "ActivateSignal" then
		if type(payload.PanelId) ~= "string" then
			return false, makeSnapshot(session), "INVALID_PANEL_ID"
		end
		if not session.SequenceInputEnabled or session.Phase ~= "INPUT" then
			return false, makeSnapshot(session), "INPUT_NOT_READY"
		end
		local panel = session.Build.Panels[payload.PanelId]
		if panel == nil then
			return false, makeSnapshot(session), "UNKNOWN_PANEL"
		end
		if not isWithinDistance(player, panel.Part) then
			return false, makeSnapshot(session), "TOO_FAR"
		end

		local expectedPanelId = session.Sequence[session.SequencePosition + 1]
		if payload.PanelId == expectedPanelId then
			session.SequencePosition += 1
		else
			session.SequencePosition = 0
			session.SequenceMistakes += 1
		end
		session.DepositedCells = session.SequencePosition
		SignalSequenceBuilder.Update(session.Build, session.SequencePosition, session.RequiredCells, session.SequenceMistakes, session.LastDisplayedSecond)
		local progressSnapshot = makeSnapshot(session)
		roomProgressedEvent:Fire(progressSnapshot, player.UserId, payload.PanelId)
		sendRoomEvent(session, "RoomProgress", progressSnapshot, {
			PlayerUserId = player.UserId,
			PanelId = payload.PanelId,
			Correct = payload.PanelId == expectedPanelId,
			Mistakes = session.SequenceMistakes,
		})

		if session.SequenceMistakes >= difficulty.MaxMistakes then
			local resolved, resolveError = RoomService.Resolve(session.RunId, session.RoomId, false, "TOO_MANY_MISTAKES")
			return resolved ~= nil, resolved, resolveError
		end
		if session.SequencePosition >= session.RequiredCells then
			local resolved, resolveError = RoomService.Resolve(session.RunId, session.RoomId, true, "SEQUENCE_COMPLETE")
			return resolved ~= nil, resolved, resolveError
		end
		return true, progressSnapshot, nil
	elseif session.RoomType == "LaserGrid" and payload.Action == "ReachExit" then
		if session.FinishedUserIds[player.UserId] then
			return false, makeSnapshot(session), "PLAYER_ALREADY_FINISHED"
		end
		if not isWithinDistance(player, session.Build.Exit) then
			return false, makeSnapshot(session), "TOO_FAR"
		end

		session.FinishedUserIds[player.UserId] = true
		session.DepositedCells += 1
		LaserGridBuilder.Update(session.Build, session.DepositedCells, session.RequiredCells, session.LastDisplayedSecond)
		local progressSnapshot = makeSnapshot(session)
		roomProgressedEvent:Fire(progressSnapshot, player.UserId, "Exit")
		sendRoomEvent(session, "RoomProgress", progressSnapshot, { PlayerUserId = player.UserId, ReachedExit = true })
		if session.DepositedCells >= session.RequiredCells then
			local resolved, resolveError = RoomService.Resolve(session.RunId, session.RoomId, true, "EXIT_REACHED")
			return resolved ~= nil, resolved, resolveError
		end
		return true, progressSnapshot, nil
	end

	return false, makeSnapshot(session), "UNKNOWN_ACTION"
end

function RoomService.Cleanup(runId: string, roomId: string, restorePlayers: boolean?): (boolean, string?)
	local session = activeRoom
	if session == nil then
		return false, "NO_ACTIVE_ROOM"
	end
	if session.RunId ~= runId then
		return false, "STALE_RUN_ID"
	end
	if session.RoomId ~= roomId then
		return false, "STALE_ROOM_ID"
	end

	session.Active = false
	if session.DeadlineThread ~= nil then
		pcall(task.cancel, session.DeadlineThread)
		session.DeadlineThread = nil
	end
	if session.PhaseThread ~= nil then
		pcall(task.cancel, session.PhaseThread)
		session.PhaseThread = nil
	end
	if session.HeartbeatConnection ~= nil then
		session.HeartbeatConnection:Disconnect()
		session.HeartbeatConnection = nil
	end
	for _, connection in session.Connections do
		connection:Disconnect()
	end
	table.clear(session.Connections)

	for _, cell in session.Cells do
		if cell.Weld ~= nil then
			cell.Weld:Destroy()
			cell.Weld = nil
		end
	end

	if restorePlayers ~= false then
		for _, player in session.Participants do
			local originalPivot = session.OriginalPivots[player.UserId]
			local character = player.Character
			if originalPivot ~= nil and character ~= nil and character.Parent ~= nil then
				character:PivotTo(originalPivot)
			end
		end
	end

	if session.Build.Model.Parent ~= nil then
		session.Build.Model:Destroy()
	end
	if activeRoom == session then
		activeRoom = nil
	end
	runService.SetActiveRoom(runId, nil)
	roomCleanedEvent:Fire(runId, roomId)
	return true, nil
end

function RoomService.Resolve(
	runId: string,
	roomId: string,
	success: boolean,
	reason: string
): (RoomSnapshot?, string?)
	local session = activeRoom
	if session == nil then
		return nil, "NO_ACTIVE_ROOM"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.RoomId ~= roomId then
		return nil, "STALE_ROOM_ID"
	end
	if not session.Active or session.Status ~= "ACTIVE" then
		return nil, "ROOM_ALREADY_RESOLVED"
	end

	session.Status = if success then "SUCCESS" else "FAILED"
	session.ResolutionReason = if reason == "" then (if success then "SUCCESS" else "FAILED") else reason
	local snapshot = makeSnapshot(session)
	sendRoomEvent(session, "RoomResolved", snapshot)
	RoomService.Cleanup(runId, roomId, true)

	if success then
		local _, transitionError = runService.Transition(runId, "DECISION", "RoomSucceeded")
		if transitionError ~= nil then
			runService.FinishRun(runId, "RoomSuccessTransitionFailed")
			return snapshot, transitionError
		end
	else
		local _, transitionError = runService.Transition(runId, "RESULTS", `RoomFailed_{session.ResolutionReason}`)
		if transitionError ~= nil then
			runService.FinishRun(runId, "RoomFailureTransitionFailed")
			return snapshot, transitionError
		end
	end
	roomResolvedEvent:Fire(snapshot, success)
	return snapshot, nil
end

function RoomService.Cancel(runId: string, roomId: string, reason: string): (RoomSnapshot?, string?)
	local session = activeRoom
	if session == nil then
		return nil, "NO_ACTIVE_ROOM"
	end
	if session.RunId ~= runId then
		return nil, "STALE_RUN_ID"
	end
	if session.RoomId ~= roomId then
		return nil, "STALE_ROOM_ID"
	end

	session.Status = "CANCELLED"
	session.ResolutionReason = if reason == "" then "CANCELLED" else reason
	local snapshot = makeSnapshot(session)
	roomCancelledEvent:Fire(snapshot)
	sendRoomEvent(session, "RoomCancelled", snapshot)
	RoomService.Cleanup(runId, roomId, true)

	local run = runService.GetActiveRun()
	if run ~= nil and run.RunId == runId then
		runService.FinishRun(runId, `RoomCancelled_{session.ResolutionReason}`)
	end
	return snapshot, nil
end

local function handleRemoteAction(player: Player, payload: any)
	local action = if type(payload) == "table" and type(payload.Action) == "string" and #payload.Action <= 64 then payload.Action else "Unknown"
	if not antiExploitService.AllowAction(player, "RoomAction") then
		sendActionResult(player, action, false, "RATE_LIMITED", nil)
		return
	end
	local valid = antiExploitService.ValidatePayload(payload, ROOM_ACTION_KEYS)
	if not valid
		or not antiExploitService.IsBoundedString(if type(payload) == "table" then payload.Action else nil)
		or not antiExploitService.IsBoundedString(if type(payload) == "table" then payload.RunId else nil)
		or not antiExploitService.IsBoundedString(if type(payload) == "table" then payload.RoomId else nil)
		or (type(payload) == "table" and payload.CellId ~= nil and not antiExploitService.IsBoundedString(payload.CellId))
		or (type(payload) == "table" and payload.PanelId ~= nil and not antiExploitService.IsBoundedString(payload.PanelId))
	then
		antiExploitService.RecordRejection(player, "RoomAction", "INVALID_PAYLOAD")
		sendActionResult(player, action, false, "INVALID_PAYLOAD", nil)
		return
	end
	local exactKeys = if action == "PickupCell"
		then PICKUP_ACTION_KEYS
		elseif action == "DepositCell" or action == "ReachExit" then ROOM_BASE_ACTION_KEYS
		elseif action == "ActivateSignal" then SIGNAL_ACTION_KEYS
		else nil
	if exactKeys == nil or not antiExploitService.ValidatePayload(payload, exactKeys) then
		antiExploitService.RecordRejection(player, "RoomAction", "UNKNOWN_ACTION_OR_FIELDS")
		sendActionResult(player, action, false, "INVALID_PAYLOAD", nil)
		return
	end
	local callSuccess, success, snapshot, actionError = pcall(RoomService.Action, player, payload)
	if not callSuccess then
		warn(`[RoomService] Action error for {player.UserId}: {tostring(success)}`)
		local session = activeRoom
		if session ~= nil then
			RoomService.Cancel(session.RunId, session.RoomId, "ROOM_ACTION_ERROR")
		end
		sendActionResult(player, action, false, "ROOM_ACTION_ERROR", nil)
		return
	end
	sendActionResult(player, action, success, actionError, snapshot)
end

function RoomService.StartService()
	assert(initialized, "RoomService.Init must run before StartService")
	assert(not started, "RoomService.StartService called more than once")
	started = true

	local remote = roomActionRemote
	assert(remote ~= nil, "RoomAction remote is unavailable")
	remote.OnServerEvent:Connect(handleRemoteAction)

	runService.RunStateChanged:Connect(function(run: any)
		if run.State == "PREPARATION" then
			task.delay(BalanceConfig.Run.PreparationSeconds, function()
				local current = runService.GetActiveRun()
				if current ~= nil and current.RunId == run.RunId and current.State == "PREPARATION" then
					runService.Transition(run.RunId, "TRAVEL", "PreparationComplete")
				end
			end)
		elseif run.State == "TRAVEL" then
			task.delay(BalanceConfig.Run.TravelSeconds, function()
				local current = runService.GetActiveRun()
				if current == nil or current.RunId ~= run.RunId or current.State ~= "TRAVEL" then
					return
				end
				local callSuccess, snapshot, startError = pcall(RoomService.Start, run.RunId)
				if not callSuccess or snapshot == nil then
					warn(`[RoomService] Failed to start challenge room for {run.RunId}: {tostring(if callSuccess then startError else snapshot)}`)
					runService.FinishRun(run.RunId, "RoomStartFailed")
				end
			end)
		elseif run.State ~= "ROOM" then
			local session = activeRoom
			if session ~= nil and session.RunId == run.RunId then
				RoomService.Cleanup(session.RunId, session.RoomId, true)
			end
		end
	end)

	runService.ParticipantsChanged:Connect(function(run: any, userId: number)
		local session = activeRoom
		if session ~= nil and session.RunId == run.RunId then
			resetCarriedCellForUser(session, userId)
			if session.Active then
				local remainingParticipants = runService.GetParticipants(session.RunId) or {}
				if #remainingParticipants == 0 then return end
				local difficulty = BalanceConfig.Rooms[session.RoomType].Tiers[session.Tier]
				if session.RoomType == "ReactorRun" then
					session.RequiredCells = difficulty.BaseCells
						+ math.max(#remainingParticipants - 1, 0) * difficulty.CellsPerAdditionalPlayer
					ReactorBuilder.UpdateProgress(session.Build, session.DepositedCells, session.RequiredCells)
					ReactorBuilder.UpdateTimer(session.Build, session.LastDisplayedSecond, session.DepositedCells, session.RequiredCells)
				elseif session.RoomType == "LaserGrid" then
					session.RequiredCells = math.max(1, math.ceil(#remainingParticipants * difficulty.CompletionRatio))
					LaserGridBuilder.Update(session.Build, session.DepositedCells, session.RequiredCells, session.LastDisplayedSecond)
				end
				if session.DepositedCells >= session.RequiredCells then
					RoomService.Resolve(session.RunId, session.RoomId, true, "REMAINING_TEAM_COMPLETED")
				else
					sendRoomEvent(session, "RoomProgress", makeSnapshot(session), { ParticipantLeftUserId = userId })
				end
			end
		end
	end)

	runService.RunClosed:Connect(function(run: any)
		lastRoomTypeByRunId[run.RunId] = nil
		local session = activeRoom
		if session ~= nil and session.RunId == run.RunId then
			RoomService.Cleanup(session.RunId, session.RoomId, true)
		end
	end)
end

return table.freeze(RoomService)
