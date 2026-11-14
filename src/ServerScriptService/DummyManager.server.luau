local workspace = game:GetService("Workspace")

-- Dummies train beside the Arena on the imported OLD A BIZARRE DAY map.
local DUMMY_SPOTS = {}
local importedMap = workspace:FindFirstChild("OLD A BIZARRE DAY") or workspace:WaitForChild("OLD A BIZARRE DAY", 10)
if importedMap then
	importedMap:WaitForChild("SpawnPads", 30) -- MapBuilder creates this last, after placement
	local mapObjects = importedMap:FindFirstChild("MapObjects")
	local arena = mapObjects and mapObjects:FindFirstChild("Arena")
	if arena then
		local apv = arena:GetPivot().Position
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { importedMap }
		-- Only trust collidable surfaces: decorative (CanCollide false) meshes
		-- above the arena made dummies float ~9 studs over the real floor.
		local function groundY(x, z)
			local y = apv.Y + 120
			for _ = 1, 10 do
				local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -400, 0), rayParams)
				if not hit then break end
				if hit.Instance:IsA("BasePart") and hit.Instance.CanCollide then
					return hit.Position.Y
				end
				y = hit.Position.Y - 0.05
			end
			-- Fallback: the town Floor that MapBuilder flushes to Y = 0.
			local organs = importedMap:FindFirstChild("MapOrgans")
			local floorRef = organs and organs:FindFirstChild("Floor")
			if floorRef and floorRef:IsA("BasePart") then
				return floorRef.Position.Y + floorRef.Size.Y / 2
			end
			return 0
		end
		for i = -2, 2 do
			local x, z = apv.X + 30, apv.Z + i * 16
			-- Dummy legs are 3 studs tall below the root, so +3 puts the feet
			-- exactly on the ground (the old +3.5 left them floating).
			table.insert(DUMMY_SPOTS, Vector3.new(x, groundY(x, z) + 3, z))
		end
	else
		warn("[DummyManager] Arena not found on imported map")
	end
else
	warn("[DummyManager] imported map never appeared")
end

local BODY_COLOR = Color3.fromRGB(255, 170, 60)
local HEAD_COLOR = Color3.fromRGB(235, 205, 150)
local LIMB_COLOR = Color3.fromRGB(120, 120, 125)

local function makePart(name, size, color, pos)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = CFrame.new(pos)
	return part
end

local folder = Instance.new("Folder")
folder.Name = "Dummies"
folder.Parent = workspace

local function makeDummy(position)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"
	model:SetAttribute("IsDummy", true)

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), BODY_COLOR, position)
	root.Transparency = 1
	root.Anchored = true

	local torso = makePart("Torso", Vector3.new(2, 2, 1), BODY_COLOR, position)
	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2), HEAD_COLOR, position + Vector3.new(0, 1.6, 0))
	local leftArm = makePart("Left Arm", Vector3.new(1, 2, 1), LIMB_COLOR, position + Vector3.new(-1.5, 0, 0))
	local rightArm = makePart("Right Arm", Vector3.new(1, 2, 1), LIMB_COLOR, position + Vector3.new(1.5, 0, 0))
	local leftLeg = makePart("Left Leg", Vector3.new(1, 2, 1), LIMB_COLOR, position + Vector3.new(-0.5, -2, 0))
	local rightLeg = makePart("Right Leg", Vector3.new(1, 2, 1), LIMB_COLOR, position + Vector3.new(0.5, -2, 0))

	local welds = {}
	for _, part in { torso, head, leftArm, rightArm, leftLeg, rightLeg } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
		table.insert(welds, weld)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 300
	humanoid.Health = 300
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = root
	rootJoint.Part1 = torso
	rootJoint.Parent = root

	head.Parent = model
	torso.Parent = model
	leftArm.Parent = model
	rightArm.Parent = model
	leftLeg.Parent = model
	rightLeg.Parent = model
	root.Parent = model
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = folder
	return model
end

local function spawnDummy(position)
	local dummy = makeDummy(position)
	dummy:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		task.wait(3)
		if dummy.Parent then
			dummy:Destroy()
		end
		spawnDummy(position)
	end)
end

for _, position in DUMMY_SPOTS do
	spawnDummy(position)
end

print("[DummyManager] Spawned", #DUMMY_SPOTS, "dummies")
