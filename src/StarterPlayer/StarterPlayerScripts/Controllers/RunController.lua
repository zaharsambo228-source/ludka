--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local clientFolder = script.Parent.Parent:FindFirstChild("Client")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")
local UIFactory = require(clientFolder:FindFirstChild("UIFactory") :: ModuleScript)
local Theme = require(clientFolder:FindFirstChild("Theme") :: ModuleScript)
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)

local store: any = nil
local decisionRemote: RemoteEvent? = nil
local revealScreen: ScreenGui? = nil
local revealCard: Frame? = nil
local revealStatus: TextLabel? = nil
local revealRarity: TextLabel? = nil
local revealName: TextLabel? = nil
local revealProduction: TextLabel? = nil
local decisionScreen: ScreenGui? = nil
local decisionCard: Frame? = nil
local decisionScale: UIScale? = nil
local pendingLabel: TextLabel? = nil
local riskLabel: TextLabel? = nil
local voteLabel: TextLabel? = nil
local countdownLabel: TextLabel? = nil
local claimButton: TextButton? = nil
local upgradeButton: TextButton? = nil
local failureScreen: ScreenGui? = nil
local failureCard: Frame? = nil
local failureTitle: TextLabel? = nil
local failureDetails: TextLabel? = nil
local revealVersion = 0
local failureVersion = 0
local revealActive = false
local lastPendingProduction = 0
local RunController = { Name = "RunController" }

local function rarityColor(rarity: string): Color3
	return Theme.RarityColors[rarity] or Theme.Colors.Text
end

local function addSizeConstraint(frame: Frame, maxX: number, maxY: number)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(maxX, maxY)
	constraint.MinSize = Vector2.new(math.min(310, maxX), math.min(250, maxY))
	constraint.Parent = frame
end

local function showReveal(pending: any, status: string, duration: number)
	revealVersion += 1
	local version = revealVersion
	revealActive = true
	if decisionScreen ~= nil then
		decisionScreen.Enabled = false
	end
	lastPendingProduction = pending.BaseProductionPerMinute or lastPendingProduction
	(revealScreen :: ScreenGui).Enabled = true
	(revealStatus :: TextLabel).Text = status
	(revealRarity :: TextLabel).Text = string.upper(pending.Rarity)
	(revealRarity :: TextLabel).TextColor3 = rarityColor(pending.Rarity)
	(revealName :: TextLabel).Text = pending.DisplayName
	(revealProduction :: TextLabel).Text = `Base farm production  +{UIFactory.FormatNumber(pending.BaseProductionPerMinute)} Coins/min`
	task.delay(duration, function()
		if revealVersion == version and revealScreen ~= nil then
			revealScreen.Enabled = false
			revealActive = false
			local state = store.GetState()
			if state.Run ~= nil and state.Run.State == "DECISION" then
				(decisionScreen :: ScreenGui).Enabled = true
			end
		end
	end)
end

local function localPlayerVoted(decision: any): boolean
	if decision == nil then return false end
	return table.find(decision.VotedUserIds, Players.LocalPlayer.UserId) ~= nil
end

local function updateDecision()
	local run = store.GetState().Run
	if run == nil or run.State ~= "DECISION" or run.PendingReward == nil or run.Decision == nil then
		(decisionScreen :: ScreenGui).Enabled = false
		return
	end
	if not revealActive then (decisionScreen :: ScreenGui).Enabled = true end
	local pending = run.PendingReward
	local decision = run.Decision
	(pendingLabel :: TextLabel).Text = `CURRENT PENDING REWARD\n{string.upper(pending.Rarity)} • {pending.DisplayName}\n+{UIFactory.FormatNumber(pending.BaseProductionPerMinute)} Coins/min base`
	(pendingLabel :: TextLabel).TextColor3 = rarityColor(pending.Rarity)
	local nextRarity = BalanceConfig.Run.RarityByStage[run.Stage + 1]
	if decision.CanUpgrade and nextRarity ~= nil then
		(riskLabel :: TextLabel).Text = `UPGRADE TARGET: {string.upper(nextRarity)}\nIf the next challenge fails, {pending.DisplayName} is lost.\nYour permanent collection stays safe.`
	else
		(riskLabel :: TextLabel).Text = "MAXIMUM TIER REACHED\nClaim now to make this reward permanent."
	end
	(voteLabel :: TextLabel).Text = `CLAIM {decision.ClaimVotes}/{decision.EligibleVoterCount}     UPGRADE {decision.UpgradeVotes}/{decision.EligibleVoterCount}`
	local voted = localPlayerVoted(decision)
	(claimButton :: TextButton).Active = not voted
	(claimButton :: TextButton).AutoButtonColor = not voted
	(claimButton :: TextButton).Text = if voted then "VOTE LOCKED" else "CLAIM & EXTRACT\nSafe • becomes PERMANENT"
	(upgradeButton :: TextButton).Active = not voted and decision.CanUpgrade
	(upgradeButton :: TextButton).AutoButtonColor = not voted and decision.CanUpgrade
	(upgradeButton :: TextButton).BackgroundColor3 = if decision.CanUpgrade then Theme.Colors.Risk else Theme.Colors.Disabled
	(upgradeButton :: TextButton).Text = if decision.CanUpgrade then "UPGRADE CHALLENGE\nRisk only the PENDING reward" else "MAX TIER • CLAIM REQUIRED"
end

local function castVote(choice: string)
	local run = store.GetState().Run
	if run == nil or run.DecisionId == nil then return end
	(decisionRemote :: RemoteEvent):FireServer({ Action = "Vote", RunId = run.RunId, DecisionId = run.DecisionId, Choice = choice })
end

local function showFailure(payload: any)
	local pending = payload.LostPendingReward
	if type(pending) ~= "table" then return end
	failureVersion += 1
	local version = failureVersion
	(failureScreen :: ScreenGui).Enabled = true
	(failureTitle :: TextLabel).Text = "PENDING REWARD LOST"
	(failureTitle :: TextLabel).TextColor3 = rarityColor(pending.Rarity)
	(failureDetails :: TextLabel).Text = `{pending.DisplayName} was not permanent yet.\n\nConsolation: +{UIFactory.FormatNumber(payload.ConsolationDust or 0)} Dust\n\n✓ Permanent collection unchanged`
	task.delay(BalanceConfig.UI.FailureMessageSeconds, function()
		if failureVersion == version and failureScreen ~= nil then failureScreen.Enabled = false end
	end)
end

function RunController.Init(context: any)
	store = context.Store
	decisionRemote = context.Remotes:FindFirstChild("DecisionVote") :: RemoteEvent
	revealScreen = UIFactory.GetScreen("RewardRevealUI", 30)
	UIFactory.Overlay(revealScreen :: ScreenGui)
	revealCard = UIFactory.Panel(revealScreen :: ScreenGui, "RewardCard", UDim2.new((9 / 10), 0, (23 / 50), 0), UDim2.fromScale((1 / 2), (12 / 25)))
	addSizeConstraint(revealCard :: Frame, 560, 300)
	revealStatus = UIFactory.Text(revealCard :: Frame, "CURRENT PENDING REWARD", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 16), 17, Theme.Colors.Muted)
	(revealStatus :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	revealRarity = UIFactory.Text(revealCard :: Frame, "RARE", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 48), 26)
	(revealRarity :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	revealName = UIFactory.Text(revealCard :: Frame, "Brainrot", UDim2.new(1, -40, 0, 52), UDim2.fromOffset(20, 86), 32)
	(revealName :: TextLabel).Font = Enum.Font.GothamBold
	(revealName :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	revealProduction = UIFactory.Text(revealCard :: Frame, "+0 Coins/min", UDim2.new(1, -40, 0, 36), UDim2.fromOffset(20, 142), 19, Theme.Colors.Coins)
	(revealProduction :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	UIFactory.Text(revealCard :: Frame, "PENDING • not in your permanent inventory yet", UDim2.new(1, -40, 0, 42), UDim2.fromOffset(20, 186), 16, Theme.Colors.Risk).TextXAlignment = Enum.TextXAlignment.Center
	(revealScreen :: ScreenGui).Enabled = false

	decisionScreen = UIFactory.GetScreen("DecisionUI", 31)
	UIFactory.Overlay(decisionScreen :: ScreenGui)
	decisionCard = UIFactory.Panel(decisionScreen :: ScreenGui, "DecisionCard", UDim2.new((47 / 50), 0, 0, 430), UDim2.fromScale((1 / 2), (1 / 2)))
	addSizeConstraint(decisionCard :: Frame, 720, 460)
	decisionScale = Instance.new("UIScale")
	decisionScale.Parent = decisionCard
	pendingLabel = UIFactory.Text(decisionCard :: Frame, "CURRENT PENDING REWARD", UDim2.new(1, -40, 0, 78), UDim2.fromOffset(20, 16), 21)
	(pendingLabel :: TextLabel).Font = Enum.Font.GothamBold
	riskLabel = UIFactory.Text(decisionCard :: Frame, "Risk explanation", UDim2.new(1, -40, 0, 78), UDim2.fromOffset(20, 100), 16, Theme.Colors.Risk)
	(riskLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	voteLabel = UIFactory.Text(decisionCard :: Frame, "CLAIM 0/1     UPGRADE 0/1", UDim2.new(1, -40, 0, 28), UDim2.fromOffset(20, 182), 15, Theme.Colors.Muted)
	(voteLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	countdownLabel = UIFactory.Text(decisionCard :: Frame, `{BalanceConfig.Run.DecisionSeconds}s`, UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 212), 19, Theme.Colors.Coins)
	(countdownLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	claimButton = UIFactory.Button(decisionCard :: Frame, "CLAIM & EXTRACT", UDim2.new(1, -40, 0, 72), Theme.Colors.Safe)
	(claimButton :: TextButton).Position = UDim2.fromOffset(20, 252)
	(claimButton :: TextButton).Activated:Connect(function() castVote("CLAIM") end)
	upgradeButton = UIFactory.Button(decisionCard :: Frame, "UPGRADE CHALLENGE", UDim2.new(1, -40, 0, 72), Theme.Colors.Risk)
	(upgradeButton :: TextButton).Position = UDim2.fromOffset(20, 336)
	(upgradeButton :: TextButton).Activated:Connect(function() castVote("UPGRADE") end)
	(decisionScreen :: ScreenGui).Enabled = false

	failureScreen = UIFactory.GetScreen("FailureUI", 40)
	UIFactory.Overlay(failureScreen :: ScreenGui)
	failureCard = UIFactory.Panel(failureScreen :: ScreenGui, "FailureCard", UDim2.new((9 / 10), 0, (23 / 50), 0), UDim2.fromScale((1 / 2), (1 / 2)))
	addSizeConstraint(failureCard :: Frame, 560, 300)
	failureTitle = UIFactory.Text(failureCard :: Frame, "PENDING REWARD LOST", UDim2.new(1, -40, 0, 48), UDim2.fromOffset(20, 24), 26, Theme.Colors.Risk)
	(failureTitle :: TextLabel).Font = Enum.Font.GothamBold
	(failureTitle :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	failureDetails = UIFactory.Text(failureCard :: Frame, "Permanent collection unchanged", UDim2.new(1, -60, 0, 150), UDim2.fromOffset(30, 82), 18)
	(failureDetails :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	(failureScreen :: ScreenGui).Enabled = false
	updateDecision()
end

function RunController.Start()
	store.Changed:Connect(updateDecision)
	RobloxRunService.RenderStepped:Connect(function()
		local run = store.GetState().Run
		if countdownLabel ~= nil and run ~= nil and run.Decision ~= nil then
			countdownLabel.Text = `{math.max(0, math.ceil(run.Decision.EndsAt - Workspace:GetServerTimeNow()))}s • missing votes default to CLAIM`
		end
		local camera = Workspace.CurrentCamera
		if decisionScale ~= nil and camera ~= nil then
			decisionScale.Scale = math.clamp((camera.ViewportSize.Y - 24) / 430, (13 / 20), 1)
		end
	end)
end

function RunController.HandleEvent(payload: any)
	if type(payload) ~= "table" then return end
	if payload.Type == "PendingRewardCreated" and payload.Run ~= nil and payload.Run.PendingReward ~= nil then
		showReveal(payload.Run.PendingReward, "CURRENT PENDING REWARD", BalanceConfig.UI.PendingRewardRevealSeconds)
	elseif payload.Type == "DecisionResolved" then
		(decisionScreen :: ScreenGui).Enabled = false
	elseif payload.Type == "PendingRewardLost" then
		showFailure(payload)
	elseif payload.Type == "ClaimActionResult" and payload.Success and payload.Claim ~= nil then
		local claim = payload.Claim
		showReveal({ Rarity = claim.Rarity, DisplayName = claim.DisplayName, BaseProductionPerMinute = lastPendingProduction }, "CLAIMED • PERMANENT & SAFE", BalanceConfig.UI.ClaimRevealSeconds)
	end
end

return table.freeze(RunController)
