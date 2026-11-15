local GripUtil = {}

local FORWARD = Vector3.new(0, 0, -1)
local UP = Vector3.new(0, 1, 0)

local POSES = {
	pointForward = { primaryTarget = FORWARD, secondaryTarget = UP },
	shaftUp = { primaryTarget = UP, secondaryTarget = FORWARD },
}

GripUtil.Categories = {
	sword = { pose = "pointForward", grabAlpha = 0.1 },
	gun = { pose = "pointForward", grabAlpha = 0.35 },
	rod = { pose = "pointForward", grabAlpha = 0.05 },
	pickaxe = { pose = "shaftUp", grabAlpha = 0.3 },
	axe = { pose = "shaftUp", grabAlpha = 0.3 },
}

local function visualSize(part)
	local size = part.Size
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		size = size * mesh.Scale
	end
	return size
end

local function assemblyBounds(handle)
	local bmin = Vector3.new(math.huge, math.huge, math.huge)
	local bmax = -bmin
	local extras = {}
	local parts = { handle }
	local tool = handle.Parent
	if tool and (tool:IsA("Tool") or tool:IsA("Model")) then
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") and d ~= handle then
				table.insert(parts, d)
			end
		end
	end
	for _, part in parts do
		local rel = handle.CFrame:ToObjectSpace(part.CFrame)
		local hs = visualSize(part) / 2
		local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
		local ext = Vector3.new(
			math.abs(r.X) * hs.X + math.abs(u.X) * hs.Y + math.abs(l.X) * hs.Z,
			math.abs(r.Y) * hs.X + math.abs(u.Y) * hs.Y + math.abs(l.Y) * hs.Z,
			math.abs(r.Z) * hs.X + math.abs(u.Z) * hs.Y + math.abs(l.Z) * hs.Z
		)
		bmin = bmin:Min(rel.Position - ext)
		bmax = bmax:Max(rel.Position + ext)
		if part ~= handle then
			local v = visualSize(part)
			table.insert(extras, { pos = rel.Position, volume = v.X * v.Y * v.Z })
		end
	end
	return bmin, bmax, extras
end

local SIGN_THRESHOLD = 0.15

function GripUtil.measure(handle)
	local bmin, bmax, extras = assemblyBounds(handle)
	local span = bmax - bmin
	local axes = {
		{ v = Vector3.xAxis, len = span.X },
		{ v = Vector3.yAxis, len = span.Y },
		{ v = Vector3.zAxis, len = span.Z },
	}
	table.sort(axes, function(a, b)
		return a.len > b.len
	end)

	local headOffset = Vector3.zero
	local totalVolume = 0
	for _, e in extras do
		headOffset += e.pos * e.volume
		totalVolume += e.volume
	end
	if totalVolume > 0 then
		headOffset = headOffset / totalVolume
	end

	local primary = axes[1].v
	local pDot = headOffset:Dot(primary)
	if math.abs(pDot) > SIGN_THRESHOLD then
		primary = primary * math.sign(pDot)
	end
	local secondary = axes[2].v
	local sDot = headOffset:Dot(secondary)
	if math.abs(sDot) > SIGN_THRESHOLD then
		secondary = secondary * math.sign(sDot)
	end
	return {
		primary = primary,
		secondary = secondary,
		bmin = bmin,
		bmax = bmax,
		span = span,
	}
end

local function grabPosition(info, alpha)
	local p = info.primary
	local k = math.abs(p.X) > 0.5 and "X" or (math.abs(p.Y) > 0.5 and "Y" or "Z")
	local axisUnit = Vector3.new(k == "X" and 1 or 0, k == "Y" and 1 or 0, k == "Z" and 1 or 0)
	local sign = p:Dot(axisUnit)
	local coord
	if sign > 0 then
		coord = info.bmin[k] + alpha * info.span[k]
	else
		coord = info.bmax[k] - alpha * info.span[k]
	end
	return axisUnit * coord
end

local function carryRotation(primary, secondary, t1, t2)
	local a = CFrame.fromMatrix(Vector3.zero, primary, secondary, primary:Cross(secondary))
	local b = CFrame.fromMatrix(Vector3.zero, t1, t2, t1:Cross(t2))
	return a * b:Inverse()
end

function GripUtil.buildGrip(handle, categoryName, flipPrimary)
	local category = GripUtil.Categories[categoryName]
	if not category then
		error("GripUtil: unknown category " .. tostring(categoryName))
	end
	if not (handle and handle:IsA("BasePart")) then
		error("GripUtil: handle must be a BasePart")
	end
	local pose = POSES[category.pose]
	local info = GripUtil.measure(handle)
	if flipPrimary then
		info.primary = -info.primary
	end
	local rotation = carryRotation(info.primary, info.secondary, pose.primaryTarget, pose.secondaryTarget)
	local grip = CFrame.new(grabPosition(info, category.grabAlpha)) * rotation
	return grip, info
end

return GripUtil
