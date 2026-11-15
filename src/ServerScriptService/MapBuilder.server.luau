-- MapBuilder: places the imported OLD A BIZARRE DAY town map and its spawn pads.
local Workspace = game:GetService("Workspace")

-- Heure d'ouverture du serveur (le HUD affiche depuis combien de temps il tourne)
if not Workspace:GetAttribute("ServerStartedAt") then
	Workspace:SetAttribute("ServerStartedAt", Workspace:GetServerTimeNow())
end

local oldBase = Workspace:FindFirstChild("Baseplate")
if oldBase then oldBase:Destroy() end
local oldSpawn = Workspace:FindFirstChild("SpawnLocation")
if oldSpawn then oldSpawn:Destroy() end

local importedMap = Workspace:FindFirstChild("OLD A BIZARRE DAY")
if not importedMap then
	importedMap = Workspace:WaitForChild("OLD A BIZARRE DAY", 10)
end
if not importedMap then
	warn("[MapBuilder] OLD A BIZARRE DAY missing from Workspace; cannot build map")
	return
end

-- Anchor everything so the imported map never shifts or collapses
for _, inst in importedMap:GetDescendants() do
	if inst:IsA("BasePart") then
		inst.Anchored = true
	end
end

-- Place: road floor flush with Y=0, town centered on Z=0, western edge at X=520
local mapOrgans = importedMap:FindFirstChild("MapOrgans")
local floorRef = mapOrgans and mapOrgans:FindFirstChild("Floor")
local bboxCF, bboxSize = importedMap:GetBoundingBox()
local minX = bboxCF.Position.X - bboxSize.X / 2
local delta = Vector3.new(
	520 - minX,
	floorRef and (0 - floorRef.Position.Y) or (-bboxCF.Position.Y),
	0 - bboxCF.Position.Z
)
importedMap:PivotTo(importedMap:GetPivot() + delta)
local placedCF, placedSize = importedMap:GetBoundingBox()
print(string.format("[MapBuilder] OLD A BIZARRE DAY placed: center(%.0f, %.0f, %.0f) size(%.0f, %.0f, %.0f)",
	placedCF.Position.X, placedCF.Position.Y, placedCF.Position.Z,
	placedSize.X, placedSize.Y, placedSize.Z))

-- Ground probe: topmost surface of the imported map at a given XZ
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { importedMap }
local topY = placedCF.Position.Y + placedSize.Y / 2
local function groundY(x, z)
	local hit = Workspace:Raycast(Vector3.new(x, topY + 5, z), Vector3.new(0, placedSize.Y + 60, 0), rayParams)
	if hit then return hit.Position.Y end
	return floorRef and floorRef.Position.Y or 0
end

local function landmarkXZ(containerName, childName)
	local container = importedMap:FindFirstChild(containerName)
	local child = container and container:FindFirstChild(childName)
	if child and (child:IsA("Model") or child:IsA("BasePart")) then
		local pv = child:GetPivot().Position
		return pv.X, pv.Z
	end
	warn("[MapBuilder] landmark missing: " .. containerName .. "/" .. childName)
	return nil, nil
end

-- ==================== SPAWN POINTS ====================
local spawnsFolder = Instance.new("Folder")
spawnsFolder.Name = "SpawnPads"
spawnsFolder.Parent = importedMap

local function spawnPad(name, displayName, x, z, color)
	if not x or not z then return end
	local baseY = groundY(x, z)

	local pad = Instance.new("SpawnLocation")
	pad.Name = name
	pad.Size = Vector3.new(10, 0.8, 10)
	pad.CFrame = CFrame.new(x, baseY + 0.4, z)
	pad.Color = color
	pad.Material = Enum.Material.SmoothPlastic
	-- point d'apparition invisible : on apparaît dessus sans le voir
	pad.Transparency = 1
	pad.CanCollide = false
	pad.CanQuery = false
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 5
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = spawnsFolder
	-- le logo blanc qu'un SpawnLocation affiche par défaut
	for _, child in pad:GetChildren() do
		if child:IsA("Decal") then child:Destroy() end
	end
end

local fx, fz = landmarkXZ("MapObjects", "fountain")
local ax, az = landmarkXZ("MapObjects", "Arena")
local rx, rz = landmarkXZ("MapObjects", "roads and park path")
local cx, cz = landmarkXZ("MapObjects", "DioCoffin")

spawnPad("SpawnTownPlaza", "TOWN PLAZA", fx and (fx + 24), fz and (fz + 24), Color3.fromRGB(255, 190, 60))
spawnPad("SpawnArena", "ARENA", ax, az, Color3.fromRGB(210, 85, 85))
spawnPad("SpawnMainStreet", "MAIN STREET", rx and (rx + 60), rz and (rz - 60), Color3.fromRGB(95, 195, 95))
spawnPad("SpawnDioCoffin", "DIO'S COFFIN", cx and (cx + 14), cz and (cz + 14), Color3.fromRGB(150, 70, 220))

print("[MapBuilder] Spawn pads placed on OLD A BIZARRE DAY")
