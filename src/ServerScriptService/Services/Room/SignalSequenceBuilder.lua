--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)

local BuilderUtilModule = script.Parent:FindFirstChild("BuilderUtil")
assert(BuilderUtilModule and BuilderUtilModule:IsA("ModuleScript"), "Room.BuilderUtil is missing")
local BuilderUtil = require(BuilderUtilModule)

local PANEL_COLORS = table.freeze({
	Color3.fromRGB(255, 83, 99),
	Color3.fromRGB(75, 170, 255),
	Color3.fromRGB(91, 235, 141),
	Color3.fromRGB(255, 210, 74),
	Color3.fromRGB(181, 103, 255),
	Color3.fromRGB(255, 139, 61),
	Color3.fromRGB(66, 238, 226),
})

local SignalSequenceBuilder = {}

local function setLabel(part: BasePart, guiName: string, text: string, color: Color3?)
	local gui = part:FindFirstChild(guiName)
	local label = if gui ~= nil then gui:FindFirstChild("Label") else nil
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = text
		label.TextColor3 = color or Color3.new(1, 1, 1)
	end
end

function SignalSequenceBuilder.Create(
	parent: Instance,
	runId: string,
	roomId: string,
	definition: any,
	difficulty: any,
	participantCount: number
): any
	local origin = definition.ArenaOrigin
	local model = Instance.new("Model")
	model.Name = `SignalSequence_{roomId}`
	model:SetAttribute("RunId", runId)
	model:SetAttribute("RoomId", roomId)
	model:SetAttribute("RoomType", definition.Id)
	BuilderUtil.CreateArena(model, definition, Color3.fromRGB(31, 38, 58))

	local objectiveSign = BuilderUtil.CreatePart(model, "ObjectiveSign", Vector3.new(22, 5, 1), CFrame.new(origin + Vector3.new(0, 5, -definition.ArenaSize.Z / 2 + (3 / 5))), Color3.fromRGB(45, 53, 78), Enum.Material.Metal)
	objectiveSign.CanCollide = false
	BuilderUtil.CreateBillboard(objectiveSign, "ObjectiveGui", `SIGNAL SEQUENCE\nMemorize {difficulty.SequenceLength} signals\n{difficulty.TimeLimitSeconds}s`, Vector3.new(0, 0, -(7 / 10)), UDim2.fromOffset(480, 130))

	local sequenceBoard = BuilderUtil.CreatePart(model, "SequenceBoard", Vector3.new(26, 7, 1), CFrame.new(origin + Vector3.new(0, 5, 2)), Color3.fromRGB(19, 23, 35), Enum.Material.SmoothPlastic)
	sequenceBoard.CanCollide = false
	BuilderUtil.CreateBillboard(sequenceBoard, "SequenceGui", "GET READY", Vector3.new(0, 0, -(7 / 10)), UDim2.fromOffset(620, 180))

	local spawnCFrames = {}
	for index = 1, participantCount do
		local x = BuilderUtil.EvenlySpacedX(index, participantCount, 5)
		local pad = BuilderUtil.CreatePart(model, `PlayerSpawn{index}`, Vector3.new(4, (3 / 10), 4), CFrame.new(origin + Vector3.new(x, (4 / 25), definition.StartZ)), Color3.fromRGB(98, 113, 211), Enum.Material.Neon)
		pad.CanCollide = false
		table.insert(spawnCFrames, CFrame.new(origin + Vector3.new(x, 3, definition.StartZ)))
	end

	local panels = {}
	for index = 1, difficulty.PanelCount do
		local panelId = `Signal{index}`
		local x = BuilderUtil.EvenlySpacedX(index, difficulty.PanelCount, definition.PanelSpacing)
		local panel = BuilderUtil.CreatePart(model, panelId, Vector3.new(5, 5, 2), CFrame.new(origin + Vector3.new(x, (5 / 2), definition.PanelZ)), PANEL_COLORS[index], Enum.Material.Neon)
		panel:SetAttribute("PanelId", panelId)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ActivatePrompt"
		prompt.ActionText = "Activate"
		prompt.ObjectText = tostring(index)
		prompt.HoldDuration = definition.ActivationHoldDuration
		prompt.MaxActivationDistance = BalanceConfig.Room.PromptMaxActivationDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = panel
		BuilderUtil.CreateBillboard(panel, "PanelGui", tostring(index), Vector3.new(0, (7 / 2), 0), UDim2.fromOffset(90, 90))
		panels[panelId] = { Id = panelId, Index = index, Part = panel, Prompt = prompt }
	end

	model.Parent = parent
	return { Model = model, ObjectiveSign = objectiveSign, SequenceBoard = sequenceBoard, SpawnCFrames = spawnCFrames, Panels = panels }
end

function SignalSequenceBuilder.ShowSequence(build: any, sequence: { string }, memorizeSeconds: number)
	local display = {}
	for _, panelId in sequence do
		local symbol = string.gsub(panelId, "Signal", "")
		table.insert(display, symbol)
	end
	setLabel(build.SequenceBoard, "SequenceGui", `MEMORIZE ({memorizeSeconds}s)\n{table.concat(display, "  →  ")}`, Color3.fromRGB(255, 231, 122))
end

function SignalSequenceBuilder.BeginInput(build: any)
	for _, panel in build.Panels do
		panel.Prompt.Enabled = true
	end
	setLabel(build.SequenceBoard, "SequenceGui", "REPEAT THE SEQUENCE", Color3.fromRGB(127, 224, 255))
end

function SignalSequenceBuilder.Update(build: any, position: number, required: number, mistakes: number, remaining: number)
	setLabel(build.ObjectiveSign, "ObjectiveGui", `SIGNAL SEQUENCE\nProgress {position} / {required}  •  Mistakes {mistakes}\n{remaining}s`, if remaining <= BalanceConfig.Room.CriticalTimerSeconds then Color3.fromRGB(255, 102, 102) else nil)
end

return table.freeze(SignalSequenceBuilder)
