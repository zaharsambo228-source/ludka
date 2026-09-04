--!strict

local controllersFolder = script.Parent:FindFirstChild("Controllers")
assert(controllersFolder and controllersFolder:IsA("Folder"), "StarterPlayerScripts.Controllers is missing")

local CONTROLLER_NAMES = {
	"HUDController",
	"RunController",
	"RoomController",
	"FarmController",
	"InventoryController",
	"InteractionController",
	"AudioController",
}

for _, controllerName in CONTROLLER_NAMES do
	local controllerModule = controllersFolder:FindFirstChild(controllerName)
	assert(controllerModule and controllerModule:IsA("ModuleScript"), `{controllerName} is missing`)
	require(controllerModule)
end

print(`[BrainrotTower] Client bootstrap loaded {#CONTROLLER_NAMES} controllers`)
