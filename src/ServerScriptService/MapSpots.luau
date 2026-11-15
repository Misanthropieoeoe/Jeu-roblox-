-- MapSpots. Trouve un endroit au hasard sur TOUTE la carte pour faire
-- apparaître un objet (flèches, fruits, argent). Utilisé par StandService et
-- MoneyService.
--
-- On tire un point au hasard dans la carte, on lance un rayon vers le bas et
-- on garde l'endroit seulement s'il est :
--   - au niveau du sol (pas sur un toit : moins de MAX_ABOVE_FLOOR au-dessus)
--   - sur une surface plate, visible et solide
--   - pas trop près d'un autre objet déjà posé
local Workspace = game:GetService("Workspace")

local MapSpots = {}

local MAP_NAME = "OLD A BIZARRE DAY"
local MAX_ABOVE_FLOOR = 6   -- studs au-dessus de la route
local EDGE_MARGIN = 0.06    -- on évite les 6 % du bord de la carte
local MIN_SPACING = 18      -- distance minimale entre deux objets
local TRIES = 60

local map, mapCF, mapSize, floorY
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- La carte est prête quand MapBuilder y a mis son dossier SpawnPads
function MapSpots.Ready()
	if mapCF then return true end
	map = map or Workspace:FindFirstChild(MAP_NAME)
	if not map or not map:FindFirstChild("SpawnPads") then return false end
	mapCF, mapSize = map:GetBoundingBox()
	local organs = map:FindFirstChild("MapOrgans")
	local floorPart = organs and organs:FindFirstChild("Floor")
	floorY = floorPart and floorPart.Position.Y or (mapCF.Position.Y - mapSize.Y / 2)
	rayParams.FilterDescendantsInstances = { map }
	print("[MapSpots] Carte prête :", mapCF.Position, mapSize)
	return true
end

-- Attend la carte (au plus `timeout` secondes)
function MapSpots.WaitReady(timeout)
	local deadline = os.clock() + (timeout or 30)
	while not MapSpots.Ready() and os.clock() < deadline do
		task.wait(0.5)
	end
	return mapCF ~= nil
end

local function farFromOthers(pos, others)
	if not others then return true end
	for _, other in others do
		local p = typeof(other) == "Vector3" and other
			or (typeof(other) == "Instance" and other.Parent and other:IsA("PVInstance") and other:GetPivot().Position)
		if p and (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < MIN_SPACING then
			return false
		end
	end
	return true
end

-- Un point au sol au hasard, ou nil. `others` = positions ou objets à éviter.
function MapSpots.Random(others)
	if not MapSpots.Ready() then return nil end
	local halfX = mapSize.X / 2 * (1 - EDGE_MARGIN)
	local halfZ = mapSize.Z / 2 * (1 - EDGE_MARGIN)
	local top = mapCF.Position.Y + mapSize.Y / 2 + 10
	for _ = 1, TRIES do
		local local_ = Vector3.new((math.random() * 2 - 1) * halfX, 0, (math.random() * 2 - 1) * halfZ)
		local point = mapCF:PointToWorldSpace(local_)
		local hit = Workspace:Raycast(Vector3.new(point.X, top, point.Z), Vector3.new(0, -(mapSize.Y + 40), 0), rayParams)
		if hit and hit.Normal.Y > 0.8 and hit.Position.Y < floorY + MAX_ABOVE_FLOOR
			and hit.Instance.CanCollide and hit.Instance.Transparency < 0.9
			and not hit.Instance:IsA("SpawnLocation")
			and farFromOthers(hit.Position, others) then
			-- de la place au-dessus (pas coincé sous un auvent ou un arbre)
			local clear = Workspace:Raycast(hit.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 6, 0), rayParams)
			if not clear then
				return hit.Position
			end
		end
	end
	return nil
end

return MapSpots
