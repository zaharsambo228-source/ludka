--!strict

local BuilderUtil = {}

function BuilderUtil.CreatePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function BuilderUtil.CreateBillboard(adornee: BasePart, name: string, text: string, offset: Vector3, size: UDim2)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
end

function BuilderUtil.EvenlySpacedX(index: number, count: number, spacing: number): number
	return (index - (count + 1) / 2) * spacing
end

function BuilderUtil.CreateArena(model: Model, definition: any, floorColor: Color3): Part
	local origin = definition.ArenaOrigin
	local size = definition.ArenaSize
	local floor = BuilderUtil.CreatePart(model, "Floor", size, CFrame.new(origin + Vector3.new(0, -0.5, 0)), floorColor, Enum.Material.Metal)
	model.PrimaryPart = floor
	BuilderUtil.CreatePart(model, "LeftWall", Vector3.new(1, 9, size.Z), CFrame.new(origin + Vector3.new(-size.X / 2, 4.5, 0)), Color3.fromRGB(25, 31, 42), Enum.Material.Metal)
	BuilderUtil.CreatePart(model, "RightWall", Vector3.new(1, 9, size.Z), CFrame.new(origin + Vector3.new(size.X / 2, 4.5, 0)), Color3.fromRGB(25, 31, 42), Enum.Material.Metal)
	BuilderUtil.CreatePart(model, "BackWall", Vector3.new(size.X, 9, 1), CFrame.new(origin + Vector3.new(0, 4.5, -size.Z / 2)), Color3.fromRGB(25, 31, 42), Enum.Material.Metal)
	BuilderUtil.CreatePart(model, "FrontWall", Vector3.new(size.X, 9, 1), CFrame.new(origin + Vector3.new(0, 4.5, size.Z / 2)), Color3.fromRGB(25, 31, 42), Enum.Material.Metal)
	return floor
end

return table.freeze(BuilderUtil)
