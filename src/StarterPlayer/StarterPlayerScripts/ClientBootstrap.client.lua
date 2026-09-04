--!strict

-- StarterPlayerScripts descendants are copied into PlayerScripts by the engine.
-- On some Studio builds a LocalScript can start before all sibling folders have
-- finished parenting, so wait for them instead of treating the brief race as a
-- permanently broken project tree.
local controllersFolder = script.Parent:WaitForChild("Controllers", 10)
local clientFolder = script.Parent:WaitForChild("Client", 10)
assert(controllersFolder and controllersFolder:IsA("Folder"), "StarterPlayerScripts.Controllers is missing")
assert(clientFolder and clientFolder:IsA("Folder"), "StarterPlayerScripts.Client is missing")

local storeModule = clientFolder:FindFirstChild("ClientStore")
assert(storeModule and storeModule:IsA("ModuleScript"), "Client.ClientStore is missing")
local ClientStore = require(storeModule)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
assert(remotes and remotes:IsA("Folder"), "ReplicatedStorage.Remotes is missing")

local CONTROLLER_NAMES = {
	"HUDController",
	"RunController",
	"RoomController",
	"FarmController",
	"InventoryController",
	"UpgradeController",
	"TutorialController",
	"InteractionController",
	"AudioController",
}

local controllers = {}
for _, controllerName in CONTROLLER_NAMES do
	local controllerModule = controllersFolder:FindFirstChild(controllerName)
	assert(controllerModule and controllerModule:IsA("ModuleScript"), `{controllerName} is missing`)
	local controller = require(controllerModule)
	table.insert(controllers, controller)
end

local context = {
	Player = Players.LocalPlayer,
	Store = ClientStore,
	Remotes = remotes,
}

for _, controller in controllers do
	if type(controller.Init) == "function" then
		controller.Init(context)
	end
end

local uiEvent = remotes:FindFirstChild("UIEvent")
assert(uiEvent and uiEvent:IsA("RemoteEvent"), "Remotes.UIEvent is missing")
uiEvent.OnClientEvent:Connect(function(payload)
	ClientStore.ApplyServerEvent(payload)
	for _, controller in controllers do
		if type(controller.HandleEvent) == "function" then
			controller.HandleEvent(payload)
		end
	end
end)

for _, controller in controllers do
	if type(controller.Start) == "function" then
		controller.Start()
	end
end

local snapshotRemote = remotes:FindFirstChild("GetPlayerSnapshot")
assert(snapshotRemote and snapshotRemote:IsA("RemoteFunction"), "Remotes.GetPlayerSnapshot is missing")
task.spawn(function()
	for _ = 1, GameConfig.Client.InitialSnapshotAttempts do
		local success, response = pcall(function()
			return snapshotRemote:InvokeServer()
		end)
		if success and type(response) == "table" and response.Success and type(response.Snapshot) == "table" then
			ClientStore.SetSnapshot(response.Snapshot)
			return
		end
		task.wait(GameConfig.Client.InitialSnapshotRetrySeconds)
	end
	warn("[BrainrotTower] Initial player snapshot was not available")
end)

print(`[BrainrotTower] Client bootstrap loaded {#CONTROLLER_NAMES} controllers`)
