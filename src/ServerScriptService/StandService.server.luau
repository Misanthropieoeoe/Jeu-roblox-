local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))

-- Verified anime barrage SFX: full ORA ORA ORA voice clip sourced from the
-- community asset "Star Platinum The World (with new sound)" (100% upvoted).
local BARRAGE_VOICE_ID = "rbxassetid://2404992475"

-- STAR PLATINUM / VISUAL UPGRADE V2
-- Non-destructive ornamental armor: all original MeshParts, joints and animations stay intact.
-- Applied to ReplicatedStorage.StarPlatinumTemplate before any player receives a clone.
local function upgradeStarPlatinumModel(template)
	if template:GetAttribute("StarPlatinumVisualV2") then return end
	local torso = template:FindFirstChild("Torso")
	local head = template:FindFirstChild("Head")
	local leftArm = template:FindFirstChild("Left Arm")
	local rightArm = template:FindFirstChild("Right Arm")
	local leftLeg = template:FindFirstChild("Left Leg")
	local rightLeg = template:FindFirstChild("Right Leg")
	if not (torso and head and leftArm and rightArm and leftLeg and rightLeg) then
		warn("[StarPlatinumV2] R6 body parts missing; original model retained")
		return
	end

	local PLUM = Color3.fromRGB(74, 32, 116)
	local PURPLE = Color3.fromRGB(121, 65, 190)
	local LAVENDER = Color3.fromRGB(186, 122, 255)
	local GOLD = Color3.fromRGB(242, 181, 75)
	local GOLD_LIGHT = Color3.fromRGB(255, 224, 146)
	local GEM = Color3.fromRGB(255, 95, 205)
	local BLACK = Color3.fromRGB(34, 21, 52)

	local function armor(host, name, size, offset, color, material, shape)
		local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
		p.Name = "SPV2_" .. name
		p.Size = size
		p.Material = material or Enum.Material.Metal
		p.Color = color
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Massless = true
		p.Anchored = false
		if shape == "Ball" then p.Shape = Enum.PartType.Ball end
		if shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
		p.CFrame = host.CFrame * offset
		p.Parent = host
		local weld = Instance.new("WeldConstraint")
		weld.Name = "SPV2_Weld"
		weld.Part0 = host
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local function inset(host, name, a, b, width, color, material)
		local delta = b - a
		if delta.Magnitude < 0.02 then return end
		local mid = (a + b) * 0.5
		return armor(host, name, Vector3.new(width, width, delta.Magnitude),
			CFrame.lookAt(mid, b), color, material)
	end

	-- Regal breastplate: twin gold piping, a dark-purple chest inset, and a luminous gem.
	local chestFront = -torso.Size.Z * 0.5 - 0.11
	armor(torso, "ChestPlate", Vector3.new(1.28, 0.66, 0.13),
		CFrame.new(0, 0.24, chestFront), PLUM)
	armor(torso, "ChestPlateInner", Vector3.new(1.08, 0.43, 0.09),
		CFrame.new(0, 0.22, chestFront - 0.095), PURPLE)
	inset(torso, "ChestVLeft", Vector3.new(-0.66, 0.55, chestFront-0.17),
		Vector3.new(0, -0.02, chestFront-0.17), 0.09, GOLD)
	inset(torso, "ChestVRight", Vector3.new(0.66, 0.55, chestFront-0.17),
		Vector3.new(0, -0.02, chestFront-0.17), 0.09, GOLD)
	armor(torso, "ChestStar", Vector3.new(0.40, 0.40, 0.19),
		CFrame.new(0, 0.10, chestFront - 0.24), GOLD_LIGHT, Enum.Material.Neon, "Ball")
	armor(torso, "ChestGem", Vector3.new(0.23, 0.23, 0.19),
		CFrame.new(0, 0.10, chestFront - 0.38), GEM, Enum.Material.Neon, "Ball")

	-- Sculpted high collar and layered imperial belt.
	armor(torso, "Collar", Vector3.new(1.32, 0.19, 0.22),
		CFrame.new(0, torso.Size.Y*0.42, chestFront+0.06), GOLD)
	armor(torso, "Belt", Vector3.new(1.75, 0.19, 1.14),
		CFrame.new(0, -torso.Size.Y*0.40, 0), PLUM)
	armor(torso, "BeltEdge", Vector3.new(1.83, 0.10, 1.19),
		CFrame.new(0, -torso.Size.Y*0.47, 0), GOLD)
	armor(torso, "BeltBuckle", Vector3.new(0.46, 0.33, 0.18),
		CFrame.new(0, -torso.Size.Y*0.41, chestFront-0.14), GOLD)
	armor(torso, "BeltJewel", Vector3.new(0.24, 0.24, 0.12),
		CFrame.new(0, -torso.Size.Y*0.41, chestFront-0.27), GEM, Enum.Material.Neon, "Ball")

	-- Greaves, pauldrons and glowing bracers remain welded to the original R6 limbs.
	for _, entry in ipairs({ {arm=leftArm, side=-1}, {arm=rightArm, side=1} }) do
		local arm, side = entry.arm, entry.side
		local width, height, depth = arm.Size.X, arm.Size.Y, arm.Size.Z
		armor(arm, "Pauldron" .. side, Vector3.new(width*1.06, height*0.22, depth*1.04),
			CFrame.new(side * 0.025, height*0.385, -0.025), PLUM)
		armor(arm, "PauldronRim" .. side, Vector3.new(width*1.10, 0.075, depth*1.08),
			CFrame.new(side * 0.025, height*0.485, -0.025), GOLD)
		armor(arm, "ShoulderGem" .. side, Vector3.new(0.24, 0.14, 0.20),
			CFrame.new(0, height*0.49, -depth*0.29), GEM, Enum.Material.Neon, "Ball")
		armor(arm, "Bracer" .. side, Vector3.new(width*1.04, height*0.33, depth*1.07),
			CFrame.new(0, -height*0.26, 0), PURPLE)
		armor(arm, "BracerRim" .. side, Vector3.new(width*1.11, 0.095, depth*1.10),
			CFrame.new(0, -height*0.12, 0), GOLD)
		armor(arm, "FistTrim" .. side, Vector3.new(width*1.12, 0.11, depth*1.11),
			CFrame.new(0, -height*0.48, 0), GOLD)
		armor(arm, "KnuckleGem" .. side, Vector3.new(0.30, 0.16, 0.18),
			CFrame.new(0, -height*0.38, -depth*0.57), GOLD_LIGHT, Enum.Material.Neon, "Ball")
	end

	for _, entry in ipairs({ {leg=leftLeg, side=-1}, {leg=rightLeg, side=1} }) do
		local leg, side = entry.leg, entry.side
		local w,h,d=leg.Size.X,leg.Size.Y,leg.Size.Z
		armor(leg, "ShinPlate" .. side, Vector3.new(w*0.75, h*0.36, 0.16),
			CFrame.new(0, -h*0.15, -d*0.52), PURPLE)
		armor(leg, "KneeTrim" .. side, Vector3.new(w*1.07, 0.17, d*1.05),
			CFrame.new(0, h*0.25, 0), GOLD)
		armor(leg, "KneeGem" .. side, Vector3.new(0.26, 0.20, 0.18),
			CFrame.new(0, h*0.25, -d*0.63), GEM, Enum.Material.Neon, "Ball")
		armor(leg, "BootCuff" .. side, Vector3.new(w*1.06, 0.14, d*1.06),
			CFrame.new(0, -h*0.43, 0), GOLD)
	end

	-- Forehead circlet and layered crown accents (preserving the imported face/hair mesh).
	local forehead = -head.Size.Z*0.52
	armor(head, "Diadem", Vector3.new(head.Size.X*0.67, 0.12, 0.15),
		CFrame.new(0, head.Size.Y*0.31, forehead), GOLD)
	armor(head, "DiademGem", Vector3.new(0.20, 0.25, 0.13),
		CFrame.new(0, head.Size.Y*0.32, forehead-0.09), GOLD_LIGHT, Enum.Material.Neon, "Ball")
	for _, side in ipairs({-1, 1}) do
		armor(head, "CrownFin" .. side, Vector3.new(0.17, 0.38, 0.22),
			CFrame.new(side*head.Size.X*0.25, head.Size.Y*0.54, -0.06)
			* CFrame.Angles(0, 0, -side*0.30), PURPLE, Enum.Material.Metal, "Wedge")
	end

	-- Very subtle core glow; particles stay in the existing aura system.
	local gem = torso:FindFirstChild("SPV2_ChestGem")
	if gem then
		local light = Instance.new("PointLight")
		light.Name = "SPV2_HeartGlow"
		light.Color = LAVENDER
		light.Range = 6
		light.Brightness = 0.55
		light.Parent = gem
	end

	template:SetAttribute("StarPlatinumVisualV2", true)
	print("[StarPlatinumV2] Decorative 3D armor added to", template.Name)
end


-- STAR PLATINUM V14: articulated elbows, visible upper arms and folded forearms.
-- Runs once on the original template, BEFORE it is cloned for players.
-- Actual Motor6D joints connect both forearms to the invisible R6 upper-arm hosts.
-- The original detailed 3D meshes are reused; combat remotes and damage are unchanged.
local function installStarPlatinumElbows(template)
    if template:GetAttribute("SPV13_ElbowsInstalled") then return end
    local detail = template:FindFirstChild("Detail")
    if not detail then
        warn("[SPV13] Missing Stand Detail, elbow conversion skipped")
        return
    end

    local PURPLE = Color3.fromRGB(125, 77, 182)
    local DARK = Color3.fromRGB(69, 42, 111)
    local LAVENDER = Color3.fromRGB(172, 115, 225)
    local GOLD = Color3.fromRGB(237, 188, 89)

    local function weldPiece(host, piece)
        piece.Anchored = false
        piece.Massless = true
        piece.CanCollide = false
        piece.CanTouch = false
        piece.CanQuery = false
        local weld = Instance.new("WeldConstraint")
        weld.Name = "SPV13_SegmentWeld"
        weld.Part0 = host
        weld.Part1 = piece
        weld.Parent = piece
        return piece
    end

    local function ornament(host, name, size, localCF, color, material, shape)
        local p = Instance.new("Part")
        p.Name = "SPV13_" .. name
        p.Size = size
        p.Material = material or Enum.Material.SmoothPlastic
        p.Color = color
        p.CastShadow = false
        p.Shape = shape or Enum.PartType.Block
        p.CFrame = host.CFrame * localCF
        p.Parent = host.Parent
        return weldPiece(host, p)
    end

    local function duplicateSkin(source, host, label, yOffset, sizeScale, originalArm)
        if not source or not source:IsA("MeshPart") then return false end
        local piece = source:Clone()
        for _, obj in piece:GetDescendants() do
            if obj:IsA("JointInstance") or obj:IsA("WeldConstraint") then
                obj:Destroy()
            end
        end
        piece.Name = "SPV13_" .. label
        piece.Size = Vector3.new(source.Size.X, math.max(source.Size.Y * sizeScale, 0.16), source.Size.Z)
        piece.Transparency = 0
        -- V20: une peau doit etre CENTREE sur son segment articule.
        -- Avant la correction, les copies de MeshPart restaient placees au-dessus
        -- du pivot et donnaient l'impression de bras rigides ou disloques.
        local relRot = originalArm.CFrame:ToObjectSpace(source.CFrame).Rotation
        piece.CFrame = host.CFrame * CFrame.new(0, yOffset, 0) * relRot
        piece.Parent = host.Parent
        weldPiece(host, piece)
        return true
    end

    for _, info in ipairs({
        {name = "Right Arm", detail = "RightArm", mesh = "RArm", short = "Right", side = 1},
        {name = "Left Arm", detail = "LeftArm", mesh = "LArm", short = "Left", side = -1},
    }) do
        local arm = template:FindFirstChild(info.name)
        local detailGroup = detail:FindFirstChild(info.detail)
        if not arm or not detailGroup then
            warn("[SPV13] Cannot rig missing arm: " .. info.name)
            continue
        end

        local oldSkin = detailGroup:FindFirstChild(info.mesh)
        local height = arm.Size.Y
        local width = arm.Size.X
        local depth = arm.Size.Z

        -- Keep existing R6 shoulder connection to preserve all earlier clips.
        -- The original R6 part becomes the invisible upper-arm rotation host.
        local forearm = Instance.new("Part")
        forearm.Name = info.short .. " Forearm"
        forearm.Size = Vector3.new(width * 0.93, height * 0.51, depth * 0.95)
        forearm.Transparency = 1
        forearm.Anchored = false
        forearm.Massless = true
        forearm.CanCollide = false
        forearm.CanTouch = false
        forearm.CanQuery = false
        forearm.CastShadow = false
        forearm.Parent = template

        local elbow = Instance.new("Motor6D")
        elbow.Name = info.short .. " Elbow"
        elbow.Part0 = arm
        elbow.Part1 = forearm
        -- V20: placer physiquement le coude au bas du bras superieur,
        -- et non pres du milieu de la piece R6 (sinon segment superieur trop court).
        elbow.C0 = CFrame.new(0, -height * 0.235, 0)
        elbow.C1 = CFrame.new(0, height * 0.255, 0)
        forearm.CFrame = arm.CFrame * elbow.C0 * elbow.C1:Inverse()
        elbow.Parent = arm

        -- V23: IMPORTANT: ne plus cloner le MeshPart "RArm"/"LArm" entier
        -- pour creer deux segments. Une copie ecrasee en Y dessine encore
        -- un BRAS COMPLET sur chaque segment, masquant visuellement le coude.
        -- Le vrai maillage d'origine est conserve (mais cache) pour une restauration.
        if oldSkin and oldSkin:IsA("MeshPart") then
            oldSkin.Transparency = 1
        end
        -- Chaque segment a sa geometrie propre, attachee a son Motor6D.
        ornament(arm, info.short .. " UpperArm Skin",
            Vector3.new(width * 0.72, height * 0.42, depth * 0.75),
            CFrame.new(0, height * 0.015, 0), PURPLE)
        ornament(arm, info.short .. " BicepGoldStripe",
            Vector3.new(width * 0.78, 0.07, depth * 0.79),
            CFrame.new(0, -height * 0.175, 0), GOLD, Enum.Material.Metal)
        ornament(forearm, info.short .. " Forearm Skin",
            Vector3.new(width * 0.76, forearm.Size.Y * 0.90, depth * 0.78),
            CFrame.identity, LAVENDER)
        ornament(forearm, info.short .. " ForearmBackPlate",
            Vector3.new(width * 0.68, forearm.Size.Y * 0.62, 0.12),
            CFrame.new(0, -forearm.Size.Y * 0.07, depth * 0.46), DARK)
        ornament(forearm, info.short .. " ForearmGoldLine",
            Vector3.new(0.10, forearm.Size.Y * 0.70, 0.09),
            CFrame.new(0, -forearm.Size.Y * 0.08, -depth * 0.49), GOLD,
            Enum.Material.Metal)

        -- Seam at elbow and a small rounded joint cover, visible while bending.
        ornament(arm, info.short .. " UpperElbowCuff",
            Vector3.new(width * 1.05, 0.11, depth * 1.07),
            CFrame.new(0, -height * 0.235, 0), GOLD)
        ornament(forearm, info.short .. " ElbowBall",
            Vector3.new(width * 0.71, width * 0.71, depth * 0.73),
            CFrame.new(0, forearm.Size.Y * 0.49, 0), DARK,
            Enum.Material.SmoothPlastic, Enum.PartType.Ball)
        ornament(forearm, info.short .. " WristGuard",
            Vector3.new(width * 0.93, 0.12, depth * 0.97),
            CFrame.new(0, -forearm.Size.Y * 0.38, 0), GOLD,
            Enum.Material.Metal)
        ornament(forearm, info.short .. " WristViolet",
            Vector3.new(width * 0.88, 0.20, depth * 0.94),
            CFrame.new(0, -forearm.Size.Y * 0.22, 0), PURPLE,
            Enum.Material.SmoothPlastic)
        ornament(forearm, info.short .. " Knuckles",
            Vector3.new(width * 0.84, 0.21, depth * 0.89),
            CFrame.new(0, -forearm.Size.Y * 0.48, -depth * 0.045), LAVENDER,
            Enum.Material.SmoothPlastic)
        ornament(forearm, info.short .. " KnuckleGold",
            Vector3.new(width * 0.82, 0.085, depth * 0.94),
            CFrame.new(0, -forearm.Size.Y * 0.55, -depth * 0.08), GOLD,
            Enum.Material.Metal)

        -- Reattach the original lower-arm ornaments, not just the new shapes.
        -- Preserve their initial world alignment using the Weld C0/C1 equation.
        local originalLower = {}
        for _, p in detailGroup:GetDescendants() do
            if p:IsA("MeshPart") and p ~= oldSkin and not p.Name:match("^SPV13_") then
                local localPos = arm.CFrame:PointToObjectSpace(p.Position)
                -- V18: this imported model's forearm plating is 1.65-1.72
                -- studs tall, with centres at Y=-0.07/-0.14 relative to Arm.
                -- The previous < -0.18 filter selected neither mesh: the
                -- gauntlets remained on the rigid upper arm despite the elbow.
                if localPos.Y < height * 0.05 and p.Size.Y < height * 0.95 then
                    table.insert(originalLower, p)
                end
            end
        end
        for _, p in originalLower do
            -- Old full-height gauntlets are incompatible with bent elbow visuals.
            -- Preserve the imported MeshPart for restoration, but render our
            -- segmented mesh/armour instead. The old Weld remains safe.
            p.Transparency = 1
            -- Shorten original giant single-piece gauntlets to fit the new
            -- forearm (the upper-arm skin and shoulder armour stay on Arm).
            -- Keep the imported mesh, texture and gold/purple detailing.
            local localCF = arm.CFrame:ToObjectSpace(p.CFrame)
            p.Size = Vector3.new(p.Size.X, math.max(0.22, p.Size.Y * 0.58), p.Size.Z)
            -- V20: retarget the gauntlet to the actual forearm centre rather
            -- than preserving the old world-space position around the upper arm.
            p.CFrame = forearm.CFrame
                * CFrame.new(localCF.X * 0.65, 0, localCF.Z * 0.65)
                * localCF.Rotation
            local attached = false
            for _, joint in template:GetDescendants() do
                if joint:IsA("Weld") then
                    -- Preserve the joint equation and current world alignment.
                    if joint.Part0 == arm and joint.Part1 == p then
                        joint.C0 = forearm.CFrame:ToObjectSpace(p.CFrame) * joint.C1
                        joint.Part0 = forearm
                        attached = true
                    elseif joint.Part1 == arm and joint.Part0 == p then
                        joint.C1 = forearm.CFrame:ToObjectSpace(p.CFrame * joint.C0)
                        joint.Part1 = forearm
                        attached = true
                    end
                elseif joint:IsA("WeldConstraint") and
                    ((joint.Part0 == arm and joint.Part1 == p) or
                     (joint.Part1 == arm and joint.Part0 == p)) then
                    local worldCFrame = p.CFrame
                    joint:Destroy()
                    p.CFrame = worldCFrame
                    weldPiece(forearm, p)
                    attached = true
                end
            end
            if not attached then
                weldPiece(forearm, p)
            end
        end
        print("[SPV20] Pieces d'avant-bras rattachees au coude", info.short, #originalLower)

        -- V2 bracers previously followed the entire upper arm. Move them to
        -- the forearm so they really move when the elbow bends.
        local toMove = {}
        for _, child in arm:GetChildren() do
            if child:IsA("BasePart") and child.Name:match("^SPV2_") then
                if child.Name:find("Bracer") or child.Name:find("Fist") or child.Name:find("Knuckle") then
                    table.insert(toMove, child)
                end
            end
        end
        for _, p in toMove do
            local localCF = arm.CFrame:ToObjectSpace(p.CFrame)
            for _, joint in p:GetChildren() do
                if joint:IsA("WeldConstraint") and joint.Part0 == arm then
                    joint:Destroy()
                end
            end
            p.CFrame = forearm.CFrame
                * CFrame.new(localCF.X * 0.70, -forearm.Size.Y * 0.06, localCF.Z * 0.70)
                * localCF.Rotation
            p.Size = Vector3.new(p.Size.X * 0.94, p.Size.Y * 0.69, p.Size.Z * 0.94)
            weldPiece(forearm, p)
        end

        arm.Transparency = 1
        print("[SPV20] Coude correctement place", info.short)
    end
    template:SetAttribute("SPV13_ElbowsInstalled", true)
end


local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local standAction = Instance.new("RemoteEvent")
standAction.Name = "StandAction"
standAction.Parent = remotes
local standFX = Instance.new("RemoteEvent")
standFX.Name = "StandFX"
standFX.Parent = remotes

local ServerStorage = game:GetService("ServerStorage")

local DEFAULT_STAND_ID = "StarPlatinum"
local lastUse = {}
local activeBarrages = {}
-- Combo M1 : coup 1 = main droite, 2 = gauche, 3 = droite, et le dernier
-- (ComboLength dans StandData, 4 par défaut) = coup puissant qui repousse.
-- Après une pause plus longue que M1_COMBO_RESET (en secondes), le combo
-- repart de zéro.
local M1_COMBO_RESET = 1.0
-- Temps pendant lequel le Stand reste en garde après la fin d'un coup avant
-- de repasser en pose d'attente (pour enchaîner le combo sans à-coup).
local M1_HOLD_AFTER = 0.2
local m1Combo = {} -- [UserId] = nombre de coups déjà donnés dans le combo
local m1BlockedUntil = {} -- [UserId] = os.clock() avant lequel M1 est bloqué

-- Voice clips live in ServerStorage (server-only). Mirror the ones referenced
-- by stand definitions into ReplicatedStorage so clients can resolve their
-- SoundIds for summon shouts and other client-side playback.
local voiceFolder = nil
local function resolveVoice(path)
	if type(path) ~= "table" or #path < 2 then return nil end
	if not voiceFolder then
		voiceFolder = ReplicatedStorage:FindFirstChild("StandVoices")
		if not voiceFolder then
			voiceFolder = Instance.new("Folder")
			voiceFolder.Name = "StandVoices"
			voiceFolder.Parent = ReplicatedStorage
		end
	end
	local pack = ServerStorage:FindFirstChild("JoJo SoundPack")
	local source = pack and pack:FindFirstChild("JoJoSFX")
	for _, segment in ipairs(path) do
		source = source and source:FindFirstChild(segment)
	end
	if not (source and source:IsA("Sound")) then
		warn("[StandService] Voice clip not found:", table.concat(path, "/"))
		return nil
	end
	local standFolder = voiceFolder:FindFirstChild(path[1])
	if not standFolder then
		standFolder = Instance.new("Folder")
		standFolder.Name = path[1]
		standFolder.Parent = voiceFolder
	end
	local clipName = path[#path]
	local existing = standFolder:FindFirstChild(clipName)
	if not existing then
		existing = source:Clone()
		existing.Parent = standFolder
	end
	return existing
end

-- StandController resolves summon shouts from StandVoices/<StandId>/Summon:
-- mirror every stand's SummonVoicePath under its stand id so clients can play
-- the reveal cry (King Crimson's epitaph cry, The World's roar, ...).
-- TimeStopVoicePath (optional) is mirrored the same way as "TimeStop" for
-- stands that ship a recorded time-stop cry instead of the TTS fallback.
for standId, standDef in pairs(StandData.Stands) do
	local mirrorJobs = {
		{ clipName = "Summon", path = standDef.SummonVoicePath },
		{ clipName = "TimeStop", path = standDef.TimeStopVoicePath },
	}
	for _, job in ipairs(mirrorJobs) do
		local voice = resolveVoice(job.path)
		if voice then
			local standFolder = voiceFolder:FindFirstChild(standId)
			if not standFolder then
				standFolder = Instance.new("Folder")
				standFolder.Name = standId
				standFolder.Parent = voiceFolder
			end
			if not standFolder:FindFirstChild(job.clipName) then
				local clone = voice:Clone()
				clone.Name = job.clipName
				clone.Parent = standFolder
			end
		end
	end
end

-- Per-stand recoloring. The shared Star Platinum rig carries fixed purple/gold
-- armor (SPV2_/SPV13_ parts) and a purple body; each stand's Theme maps the
-- legacy palette roles onto its own colors right after cloning.
local LEGACY_ROLES = {
	["74,32,116"] = "Primary",    -- SPV2 plum plate
	["121,65,190"] = "Secondary", -- SPV2 purple plate
	["186,122,255"] = "Skin",     -- SPV2 lavender skin
	["242,181,75"] = "Trim",      -- SPV2 gold trim
	["255,224,146"] = "TrimLight",
	["255,95,205"] = "Gem",       -- SPV2 pink gem
	["125,77,182"] = "Secondary", -- SPV13 purple
	["172,115,225"] = "Skin",     -- SPV13 lavender
	["237,188,89"] = "Trim",      -- SPV13 gold
	["69,42,111"] = "Dark",       -- SPV13 dark joints
}

local function colorKey(color)
	return string.format("%d,%d,%d", color.R * 255 + 0.5, color.G * 255 + 0.5, color.B * 255 + 0.5)
end

local function applyStandTheme(standModel, stand)
	local theme = stand.Theme
	if not theme then return end
	-- Templates imported with their own finished look (TheWorldTemplate) set
	-- NativeColors: keep their colors, apply only aura/shout/voice FX below.
	if not standModel:GetAttribute("NativeColors") then
		local roleByColor = {}
		for key, role in pairs(LEGACY_ROLES) do
			roleByColor[key] = role
		end
		for _, part in standModel:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				local name = part.Name
				if name:match("^SPV2_") or name:match("^SPV13_") then
					local role = roleByColor[colorKey(part.Color)]
					if role and theme[role] then
						part.Color = theme[role]
					end
				else
					-- Body meshes: gold-ish pieces keep the trim color, everything
					-- else tints to the stand's body color.
					local r, g, b = part.Color.R, part.Color.G, part.Color.B
					local role = (r > b * 1.3 and r >= g) and "Trim" or "Body"
					if theme[role] then
						part.Color = theme[role]
					end
				end
			end
		end
	end

	local torso = standModel:FindFirstChild("Torso") or standModel:FindFirstChild("UpperTorso")
	if torso then
		local aura = torso:FindFirstChild("StandAura")
		if aura then
			aura.Color = ColorSequence.new(theme.Aura1, theme.Aura2)
		end
		local glow = torso:FindFirstChild("StandGlow")
		if glow then
			glow.Color = theme.Aura1
		end
		local heartGlow = torso:FindFirstChild("SPV2_HeartGlow", true)
		if heartGlow then
			heartGlow.Color = theme.Gem
		end
		local shoutGui = torso:FindFirstChild("Shout")
		local shoutLabel = shoutGui and shoutGui:FindFirstChild("Text")
		if shoutLabel then
			shoutLabel.Text = stand.ShoutText or "ORA!"
			shoutLabel.TextColor3 = theme.TrimLight or Color3.fromRGB(255, 230, 120)
		end
	end

	local highlight = standModel:FindFirstChild("StandHighlight", true)
	if highlight then
		highlight.OutlineColor = theme.Outline
	end

	local shoutSound = standModel:FindFirstChild("OraShout", true)
	if shoutSound then
		local voice = resolveVoice(stand.BarrageVoicePath)
		if voice then
			shoutSound.SoundId = voice.SoundId
		else
			shoutSound:Destroy()
		end
	end
end

-- ==================== STANDS SANS HITBOX ====================
-- Les Stands ne doivent bloquer personne. CanCollide = false ne suffit pas :
-- un modèle avec un Humanoid voit Roblox réactiver les collisions de son
-- torse / sa tête. Le groupe de collision "Stands" ne touche rien du tout.
local PhysicsService = game:GetService("PhysicsService")
local STAND_COLLISION_GROUP = "Stands"
pcall(function()
	PhysicsService:RegisterCollisionGroup(STAND_COLLISION_GROUP)
end)
for _, group in PhysicsService:GetRegisteredCollisionGroups() do
	PhysicsService:CollisionGroupSetCollidable(STAND_COLLISION_GROUP, group.name, false)
end

local function makeGhostPart(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = STAND_COLLISION_GROUP
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end
end

local function makeStandIntangible(model)
	for _, part in model:GetDescendants() do
		makeGhostPart(part)
	end
	-- Pièces ajoutées plus tard (effets, armes…)
	model.DescendantAdded:Connect(makeGhostPart)
end

local function setupTemplate(template)
	local primary = template.PrimaryPart or template:FindFirstChild("HumanoidRootPart")
	if primary then
		template.PrimaryPart = primary
	end
	for _, part in template:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = (part.Name == "HumanoidRootPart")
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	-- The new display-style template ships its Head without any joint to the
	-- Torso; pin it with a Neck Motor6D (once, persisted via attribute).
	local head = template:FindFirstChild("Head")
	local neckHost = template:FindFirstChild("Torso")
	if neckHost and head and not template:GetAttribute("SPNeckPinned")
		and not neckHost:FindFirstChild("Neck") then
		local neck = Instance.new("Motor6D")
		neck.Name = "Neck"
		neck.Part0 = neckHost
		neck.Part1 = head
		neck.C0 = neckHost.CFrame:ToObjectSpace(head.CFrame)
		neck.C1 = CFrame.identity
		neck.Parent = neckHost
	end
	template:SetAttribute("SPNeckPinned", true)

	local torso = template:FindFirstChild("Torso") or template:FindFirstChild("UpperTorso")
	if torso then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "StandAura"
		aura.Color = ColorSequence.new(Color3.fromRGB(170, 120, 255), Color3.fromRGB(90, 60, 180))
		aura.Rate = 18
		aura.Lifetime = NumberRange.new(0.7, 1.3)
		aura.Speed = NumberRange.new(1, 2.5)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new(0.4)
		aura.Transparency = NumberSequence.new(0.25, 1)
		aura.LightEmission = 1
		aura.Rotation = NumberRange.new(0, 360)
		aura.RotSpeed = NumberRange.new(-90, 90)
		aura.Parent = torso

		local light = Instance.new("PointLight")
		light.Name = "StandGlow"
		light.Color = Color3.fromRGB(170, 120, 255)
		light.Brightness = 1.2
		light.Range = 12
		light.Parent = torso

		local punchId = "rbxasset://sounds/swordslash.wav"
		local hitSound = Instance.new("Sound")
		hitSound.Name = "BarrageHit"
		hitSound.SoundId = punchId
		hitSound.Volume = 0.55
		hitSound.RollOffMaxDistance = 90
		hitSound.Parent = torso

		-- Second voice so consecutive rapid hits overlap instead of cutting.
		local hitAlt = Instance.new("Sound")
		hitAlt.Name = "BarrageHitAlt"
		hitAlt.SoundId = punchId
		hitAlt.Volume = 0.5
		hitAlt.RollOffMaxDistance = 90
		hitAlt.Parent = torso

		-- ORA ORA ORA: the verified anime barrage voice clip, played looped.
		local oraShout = Instance.new("Sound")
		oraShout.Name = "OraShout"
		oraShout.SoundId = BARRAGE_VOICE_ID
		oraShout.Volume = 1.4
		oraShout.RollOffMaxDistance = 120
		oraShout.Parent = torso
	end

	for _, armName in { "Left Arm", "Right Arm", "LeftUpperArm", "RightUpperArm" } do
		local arm = template:FindFirstChild(armName)
		if arm then
			local trail = Instance.new("ParticleEmitter")
			trail.Name = "PunchTrail"
			trail.Enabled = false
			trail.Color = ColorSequence.new(Color3.fromRGB(220, 190, 255))
			trail.Rate = 60
			trail.Lifetime = NumberRange.new(0.2, 0.35)
			trail.Speed = NumberRange.new(2, 4)
			trail.SpreadAngle = Vector2.new(60, 60)
			trail.Size = NumberSequence.new(0.3)
			trail.Transparency = NumberSequence.new(0.1, 1)
			trail.LightEmission = 1
			trail.Parent = arm
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "StandHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(190, 140, 255)
	highlight.OutlineTransparency = 0.1
	highlight.Parent = template

	-- The ornamental armor and elbow rig only apply to the old Detail-based
	-- template; the new display-style template carries its own finished look.
	if template:FindFirstChild("Detail") then
		upgradeStarPlatinumModel(template)
		installStarPlatinumElbows(template)
	end
	print("[StandService] Template ready:", template.Name)
end

local GOLD = Color3.fromRGB(255, 190, 60)

local function buildFace(stand)
	local detail = stand:FindFirstChild("Detail")
	local headModel = detail and detail:FindFirstChild("Head")
	if not headModel then return end
	local eyesMesh = headModel:FindFirstChild("Eyes")
	local fakeHead = headModel:FindFirstChild("Fake Head")
	if not eyesMesh or not fakeHead then return end
	local eye1 = eyesMesh:FindFirstChild("Eye1")
	local eye2 = eyesMesh:FindFirstChild("Eye2")
	if not (eye1 and eye2) then return end

	local faceDecal = fakeHead:FindFirstChild("face")
	if faceDecal then
		faceDecal.Transparency = 1
	end

	local eye1Pos = eye1.WorldPosition
	local eye2Pos = eye2.WorldPosition
	local eyeMid = (eye1Pos + eye2Pos) / 2
	local eyeDist = (eye1Pos - eye2Pos).Magnitude
	if eyeDist < 0.05 then
		warn("[StandService] Eye attachments too close, skipping battle face")
		return
	end

	local up = fakeHead.CFrame.UpVector
	local front = eyeMid - fakeHead.Position
	front = front - up * front:Dot(up)
	front = front.Magnitude > 0.01 and front.Unit or fakeHead.CFrame.LookVector
	local back = -front
	local right = front:Cross(up)

	local function attachWelded(part, anchorPart, cf)
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.CFrame = cf
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchorPart
		weld.Part1 = part
		weld.Parent = part
		part.Parent = headModel
	end

	for _, eyePos in { eye1Pos, eye2Pos } do
		local innerSign = right:Dot(eyePos - eyeMid) > 0 and 1 or -1
		local along = innerSign == 1 and right or -right
		local browPos = eyePos + up * (eyeDist * 0.42) + front * (eyeDist * 0.12)
		local brow = Instance.new("Part")
		brow.Name = "AngryBrow"
		brow.Size = Vector3.new(eyeDist * 0.85, eyeDist * 0.13, eyeDist * 0.13)
		brow.Color = GOLD
		brow.Material = Enum.Material.Neon
		attachWelded(brow, eyesMesh, CFrame.fromMatrix(browPos, along, up, back) * CFrame.Angles(0, 0, 0.45))
	end

	local mouthPos = eyeMid - up * (eyeDist * 0.75) + front * (eyeDist * 0.3)
	local mouthBase = CFrame.fromMatrix(mouthPos, right, up, back)
	local mouth = Instance.new("Part")
	mouth.Name = "BattleMouth"
	mouth.Size = Vector3.new(eyeDist * 1.0, eyeDist * 0.34, eyeDist * 0.12)
	mouth.Color = Color3.fromRGB(25, 10, 20)
	mouth.Material = Enum.Material.SmoothPlastic
	attachWelded(mouth, fakeHead, mouthBase)

	local teeth = Instance.new("Part")
	teeth.Name = "BattleTeeth"
	teeth.Size = Vector3.new(eyeDist * 0.92, eyeDist * 0.12, eyeDist * 0.06)
	teeth.Color = Color3.fromRGB(240, 240, 235)
	teeth.Material = Enum.Material.SmoothPlastic
	attachWelded(teeth, fakeHead, mouthBase * CFrame.new(0, eyeDist * 0.11, -eyeDist * 0.03))

	print("[StandService] Battle face built:", stand.Name)
end

local function removeStand(player)
	-- V8: cancelling a barrage also restores movement and invalidates its
	-- running task. The previous implementation only cleared a boolean,
	-- potentially leaving the caster slowed after desummoning.
	local session = activeBarrages[player.UserId]
	if session then
		activeBarrages[player.UserId] = nil
		if session.stand and session.stand.Parent then
			session.stand:SetAttribute("BarrageEndsAt", 0)
		end
		if session.humanoid and session.humanoid.Parent then
			session.humanoid.WalkSpeed = session.savedSpeed
		end
		if session.sound and session.sound.Parent then
			session.sound:Stop()
		end
		if session.shout and session.shout.Parent then
			session.shout:Stop()
		end
	end
	local existing = workspace:FindFirstChild(player.Name .. "Stand")
	if existing then
		existing:Destroy()
	end
end

local function giveStand(player)
	if player:GetAttribute("Standless") then return end
	local standId = player:GetAttribute("StandId") or DEFAULT_STAND_ID
	local stand = StandData.GetStand(standId)
	if not stand then
		warn("[StandService] Unknown stand id:", tostring(standId))
		return
	end
	local template = ReplicatedStorage:FindFirstChild(stand.TemplateName)
	if not template then
		warn("[StandService] Missing template:", stand.TemplateName)
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")

	-- One cry per summon: if a deployment of this same stand is still running,
	-- a racing giveStand call (join race, respawn overlapping a toggle) must
	-- not deploy a second model and double-play the summon voice line.
	local pendingDeploy = workspace:FindFirstChild(player.Name .. "Stand")
	if pendingDeploy
		and pendingDeploy:GetAttribute("State") == "Deploying"
		and pendingDeploy:GetAttribute("StandId") == standId then
		print("[StandService] Summon already running for", player.Name)
		return
	end

	removeStand(player)

	local clone = template:Clone()
	clone.Name = player.Name .. "Stand"
	clone:SetAttribute("Owner", player.UserId)
	clone:SetAttribute("StandId", standId)
	applyStandTheme(clone, stand)
	-- Cinematic deployment is replicated to all players, so the Stand rises and materializes
	-- on every client. Any attacks are blocked until the animation finishes.
	clone:SetAttribute("State", "Deploying")
	clone:SetAttribute("StateStarted", workspace:GetServerTimeNow())
	-- Start below its normal position. StandController smoothly raises it in sync
	-- with the fade and summoning stance (the existing 3D rig stays intact).
	clone:PivotTo(character.HumanoidRootPart.CFrame * CFrame.new(stand.FollowOffset + Vector3.new(0, -4.3, 0)))
	makeStandIntangible(clone)
	clone.Parent = workspace
	buildFace(clone)

	local summonDuration = stand.SummonDuration or 1.25
	-- After the cinematic deployment the stand holds its iconic Star Platinum
	-- pose briefly before combat starts. Attacks stay blocked during the pose.
	local POSE_DURATION = 1.5
	task.delay(summonDuration, function()
		-- Do not revive a removed Stand or override a newer action/state.
		if clone.Parent and clone:GetAttribute("State") == "Deploying" then
			clone:SetAttribute("State", "Pose")
			clone:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			task.delay(POSE_DURATION, function()
				if clone.Parent and clone:GetAttribute("State") == "Pose" then
					clone:SetAttribute("State", "Idle")
					clone:SetAttribute("StateStarted", workspace:GetServerTimeNow())
				end
			end)
		end
	end)
	print("[StandService] Summoned", stand.DisplayName, "for", player.Name)
end

local function isStandOrCaster(model, casterCharacter)
	return model == casterCharacter or model:GetAttribute("Owner") ~= nil
end

local function getTargets(caster, originCFrame, boxSize, range)
	local targets = {}
	local seen = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster.Character, workspace:FindFirstChild(caster.Name .. "Stand") }

	local center = originCFrame.Position + originCFrame.LookVector * (range / 2)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(center) * originCFrame.Rotation, boxSize, params)
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		while model do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not isStandOrCaster(model, caster.Character) and not seen[model] then
				seen[model] = true
				table.insert(targets, { model = model, humanoid = humanoid, root = model.PrimaryPart })
			end
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
	end
	return targets
end

-- V27: every landed hit is broadcast so clients can render damage numbers,
-- spark bursts, camera shake and the combo counter (see CombatFX).
-- Parade : défini plus bas (section PARADE). Il peut réduire ou annuler les
-- dégâts ; il marque alors la cible (target.guarded = "block" | "parry") pour
-- que le recul et les étourdissements ne s'appliquent pas.
local guardHook = nil

-- ==================== ÉTOURDISSEMENT À L'IMPACT ====================
-- Un joueur qui prend un coup ne peut plus attaquer pendant un instant
-- (selon le type de coup). La garde reste possible. Les coups bloqués ou
-- parés ne comptent pas. L'attribut "Hitstun" du joueur sert à l'affichage.
local HITSTUN = {
	light = 0.6, -- M1 (un peu plus que le rythme du combo : le combo est garanti)
	barrage = 0.35, -- renouvelé à chaque coup du barrage
	heavy = 0.8,
	final = 0.9,
	projectile = 0.5,
	zone = 0.2,
}
local HITSTUN_DEFAULT = 0.5
local hitstunUntil = {} -- [Player] = os.clock() de fin

-- Garde pendant un combo M1 : la victime ne peut PAS lever sa garde après
-- les 2 premiers M1 reçus ; à partir du 3e, elle peut (pour bloquer le
-- coup final). Le compte repart de zéro après une pause de M1_TAKEN_RESET.
local GUARD_UNLOCK_AFTER_M1 = 3
local M1_TAKEN_RESET = 1.0
local m1Taken = {} -- [Player] = { count, lastAt }
local guardLockUntil = {} -- [Player] = os.clock() de fin

local function onM1Taken(player)
	local now = os.clock()
	local entry = m1Taken[player]
	if not entry or now - entry.lastAt > M1_TAKEN_RESET then
		entry = { count = 0, lastAt = now }
		m1Taken[player] = entry
	end
	entry.count += 1
	entry.lastAt = now
	if entry.count < GUARD_UNLOCK_AFTER_M1 then
		guardLockUntil[player] = now + HITSTUN.light
		player:SetAttribute("GuardLocked", true)
	else
		guardLockUntil[player] = nil
		player:SetAttribute("GuardLocked", nil)
	end
end

local function applyHitstun(player, kind)
	local untilT = os.clock() + (HITSTUN[kind] or HITSTUN_DEFAULT)
	if not hitstunUntil[player] or untilT > hitstunUntil[player] then
		hitstunUntil[player] = untilT
	end
	if not player:GetAttribute("Hitstun") then
		player:SetAttribute("Hitstun", true)
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, untilT in hitstunUntil do
		if now >= untilT or not player.Parent then
			hitstunUntil[player] = nil
			if player.Parent then player:SetAttribute("Hitstun", nil) end
		end
	end
	for player, untilT in guardLockUntil do
		if now >= untilT or not player.Parent then
			guardLockUntil[player] = nil
			if player.Parent then player:SetAttribute("GuardLocked", nil) end
		end
	end
	for player, entry in m1Taken do
		if not player.Parent or now - entry.lastAt > M1_TAKEN_RESET then
			m1Taken[player] = nil
		end
	end
end)

local function dealDamage(targets, amount, caster, knockback, kind)
	for _, target in targets do
		target.guarded = nil
		local final = amount
		if guardHook then
			final = guardHook(target, caster, amount, kind)
		end
		if final > 0 then
			target.humanoid:TakeDamage(final)
			local victim = Players:GetPlayerFromCharacter(target.model)
			if victim then
				applyHitstun(victim, kind)
				if kind == "light" then
					onM1Taken(victim)
				end
			end
		end
		if knockback and not target.guarded and target.root and not target.root.Anchored then
			target.root.AssemblyLinearVelocity = caster.HumanoidRootPart.CFrame.LookVector * knockback + Vector3.new(0, 20, 0)
		end
		if final > 0 then
			standFX:FireAllClients("Hit", kind or "barrage",
				target.root and target.root.Position or caster.HumanoidRootPart.Position, final)
		end
	end
end

local PURPLE = Color3.fromRGB(170, 120, 255)

local function impactFX(position, color, maxSize, soundSpeed)
	local ball = Instance.new("Part")
	ball.Name = "StandImpact"
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Transparency = 0.25
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Size = Vector3.new(0.5, 0.5, 0.5)
	ball.CFrame = CFrame.new(position)
	ball.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 4
	light.Range = 16
	light.Parent = ball

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/collide.wav"
	sound.Volume = 0.7
	sound.PlaybackSpeed = soundSpeed or 1
	sound.RollOffMaxDistance = 120
	sound.Parent = ball
	sound:Play()

	local tween = TweenService:Create(
		ball,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(maxSize, maxSize, maxSize), Transparency = 1 }
	)
	tween:Play()
	tween.Completed:Once(function()
		ball:Destroy()
	end)
end

local function pulseGlow(stand)
	local glow = stand:FindFirstChild("StandGlow", true)
	if not glow then return end
	glow.Brightness = 4
	task.delay(0.08, function()
		if glow.Parent then
			glow.Brightness = 1.2
		end
	end)
end

-- YBA-style stun-lock: every barrage hit re-stuns the victim (walk/jump
-- locked) for StunPerTick; the lock lapses shortly after the hits stop.
local function releaseVictim(session)
	local victim = session.victim
	if not victim then return end
	session.victim = nil
	if victim.model and victim.model.Parent and victim.humanoid and victim.humanoid.Parent then
		victim.humanoid.WalkSpeed = victim.savedWalkSpeed or 16
		victim.humanoid.JumpPower = victim.savedJumpPower or 50
		victim.humanoid.JumpHeight = victim.savedJumpHeight or 7.2
	end
end

local function stunVictim(session, target)
	if target.guarded then return end -- cible en garde : pas d'étourdissement
	local victim = session.victim
	if victim and victim.model ~= target.model then
		releaseVictim(session)
		victim = nil
	end
	if not victim then
		local humanoid = target.humanoid
		victim = {
			model = target.model,
			humanoid = humanoid,
			root = target.root,
			savedWalkSpeed = humanoid.WalkSpeed,
			savedJumpPower = humanoid.JumpPower,
			savedJumpHeight = humanoid.JumpHeight,
		}
		session.victim = victim
	end
	victim.humanoid.WalkSpeed = 0
	victim.humanoid.JumpPower = 0
	victim.humanoid.JumpHeight = 0
	session.victimStunUntil = workspace:GetServerTimeNow() + (session.move.StunPerTick or 0.15)
end

-- V8: a barrage owns a unique session. This prevents a new click at the
-- cooldown boundary from setting State=Barrage without starting a matching
-- damage/cleanup task. All termination paths return the Stand to Idle.
local function finishBarrage(player, session, completed)
	local userId = player.UserId
	if activeBarrages[userId] ~= session then return end
	activeBarrages[userId] = nil
	-- YBA: the long barrage cooldown is charged when the barrage ENDS
	-- (full duration, early release, or cancel), not when it starts.
	lastUse[userId] = lastUse[userId] or {}
	lastUse[userId].Barrage = os.clock()
	releaseVictim(session)
	if session.stand and session.stand.Parent then
		session.stand:SetAttribute("BarrageEndsAt", 0)
	end

	local humanoid = session.humanoid
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = session.savedSpeed
	end
	if session.sound and session.sound.Parent then
		session.sound:Stop()
	end
	if session.shout and session.shout.Parent then
		session.shout:Stop()
	end

	local stand = session.stand
	local started = session.started
	if not stand.Parent or stand:GetAttribute("State") ~= "Barrage"
		or stand:GetAttribute("StateStarted") ~= started then
		return
	end

	-- Changing the replicated state is the definitive stop signal for
	-- the R6 clip, ORA text, ghost fists and punch trails on all clients.
	stand:SetAttribute("State", "Idle")
	stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())

	if not completed then return end
	local character = session.character
	local root = character and character.Parent and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	local move = session.move
	local targets = getTargets(player, root.CFrame, move.BoxSize, move.Range)
	dealDamage(targets, move.FinalDamage or 4, character, move.FinalKnockback, "final")
	if #targets > 0 then
		impactFX((root.CFrame * CFrame.new(0, 0, -4)).Position, PURPLE, 12, 1.2)
	end
end

local function runBarrage(player, stand, move)
	local userId = player.UserId
	if activeBarrages[userId] then return false end
	local started = stand:GetAttribute("StateStarted")
	-- YBA flow: a windup beat first, then hold-to-sustain punching up to
	-- MaxHold; Duration stays the absolute hard cap.
	local windup = move.Windup or 0.45
	local maxHold = move.MaxHold or 3.0
	local duration = math.min(move.Duration or (windup + maxHold), windup + maxHold)
	stand:SetAttribute("BarrageEndsAt", started + duration)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local sound = stand:FindFirstChild("BarrageHit", true)
	local soundAlt = stand:FindFirstChild("BarrageHitAlt", true)
	local shout = stand:FindFirstChild("OraShout", true)
	local hitFlip = 0
	local session = {
		player = player,
		stand = stand,
		started = started,
		character = character,
		humanoid = humanoid,
		savedSpeed = humanoid and humanoid.WalkSpeed or 16,
		sound = sound,
		shout = shout,
		move = move,
		windup = windup,
		deadline = started + duration,
		victim = nil,
		victimStunUntil = 0,
	}
	activeBarrages[userId] = session
	if humanoid then humanoid.WalkSpeed = move.SelfSlow end

	-- ORA ORA ORA: the anime barrage voice clip plays looped for the whole
	-- barrage; it is restarted only if something interrupted it, and it is
	-- stopped when the session ends.
	task.spawn(function()
		if shout and shout.Parent then
			shout.Looped = true
			shout:Play()
		end
		while activeBarrages[userId] == session do
			if shout and shout.Parent and not shout.IsPlaying then
				shout:Play()
			end
			task.wait(0.25)
		end
	end)

	-- Primary time limit: never let a stalled damage loop keep the
	-- barrage state or its animation active beyond the allotted duration.
	task.delay(duration, function()
		finishBarrage(player, session, true)
	end)

	task.spawn(function()
		while activeBarrages[userId] == session do
			task.wait(move.TickRate)
			if activeBarrages[userId] ~= session then return end
			if workspace:GetServerTimeNow() >= session.deadline then
				finishBarrage(player, session, true)
				return
			end
			if not stand.Parent or stand:GetAttribute("State") ~= "Barrage"
				or stand:GetAttribute("StateStarted") ~= started then
				finishBarrage(player, session, false)
				return
			end
			local root = character and character.Parent and character:FindFirstChild("HumanoidRootPart")
			if not root or not humanoid or humanoid.Health <= 0 then
				finishBarrage(player, session, false)
				return
			end
			-- YBA windup: no punches land during the first Windup seconds.
			if workspace:GetServerTimeNow() < started + windup then
				continue
			end
			-- The stun lapses shortly after hits stop landing.
			if session.victim and workspace:GetServerTimeNow() > session.victimStunUntil then
				releaseVictim(session)
			end
			local targets = getTargets(player, root.CFrame, move.BoxSize, move.Range)
			-- YBA lock-on: the barrage focuses the nearest valid target; if it
			-- dies or escapes the box, the next tick locks a new one or whiffs.
			local victim = nil
			local bestDist = nil
			for _, target in targets do
				local d = target.root and (target.root.Position - root.Position).Magnitude or math.huge
				if not bestDist or d < bestDist then
					victim, bestDist = target, d
				end
			end
			if victim then
				dealDamage({ victim }, move.DamagePerTick, character, nil, "barrage")
				stunVictim(session, victim)
				local sfx = (hitFlip % 2 == 0) and sound or soundAlt
				hitFlip += 1
				if sfx and sfx.Parent then
					sfx.PlaybackSpeed = 0.85 + math.random() * 0.55
					sfx.Volume = 0.45 + math.random() * 0.3
					sfx:Play()
				end
				pulseGlow(stand)
			end
		end
	end)
	return true
end

-- Dernier coup du combo M1 : le Stand joue le Heavy Punch (animation,
-- position, effets) et repousse les cibles touchées. N'utilise pas le
-- cooldown de la touche R.
local function runComboFinisher(player, stand, standDef, move)
	stand:SetAttribute("State", "HeavyPunch")
	stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())

	local voice = standDef and resolveVoice(standDef.HeavyVoicePath)
	local torso = stand:FindFirstChild("Torso") or stand:FindFirstChild("UpperTorso")
	if voice and torso then
		local shout = voice:Clone()
		shout.Name = "FinisherVoice"
		shout.Looped = false
		shout.Parent = torso
		shout:Play()
		task.delay(6, function()
			if shout.Parent then shout:Destroy() end
		end)
	end

	task.delay(move.FinisherHitDelay or 0.25, function()
		if not stand.Parent or stand:GetAttribute("State") ~= "HeavyPunch" then return end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local targets = getTargets(player, hrp.CFrame, move.BoxSize, move.Range)
		dealDamage(targets, move.FinisherDamage or 15, character, move.FinisherKnockback or 70, "heavy")
		local hitPos = #targets > 0 and targets[1].root and targets[1].root.Position
			or (hrp.CFrame * CFrame.new(0, 0, -move.Range / 2)).Position
		impactFX(hitPos, GOLD, 14, 0.85)
		impactFX(hitPos, PURPLE, 8, 1.3)
	end)

	task.delay(move.FinisherDuration or 0.45, function()
		if stand.Parent and stand:GetAttribute("State") == "HeavyPunch" then
			stand:SetAttribute("State", "Idle")
			stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
		end
	end)
end

local function runHeavy(player, stand, move)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local hrp = character.HumanoidRootPart
	-- Per-stand heavy punch cry (e.g. GER's Strong Punch SFX): clone the pack
	-- clip onto the stand so its playback replicates to everyone nearby.
	local standDef = StandData.GetStand(stand:GetAttribute("StandId"))
	local voice = standDef and resolveVoice(standDef.HeavyVoicePath)
	local heavyTorso = stand:FindFirstChild("Torso") or stand:FindFirstChild("UpperTorso")
	if voice and heavyTorso then
		local shout = voice:Clone()
		shout.Name = "HeavyVoice"
		shout.Looped = false
		shout.Parent = heavyTorso -- Sounds only play on a BasePart, not the Model
		shout:Play()
		task.delay(6, function()
			if shout.Parent then
				shout:Destroy()
			end
		end)
	end
	local targets = getTargets(player, hrp.CFrame, move.BoxSize, move.Range)
	dealDamage(targets, move.Damage, character, move.Knockback, "heavy")
	local hitPos = #targets > 0 and targets[1].root and targets[1].root.Position
		or (hrp.CFrame * CFrame.new(0, 0, -move.Range / 2)).Position
	impactFX(hitPos, GOLD, 18, 0.8)
	impactFX(hitPos, PURPLE, 10, 1.3)
end

-- GER-only mercy move: T channels life energy into the person the stand
-- strikes — the nearest valid target in the hit box, barrage lock-on style.
-- Pure restoration (no damage, no knockback); the gold-green pulse reads as
-- healing to everyone nearby.
local HEAL_GREEN = Color3.fromRGB(110, 255, 170)

local function runHeal(player, stand, move)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local hrp = character.HumanoidRootPart
	local targets = getTargets(player, hrp.CFrame, move.BoxSize, move.Range)
	local victim, bestDist = nil, nil
	for _, target in targets do
		local d = target.root and (target.root.Position - hrp.Position).Magnitude or math.huge
		if not bestDist or d < bestDist then
			victim, bestDist = target, d
		end
	end
	if not victim or not victim.humanoid or victim.humanoid.Health <= 0 then return end
	local humanoid = victim.humanoid
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + move.HealAmount)
	local healed = humanoid.Health - before
	if healed <= 0 then return end
	local hitPos = victim.root and victim.root.Position
		or (hrp.CFrame * CFrame.new(0, 0, -move.Range / 2)).Position
	impactFX(hitPos, HEAL_GREEN, 12, 0.55)
	impactFX(hitPos, GOLD, 7, 0.9)
	standFX:FireAllClients("Healed", hitPos, healed)
	print("[StandService] Heal for", player.Name, "->", victim.model and victim.model.Name,
		"+" .. tostring(math.floor(healed + 0.5)) .. " HP")
end

local frozen = {}

local function runTimeStop(player, stand, move)
	standFX:FireAllClients("TimeStop", move.Duration, player.Name)
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character and other.Character:FindFirstChildOfClass("Humanoid") then
			local humanoid = other.Character:FindFirstChildOfClass("Humanoid")
			if not frozen[other] then
				frozen[other] = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight }
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
			end
		end
	end
	for _, dummy in workspace:GetChildren() do
		if dummy:GetAttribute("IsDummy") and not frozen[dummy] then
			local humanoid = dummy:FindFirstChildOfClass("Humanoid")
			if humanoid then
				frozen[dummy] = { Anchored = true }
				humanoid.WalkSpeed = 0
			end
		end
	end

	task.delay(move.Duration, function()
		for instance, saved in frozen do
			if instance.Parent then
				local humanoid = instance:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if saved.WalkSpeed then humanoid.WalkSpeed = saved.WalkSpeed end
					if saved.JumpPower then humanoid.JumpPower = saved.JumpPower end
					if saved.JumpHeight then humanoid.JumpHeight = saved.JumpHeight end
				end
			end
			frozen[instance] = nil
		end
	end)
end

-- ==================== SORTS (attaques T / F / G) ====================
-- Moteur générique des attaques définies dans ReplicatedStorage.StandSpells.
-- Chaque attaque a un Type (Strike, Dash, Projectile, Burst, Buff,
-- Teleport) et ses réglages ; voir l'en-tête de StandSpells.
local SPELL_DEFAULT_COLOR = PURPLE

local spellFolder = Instance.new("Folder")
spellFolder.Name = "StandSpellFX"
spellFolder.Parent = workspace

local function spellColor(standDef, move)
	return move.Color or (standDef and standDef.Theme and standDef.Theme.Aura1) or SPELL_DEFAULT_COLOR
end

-- Cibles dans une sphère (joueurs et mannequins, jamais le lanceur ni un Stand)
local function getTargetsInRadius(caster, center, radius)
	local targets, seen = {}, {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster.Character, workspace:FindFirstChild(caster.Name .. "Stand"), spellFolder }
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not isStandOrCaster(model, caster.Character) and not seen[model] then
				seen[model] = true
				table.insert(targets, { model = model, humanoid = humanoid, root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") })
			end
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
	end
	return targets
end

-- Étourdissement : vitesse et saut à 0 pendant `seconds`, puis restauration.
local spellStuns = {} -- [Humanoid] = { untilT, WalkSpeed, JumpPower, JumpHeight }
local function stunTargets(targets, seconds)
	if not seconds or seconds <= 0 then return end
	local untilT = os.clock() + seconds
	for _, target in targets do
		local h = target.humanoid
		if h and h.Parent and not target.guarded then
			local entry = spellStuns[h]
			if not entry then
				entry = { WalkSpeed = h.WalkSpeed, JumpPower = h.JumpPower, JumpHeight = h.JumpHeight }
				spellStuns[h] = entry
			end
			entry.untilT = math.max(entry.untilT or 0, untilT)
			h.WalkSpeed = 0
			h.JumpPower = 0
			h.JumpHeight = 0
		end
	end
end
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for h, entry in spellStuns do
		if not h.Parent then
			spellStuns[h] = nil
		elseif now >= entry.untilT then
			spellStuns[h] = nil
			h.WalkSpeed = entry.WalkSpeed
			h.JumpPower = entry.JumpPower
			h.JumpHeight = entry.JumpHeight
		end
	end
end)

-- Recul depuis un point (explosions) : vers l'extérieur + un peu vers le haut
local function pushFrom(targets, center, force, launch)
	for _, target in targets do
		local root = target.root
		if root and not root.Anchored and not target.guarded then
			local away = root.Position - center
			away = Vector3.new(away.X, 0, away.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.zero
			root.AssemblyLinearVelocity = away * (force or 0) + Vector3.new(0, (launch or 0) + (force and force > 0 and 20 or 0), 0)
		end
	end
end

local function spellBurstAt(player, center, radius, damage, knockback, launch, stun, color)
	local character = player.Character
	if not character then return end
	local targets = getTargetsInRadius(player, center, radius)
	if damage and damage > 0 then
		dealDamage(targets, damage, character, nil, "heavy")
	end
	pushFrom(targets, center, knockback, launch)
	stunTargets(targets, stun)
	impactFX(center, color, radius * 2, 0.7)
	return targets
end

-- Frappe devant le joueur, avec bombe à retardement optionnelle
local function spellStrike(player, standDef, move, origin)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local color = spellColor(standDef, move)
	local range = move.Range or 10
	local targets = getTargets(player, origin or hrp.CFrame, move.BoxSize or Vector3.new(7, 7, range), range)
	dealDamage(targets, move.Damage or 0, character, move.Knockback, "heavy")
	stunTargets(targets, move.Stun)
	local hitPos = #targets > 0 and targets[1].root and targets[1].root.Position
		or ((origin or hrp.CFrame) * CFrame.new(0, 0, -range / 2)).Position
	impactFX(hitPos, color, 10, 1.1)
	if move.BombDelay then
		for _, target in targets do
			local root = target.root
			task.delay(move.BombDelay, function()
				if root and root.Parent then
					spellBurstAt(player, root.Position, move.BombRadius or 7, move.BombDamage or 15, 35, 10, nil, color)
				end
			end)
		end
	end
end

-- ─── Projectiles ────────────────────────────────────────────────────────────
-- Le serveur calcule la trajectoire (balayage Spherecast : pas de cible
-- "traversée" entre deux images, arrêt contre les murs) SANS rien afficher ;
-- chaque client affiche le projectile en local (ProjectileFX), ce qui le
-- rend fluide. Les projectiles à tête chercheuse (Homing) sont affichés par
-- le serveur, car les clients ne peuvent pas deviner leur trajet.
local MAX_PROJECTILE_PITCH = math.rad(60) -- visée max vers le haut / le bas
local projectileCounter = 0

local function projectileParams(player)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild(player.Name .. "Stand"), spellFolder }
	params.IgnoreWater = true
	return params
end

-- Modèle touché (joueur / mannequin valide) ou nil si c'est le décor
local function targetFromPart(player, part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.Health > 0 and not isStandOrCaster(model, player.Character) then
				return { model = model, humanoid = humanoid, root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") }
			end
			return false -- Stand, lanceur ou mort : on traverse
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function makeProjectilePart(move, color, size)
	local part = Instance.new("Part")
	part.Name = "SpellProjectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	if move.Shape == "Blade" then
		part.Size = Vector3.new(size * 0.4, size * 0.4, size * 3)
	else
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(size, size, size)
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 2
	light.Parent = part
	return part
end

local function spawnProjectile(player, standDef, move, origin, direction)
	local color = spellColor(standDef, move)
	local size = move.Size or 0.6
	local radius = math.max(size / 2, 0.3) + 0.5 -- un peu de marge pour toucher
	local speed = move.Speed or 100
	local maxRange = move.Range or 60
	local character = player.Character
	local params = projectileParams(player)

	projectileCounter += 1
	local id = projectileCounter
	local serverPart
	if move.Homing then
		serverPart = makeProjectilePart(move, color, size)
		serverPart.CFrame = CFrame.lookAt(origin, origin + direction)
		serverPart.Parent = spellFolder
	else
		standFX:FireAllClients("Projectile", id, origin, direction, speed, maxRange,
			{ Size = size, Shape = move.Shape or "Ball", Color = color })
	end

	local pos, dir, traveled = origin, direction, 0
	local hitModels = {}
	local connection
	local function finish(endPos, explode)
		if connection then connection:Disconnect() end
		if serverPart then serverPart:Destroy() end
		standFX:FireAllClients("ProjectileEnd", id, endPos)
		if explode and move.Explode then
			spellBurstAt(player, endPos, move.Explode.Radius or 8, move.Explode.Damage or 15, 40, 15, nil, color)
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		if not character or not character.Parent then
			finish(pos, false)
			return
		end
		-- Tête chercheuse : tourne doucement vers la cible la plus proche devant
		if move.Homing then
			local best, bestDist
			for _, target in getTargetsInRadius(player, pos, move.HomingRange or 30) do
				if target.root and not hitModels[target.model] then
					local to = target.root.Position - pos
					if to.Magnitude > 0.1 and to.Unit:Dot(dir) > 0.2 and (not bestDist or to.Magnitude < bestDist) then
						best, bestDist = target, to.Magnitude
					end
				end
			end
			if best then
				local want = (best.root.Position - pos).Unit
				local turn = math.min(1, (move.Homing or 3) * dt)
				dir = dir:Lerp(want, turn).Unit
			end
		end

		local step = math.min(speed * dt, maxRange - traveled)
		-- Balayage du segment parcouru pendant cette image
		local remaining = step
		local from = pos
		for _ = 1, 6 do
			if remaining <= 0 then break end
			local result = workspace:Spherecast(from, radius, dir * remaining, params)
			if not result then
				from += dir * remaining
				remaining = 0
				break
			end
			local target = targetFromPart(player, result.Instance)
			local hitPos = from + dir * result.Distance
			if target then
				if not hitModels[target.model] then
					hitModels[target.model] = true
					dealDamage({ target }, move.Damage or 5, character, move.Knockback, "projectile")
					stunTargets({ target }, move.Stun)
					impactFX(hitPos, color, 5, 1.4)
				end
				if not move.Pierce then
					finish(hitPos, true)
					return
				end
			elseif target == nil and result.Instance.CanCollide then
				-- Mur / sol : le projectile s'arrête (et explose s'il le peut)
				impactFX(hitPos, color, 3, 1.6)
				finish(hitPos, true)
				return
			end
			-- Pièce à ignorer (Stand, déco sans collision…) : on continue derrière
			local ignore = params.FilterDescendantsInstances
			table.insert(ignore, target == false and result.Instance:FindFirstAncestorOfClass("Model") or result.Instance)
			params.FilterDescendantsInstances = ignore
			local advance = result.Distance + 0.05
			from += dir * advance
			remaining -= advance
		end
		pos = from
		traveled += step
		if serverPart then
			serverPart.CFrame = CFrame.lookAt(pos, pos + dir)
		end
		if traveled >= maxRange - 0.01 then
			finish(pos, move.Explode ~= nil)
		end
	end)
end

-- Direction de tir : vers le point visé par le joueur (souris / centre de
-- l'écran sur mobile), sinon droit devant. Inclinaison limitée.
local function aimDirection(origin, flat, aim)
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude > 1e6 then
		return flat
	end
	local to = aim - origin
	if to.Magnitude < 1 then return flat end
	local dir = to.Unit
	local horizontal = Vector3.new(dir.X, 0, dir.Z)
	if horizontal.Magnitude < 0.05 then return flat end
	local pitch = math.clamp(math.atan2(dir.Y, horizontal.Magnitude), -MAX_PROJECTILE_PITCH, MAX_PROJECTILE_PITCH)
	horizontal = horizontal.Unit
	return (horizontal * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit
end

local function spellProjectiles(player, stand, standDef, move, aim)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	-- Départ : là où le Stand se trouve à l'écran pendant un sort (devant le
	-- joueur, cf. StandController). Le Stand côté serveur, lui, ne bouge pas.
	local origin = hrp.Position + flat * 3.4 + Vector3.new(0, 1.3, 0)
	local center = aimDirection(origin, flat, aim)
	local count = move.Count or 1
	local spread = math.rad(move.Spread or 0)
	for i = 1, count do
		local angle = count > 1 and (-spread / 2 + spread * (i - 1) / (count - 1)) or 0
		local dir = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(center)
		spawnProjectile(player, standDef, move, origin, dir.Unit)
	end
end

-- Bonus sur soi : soin et / ou vitesse
local function spellBuff(player, standDef, move)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then return end
	local color = spellColor(standDef, move)
	if move.Heal then
		local before = humanoid.Health
		humanoid.Health = math.min(humanoid.MaxHealth, before + move.Heal)
		local healed = humanoid.Health - before
		if healed > 0 then
			standFX:FireAllClients("Healed", hrp.Position, healed)
		end
	end
	if move.SpeedBoost then
		local base = humanoid.WalkSpeed
		local boosted = base * move.SpeedBoost
		humanoid.WalkSpeed = boosted
		task.delay(move.BuffTime or 5, function()
			-- Ne restaure que si personne d'autre n'a changé la vitesse entre-temps
			if humanoid.Parent and math.abs(humanoid.WalkSpeed - boosted) < 0.01 then
				humanoid.WalkSpeed = base
			end
		end)
	end
	impactFX(hrp.Position, color, 9, 0.6)
end

-- Ruée : c'est le client qui pousse son personnage (il possède sa physique) ;
-- le serveur vérifie les cibles traversées pendant la ruée.
local function spellDash(player, standDef, move)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local dashTime = move.DashTime or 0.25
	standFX:FireClient(player, "SpellDash", move.DashSpeed or 80, dashTime)
	local hitModels = {}
	local color = spellColor(standDef, move)
	local checks = math.max(2, math.ceil(dashTime / 0.06))
	for i = 1, checks do
		task.delay(i * dashTime / checks + 0.03, function()
			if not hrp.Parent then return end
			local targets = getTargets(player, hrp.CFrame, move.BoxSize or Vector3.new(7, 7, 8), 6)
			local fresh = {}
			for _, target in targets do
				if not hitModels[target.model] then
					hitModels[target.model] = true
					table.insert(fresh, target)
				end
			end
			if #fresh > 0 then
				dealDamage(fresh, move.Damage or 0, character, move.Knockback, "heavy")
				stunTargets(fresh, move.Stun)
				impactFX(fresh[1].root and fresh[1].root.Position or hrp.Position, color, 9, 1.2)
			end
		end)
	end
end

-- Téléportation derrière l'ennemi le plus proche, puis frappe
local function spellTeleport(player, standDef, move)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local best, bestDist = nil, nil
	for _, target in getTargetsInRadius(player, hrp.Position, move.Range or 40) do
		if target.root then
			local d = (target.root.Position - hrp.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = target, d
			end
		end
	end
	local color = spellColor(standDef, move)
	impactFX(hrp.Position, color, 6, 1.6)
	if best then
		local behind = best.root.CFrame * CFrame.new(0, 0, 3.5)
		character:PivotTo(CFrame.lookAt(behind.Position, best.root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, behind.Position.Y, 0)))
	end
	task.delay(math.max(0.05, (move.HitDelay or 0.3) - 0.1), function()
		if hrp.Parent then
			spellStrike(player, standDef, move)
		end
	end)
end

-- ─── Mécaniques du moveset original ─────────────────────────────────────────

-- Point au sol sous `pos` (pour les zones et les pièges)
local function groundAt(player, pos)
	local params = projectileParams(player)
	local result = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return result and result.Position or (pos - Vector3.new(0, 3, 0))
end

local function flatLook(hrp)
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
end

local function fxPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		part[k] = v
	end
	part.Parent = spellFolder
	return part
end

-- Rafale : coups répétés devant le Stand pendant Duration, puis coup final.
-- Comme un barrage : la cible est retenue, et la garde ne s'use pas.
local function spellFlurry(player, stand, standDef, move, actionName)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	local color = spellColor(standDef, move)
	task.spawn(function()
		local tick = move.TickRate or 0.1
		local endsAt = os.clock() + (move.Duration or 2) - 0.2
		task.wait(0.15) -- armement
		local count = 0
		local function stillRunning()
			return stand.Parent and stand:GetAttribute("State") == actionName
				and hrp.Parent and humanoid.Health > 0 and not spellStuns[humanoid]
		end
		while os.clock() < endsAt do
			if not stillRunning() then return end
			local targets = getTargets(player, hrp.CFrame, move.BoxSize or Vector3.new(7, 7, 10), move.Range or 9)
			if #targets > 0 then
				dealDamage(targets, move.Damage or 0.8, character, nil, "barrage")
				stunTargets(targets, tick + 0.1)
				count += 1
				if count % 3 == 1 and targets[1].root then
					impactFX(targets[1].root.Position, color, 4, 1.6)
				end
			end
			task.wait(tick)
		end
		if not stillRunning() then return end
		local targets = getTargets(player, hrp.CFrame, move.BoxSize or Vector3.new(7, 7, 10), move.Range or 9)
		dealDamage(targets, move.FinalDamage or 4, character, move.FinalKnockback or 45, "final")
		impactFX(#targets > 0 and targets[1].root and targets[1].root.Position
			or (hrp.CFrame * CFrame.new(0, 0, -(move.Range or 9) / 2)).Position, color, 10, 0.9)
	end)
end

-- Contre : pendant Duration, le prochain coup reçu est annulé et renvoyé.
-- (Déclenché dans guardHook, section PARADE.)
local counterState = {} -- [Player] = { untilT, move, standDef }

local function spellCounter(player, standDef, move)
	counterState[player] = { untilT = os.clock() + (move.Duration or 1), move = move, standDef = standDef }
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		impactFX(hrp.Position, spellColor(standDef, move), 5, 1.8)
	end
end

-- Harpon : attrape la première cible vers la souris et la ramène devant soi.
local function spellPull(player, standDef, move, aim)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local color = spellColor(standDef, move)
	local flat = flatLook(hrp)
	local origin = hrp.Position + flat * 2 + Vector3.new(0, 1.3, 0)
	local dir = aimDirection(origin, flat, aim)
	local range = move.Range or 20
	local params = projectileParams(player)
	local target, endPos = nil, origin + dir * range
	local from, remaining = origin, range
	for _ = 1, 6 do
		local result = workspace:Spherecast(from, 1.2, dir * remaining, params)
		if not result then break end
		local hit = targetFromPart(player, result.Instance)
		local hitPos = from + dir * result.Distance
		if hit then
			target, endPos = hit, hitPos
			break
		elseif hit == nil and result.Instance.CanCollide then
			endPos = hitPos
			break
		end
		local ignore = params.FilterDescendantsInstances
		table.insert(ignore, hit == false and result.Instance:FindFirstAncestorOfClass("Model") or result.Instance)
		params.FilterDescendantsInstances = ignore
		from = hitPos + dir * 0.05
		remaining -= result.Distance + 0.05
	end

	-- Le "câble" visible pendant un instant
	local length = (endPos - origin).Magnitude
	local rope = fxPart({
		Color = color, Transparency = 0.2,
		Size = Vector3.new(0.25, 0.25, math.max(length, 0.5)),
		CFrame = CFrame.lookAt((origin + endPos) / 2, endPos),
	})
	TweenService:Create(rope, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(rope, 0.4)

	if not target then return end
	dealDamage({ target }, move.Damage or 6, character, nil, "projectile")
	impactFX(endPos, color, 5, 1.4)
	if target.guarded or not target.root then return end -- bloqué : pas de prise
	stunTargets({ target }, move.Stun)
	-- La cible est tirée devant le joueur
	local model, root = target.model, target.root
	local startCF = model:GetPivot()
	local pullTime = move.PullTime or 0.25
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if not model.Parent or not hrp.Parent then
			connection:Disconnect()
			return
		end
		local goal = hrp.Position + flatLook(hrp) * (move.PullTo or 4)
		goal = Vector3.new(goal.X, startCF.Position.Y, goal.Z)
		local alpha = math.min(1, elapsed / pullTime)
		local pos = startCF.Position:Lerp(goal, alpha * alpha * (3 - 2 * alpha))
		model:PivotTo(CFrame.lookAt(pos, Vector3.new(hrp.Position.X, pos.Y, hrp.Position.Z)))
		if alpha >= 1 then
			connection:Disconnect()
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

-- Zone : champ au sol qui fait des dégâts à chaque tick à ceux qui restent dedans
local function spellZone(player, standDef, move)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local color = spellColor(standDef, move)
	local radius = move.Radius or 8
	local ground = groundAt(player, hrp.Position + flatLook(hrp) * (move.Offset or 0))
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.55,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	impactFX(ground + Vector3.new(0, 1, 0), color, radius, 0.8)
	task.spawn(function()
		local endsAt = os.clock() + (move.Lifetime or 3)
		while os.clock() < endsAt and character.Parent do
			local targets = getTargetsInRadius(player, ground + Vector3.new(0, 2, 0), radius)
			if #targets > 0 then
				dealDamage(targets, move.Damage or 3, character, nil, "zone")
				stunTargets(targets, move.Slow)
			end
			task.wait(move.TickRate or 0.5)
		end
		TweenService:Create(disc, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		game:GetService("Debris"):AddItem(disc, 0.35)
	end)
end

-- Piège : posé devant, il explose quand un ennemi s'approche (un seul piège
-- de chaque type par joueur : en poser un nouveau retire l'ancien).
local activeMines = {} -- [Player] = { [Label] = part }

local function spellMine(player, standDef, move)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local color = spellColor(standDef, move)
	local key = move.Label or "Mine"
	activeMines[player] = activeMines[player] or {}
	local old = activeMines[player][key]
	if old and old.Parent then old:Destroy() end

	local pos = groundAt(player, hrp.Position + flatLook(hrp) * (move.Offset or 4)) + Vector3.new(0, 0.5, 0)
	local mine = fxPart({
		Name = "StandMine", Shape = Enum.PartType.Ball, Color = color, Transparency = 0.3,
		Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(pos),
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6
	light.Parent = mine
	TweenService:Create(mine, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = Vector3.new(1.5, 1.5, 1.5), Transparency = 0.6 }):Play()
	activeMines[player][key] = mine

	task.spawn(function()
		task.wait(move.ArmTime or 0.6)
		local endsAt = os.clock() + (move.Lifetime or 12)
		while mine.Parent and os.clock() < endsAt and player.Parent do
			if #getTargetsInRadius(player, pos, move.TriggerRadius or 5) > 0 then
				spellBurstAt(player, pos, move.Radius or 7, move.Damage, move.Knockback, move.Launch, move.Stun, color)
				break
			end
			task.wait(0.1)
		end
		if mine.Parent then mine:Destroy() end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	counterState[player] = nil
	for _, mine in pairs(activeMines[player] or {}) do
		if mine.Parent then mine:Destroy() end
	end
	activeMines[player] = nil
end)

local function runSpell(player, stand, standDef, move, aim, actionName)
	local kind = move.Type
	if kind == "Flurry" then
		spellFlurry(player, stand, standDef, move, actionName)
		return
	elseif kind == "Counter" then
		spellCounter(player, standDef, move)
		return
	elseif kind == "Dash" then
		spellDash(player, standDef, move)
		return
	elseif kind == "Teleport" then
		spellTeleport(player, standDef, move)
		return
	end
	task.delay(move.HitDelay or 0.25, function()
		if not stand.Parent then return end
		if kind == "Strike" then
			spellStrike(player, standDef, move)
		elseif kind == "Projectile" then
			spellProjectiles(player, stand, standDef, move, aim)
		elseif kind == "Burst" then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local look = hrp.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
				local center = hrp.Position + flat * (move.Offset or 0)
				spellBurstAt(player, center, move.Radius or 10, move.Damage, move.Knockback, move.Launch, move.Stun, spellColor(standDef, move))
			end
		elseif kind == "Buff" then
			spellBuff(player, standDef, move)
		elseif kind == "Pull" then
			spellPull(player, standDef, move, aim)
		elseif kind == "Zone" then
			spellZone(player, standDef, move)
		elseif kind == "Mine" then
			spellMine(player, standDef, move)
		end
	end)
end

-- ==================== PARADE (garde / parade parfaite) ====================
-- Maintenir X : garde. Les coups reçus DE FACE ne font aucun dégât, sans
-- recul ni étourdissement, et vident la jauge de garde. Jauge vide = garde
-- brisée (étourdi). Lever la garde juste avant le coup (PARRY_WINDOW) =
-- parade parfaite : aucun dégât, l'attaquant est étourdi et son barrage
-- coupé. La jauge (attribut "Guard" du joueur) se recharge hors de la garde.
local PARRY_WINDOW = 0.3 -- s après avoir levé la garde
local BLOCK_DAMAGE_TAKEN = 0 -- part des dégâts encaissée en garde (0 = aucun dégât, seule la jauge baisse)
local GUARD_MAX = 60
local GUARD_REGEN = 15 -- points / s hors de la garde
local GUARD_REGEN_DELAY = 1 -- s avant que la jauge se recharge
local GUARD_BREAK_STUN = 1.5
local PARRY_ATTACKER_STUN = 1.2
local BLOCK_COOLDOWN = 0.5 -- s entre deux gardes
local BLOCK_WALKSPEED = 7
local BLOCK_FRONT_DOT = 0.1 -- 1 = pile en face, 0 = sur le côté

local blockState = {} -- [Player] = { started, savedSpeed }
local blockReadyAt = {}
local guardValue = {} -- [Player] = jauge
local guardUsedAt = {}
local blockFxAt = {}

local function guardOf(player)
	return guardValue[player] or GUARD_MAX
end

local function setGuard(player, value)
	value = math.clamp(value, 0, GUARD_MAX)
	guardValue[player] = value
	local shown = math.floor(value + 0.5)
	if player:GetAttribute("Guard") ~= shown then
		player:SetAttribute("Guard", shown)
	end
end

local function floatingText(position, text, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	anchor.Parent = spellFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.8), { CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(anchor, 0.9)
end

local function guardSound(position, soundId, pitch)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = spellFolder
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = 0.9
	sound.RollOffMaxDistance = 120
	sound.Parent = anchor
	sound:Play()
	game:GetService("Debris"):AddItem(anchor, 2)
end

local function stopBlock(player)
	local state = blockState[player]
	if not state then return end
	blockState[player] = nil
	blockReadyAt[player] = os.clock() + BLOCK_COOLDOWN
	player:SetAttribute("Blocking", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Restaure la vitesse seulement si personne d'autre ne l'a changée
	if humanoid and math.abs(humanoid.WalkSpeed - BLOCK_WALKSPEED) < 0.01 then
		humanoid.WalkSpeed = state.savedSpeed
	end
	local stand = workspace:FindFirstChild(player.Name .. "Stand")
	if stand and stand:GetAttribute("State") == "Block" then
		stand:SetAttribute("State", "Idle")
		stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
	end
end

local function startBlock(player)
	if blockState[player] then return end
	if (blockReadyAt[player] or 0) > os.clock() then return end
	if guardOf(player) < GUARD_MAX * 0.15 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if spellStuns[humanoid] or humanoid.WalkSpeed == 0 then return end -- étourdi
	-- en plein combo M1 (avant le 3e coup reçu) : pas de garde
	if guardLockUntil[player] and guardLockUntil[player] > os.clock() then return end
	if activeBarrages[player.UserId] then return end
	local stand = workspace:FindFirstChild(player.Name .. "Stand")
	if stand and stand:GetAttribute("State") ~= "Idle" then return end -- en pleine attaque
	blockState[player] = { started = os.clock(), savedSpeed = humanoid.WalkSpeed }
	player:SetAttribute("Blocking", true)
	humanoid.WalkSpeed = BLOCK_WALKSPEED
	if stand then
		stand:SetAttribute("State", "Block")
		stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
	end
end

-- Appelé par dealDamage pour chaque cible : renvoie les dégâts réellement subis.
guardHook = function(target, caster, amount, kind)
	local defender = Players:GetPlayerFromCharacter(target.model)

	-- CONTRE (attaques de type Counter) : le coup est annulé et renvoyé
	local counter = defender and counterState[defender]
	if counter and counter.untilT > os.clock() and caster and caster ~= target.model then
		counterState[defender] = nil
		target.guarded = "parry"
		local attackerRoot = caster:FindFirstChild("HumanoidRootPart")
		local attackerHumanoid = caster:FindFirstChildOfClass("Humanoid")
		local defenderCharacter = defender.Character
		if attackerRoot and attackerHumanoid and defenderCharacter then
			local attacker = { model = caster, humanoid = attackerHumanoid, root = attackerRoot }
			local move = counter.move
			task.defer(function()
				dealDamage({ attacker }, move.CounterDamage or 14, defenderCharacter, move.CounterKnockback, "heavy")
				stunTargets({ attacker }, move.CounterStun)
			end)
			-- Le Stand frappe (animation du coup lourd du Stand)
			local stand = workspace:FindFirstChild(defender.Name .. "Stand")
			if stand then
				local started = workspace:GetServerTimeNow()
				stand:SetAttribute("State", "HeavyPunch")
				stand:SetAttribute("StateStarted", started)
				task.delay(0.45, function()
					if stand.Parent and stand:GetAttribute("StateStarted") == started then
						stand:SetAttribute("State", "Idle")
						stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
					end
				end)
			end
			local pos = target.root and target.root.Position or attackerRoot.Position
			impactFX(pos, spellColor(counter.standDef, move), 12, 1.3)
			floatingText(pos, "COUNTER!", spellColor(counter.standDef, move))
		end
		return 0
	end

	local state = defender and blockState[defender]
	if not state then return amount end
	local root = target.root
	local attackerRoot = caster and caster:FindFirstChild("HumanoidRootPart")
	if not root or not attackerRoot then return amount end
	local toAttacker = attackerRoot.Position - root.Position
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if toAttacker.Magnitude < 0.1 or look.Magnitude < 0.1 then return amount end
	if look.Unit:Dot(toAttacker.Unit) < BLOCK_FRONT_DOT then
		return amount -- frappé de dos ou de côté : la garde ne sert à rien
	end

	if os.clock() - state.started <= PARRY_WINDOW then
		-- PARADE PARFAITE
		target.guarded = "parry"
		local attacker = Players:GetPlayerFromCharacter(caster)
		local attackerHumanoid = caster:FindFirstChildOfClass("Humanoid")
		if attackerHumanoid then
			stunTargets({ { model = caster, humanoid = attackerHumanoid, root = attackerRoot } }, PARRY_ATTACKER_STUN)
		end
		if attacker and activeBarrages[attacker.UserId] then
			finishBarrage(attacker, activeBarrages[attacker.UserId], true)
		end
		state.started = -math.huge -- une seule parade parfaite par garde
		impactFX(root.Position, GOLD, 12, 1.5)
		guardSound(root.Position, "rbxasset://sounds/electronicpingshort.wav", 1.4)
		floatingText(root.Position, "PARRY!", GOLD)
		return 0
	end

	-- GARDE
	target.guarded = "block"
	-- Le barrage (et son coup final) ne vide pas la jauge de garde
	local drainsGuard = kind ~= "barrage" and kind ~= "final"
	if drainsGuard then
		guardUsedAt[defender] = os.clock()
	end
	-- Petit éclat sur la garde (limité pour ne pas en mettre partout pendant
	-- un barrage)
	if os.clock() - (blockFxAt[defender] or 0) > 0.15 then
		blockFxAt[defender] = os.clock()
		impactFX(root.Position + toAttacker.Unit * 1.5, Color3.fromRGB(210, 215, 235), 4, 1.8)
	end
	if drainsGuard then
		setGuard(defender, guardOf(defender) - amount)
	end
	if guardOf(defender) <= 0 then
		-- GARDE BRISÉE
		stopBlock(defender)
		target.guarded = nil
		stunTargets({ target }, GUARD_BREAK_STUN)
		target.guarded = "block" -- pas de recul en plus
		impactFX(root.Position, Color3.fromRGB(255, 70, 60), 10, 0.6)
		guardSound(root.Position, "rbxasset://sounds/glassbreak.wav", 1)
		floatingText(root.Position, "GUARD BREAK!", Color3.fromRGB(255, 80, 70))
	end
	return amount * BLOCK_DAMAGE_TAKEN
end

-- Recharge de la jauge hors de la garde
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		if not blockState[player] and now - (guardUsedAt[player] or 0) >= GUARD_REGEN_DELAY then
			local value = guardOf(player)
			if value < GUARD_MAX then
				setGuard(player, value + GUARD_REGEN * dt)
			end
		end
	end
end)

local function onGuardPlayer(player)
	setGuard(player, GUARD_MAX)
	player.CharacterAdded:Connect(function(character)
		stopBlock(player)
		setGuard(player, GUARD_MAX)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				stopBlock(player)
			end)
		end
	end)
end
Players.PlayerAdded:Connect(onGuardPlayer)
for _, player in Players:GetPlayers() do
	onGuardPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	blockState[player] = nil
	blockReadyAt[player] = nil
	guardValue[player] = nil
	guardUsedAt[player] = nil
	blockFxAt[player] = nil
end)

local toggleAt = {}

-- Random stand pick for Stand Arrow pickups. Time-reality stands (The World,
-- King Crimson, Made in Heaven) are rarer than the rest.
local RARE_STANDS = { TheWorld = true, KingCrimson = true, MadeInHeaven = true }

local function pickRandomStand()
	local pool = {}
	local total = 0
	for id, def in pairs(StandData.Stands) do
		-- Stands marked ArrowObtainable = false (e.g. Gold Experience Requiem)
		-- never come out of a Stand Arrow.
		if def.ArrowObtainable ~= false then
			local weight = RARE_STANDS[id] and 1 or 3
			table.insert(pool, { id = id, weight = weight })
			total += weight
		end
	end
	local roll = math.random() * total
	for _, entry in ipairs(pool) do
		roll -= entry.weight
		if roll <= 0 then return entry.id end
	end
	return pool[#pool].id
end

-- ==================== STAND PERSISTENCE (DataStore) ====================
-- A player's Stand (or standless state) survives rejoining. Saved whenever
-- the stand changes and on leave/shutdown; loaded before the first summon.
local DataStoreService = game:GetService("DataStoreService")
local standStore
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerStands_v1")
	end)
	if ok then
		standStore = result
	else
		warn("[StandService] DataStore unavailable: " .. tostring(result))
	end
end

local function saveStandData(player)
	if not standStore then return end
	local data = player:GetAttribute("Standless")
		and { Standless = true }
		or { StandId = player:GetAttribute("StandId") }
	local ok, err = pcall(function()
		standStore:SetAsync("Stand_" .. player.UserId, data)
	end)
	if ok then
		print("[StandService] Saved stand data for", player.Name)
	else
		warn("[StandService] Failed to save stand for", player.Name, err)
	end
end

local function loadStandData(player)
	if not standStore then return end
	local ok, data = pcall(function()
		return standStore:GetAsync("Stand_" .. player.UserId)
	end)
	if not ok then
		warn("[StandService] Failed to load stand for", player.Name, data)
		return
	end
	if type(data) ~= "table" then return end
	if data.Standless then
		player:SetAttribute("Standless", true)
	elseif typeof(data.StandId) == "string" and StandData.GetStand(data.StandId) then
		player:SetAttribute("StandId", data.StandId)
	end
	print("[StandService] Loaded stand data for", player.Name,
		data.Standless and "(standless)" or ("StandId=" .. tostring(data.StandId)))
end

-- Stand travel jump: pressing Z flings the player up and forward along
-- their look direction for fast travel. Stand-agnostic, so it
-- lives outside the per-stand Moves tables. Launch power is tuned on the
-- client (it owns the character's physics); the server owns the rate limit.
local STAND_JUMP_COOLDOWN = 3

-- ==================== MENU DES STANDS (admins) ====================
-- Les admins peuvent prendre n'importe quel Stand via le menu (StandMenu).
-- Le serveur vérifie lui-même qui est admin : un joueur normal ne peut pas
-- changer de Stand, même en trichant.
-- Le mieux est de mettre les UserId (ils ne changent jamais, contrairement
-- aux pseudos). UserId : roblox.com/users/<UserId>/profile
local STAND_ADMIN_IDS = {
	-- [123456789] = true,
}
local STAND_ADMIN_NAMES = {
	["mamamzeze"] = true, -- en minuscules
}
-- Le créateur du jeu est admin automatiquement.
local CREATOR_IS_ADMIN = true
local CHOOSE_STAND_COOLDOWN = 1

local function isStandAdmin(player)
	if STAND_ADMIN_IDS[player.UserId] then return true end
	if STAND_ADMIN_NAMES[string.lower(player.Name)] then return true end
	if CREATOR_IS_ADMIN and game.CreatorType == Enum.CreatorType.User
		and player.UserId == game.CreatorId then
		return true
	end
	return false
end

local function markStandAdmin(player)
	player:SetAttribute("StandAdmin", isStandAdmin(player) or nil)
end
Players.PlayerAdded:Connect(markStandAdmin)
for _, player in Players:GetPlayers() do
	markStandAdmin(player)
end
local chooseStandAt = {}
Players.PlayerRemoving:Connect(function(player)
	chooseStandAt[player.UserId] = nil
end)

standAction.OnServerEvent:Connect(function(player, actionName, ...)
	if actionName == "ChooseStand" then
		if not isStandAdmin(player) then
			warn("[StandService] ChooseStand refusé (pas admin) :", player.Name)
			return
		end
		local nowChoose = os.clock()
		if (chooseStandAt[player.UserId] or 0) + CHOOSE_STAND_COOLDOWN > nowChoose then return end
		chooseStandAt[player.UserId] = nowChoose
		local args = { ... }
		local standId = tostring(args[1])
		print("[StandService] ChooseStand received:", standId)
		local def = StandData.GetStand(standId)
		if not def then
			warn("[StandService] ChooseStand rejected unknown id:", standId)
			return
		end
		if player:GetAttribute("StandId") == standId
			and workspace:FindFirstChild(player.Name .. "Stand") then
			return
		end
		player:SetAttribute("Standless", nil)
		player:SetAttribute("StandId", standId)
		removeStand(player)
		giveStand(player)
		saveStandData(player)
		print("[StandService]", player.Name, "chose", def.DisplayName)
		return
	end

	if actionName == "Block" then
		-- true = lever la garde, false = baisser, rien = basculer (mobile)
		local wanted = (...)
		if wanted == nil then wanted = not blockState[player] end
		if wanted == true then
			startBlock(player)
		else
			stopBlock(player)
		end
		return
	end
	if blockState[player] then return end -- pas d'attaque pendant la garde

	-- Pas d'attaque si on vient de prendre un coup, si on est étourdi par un
	-- sort ou figé par un arrêt du temps
	if hitstunUntil[player] and hitstunUntil[player] > os.clock() then return end
	local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if myHumanoid and spellStuns[myHumanoid] then return end
	if frozen[player] then return end

	if actionName == "Toggle" then
		local now = os.clock()
		if (toggleAt[player.UserId] or 0) + 0.75 > now then return end
		toggleAt[player.UserId] = now
		if workspace:FindFirstChild(player.Name .. "Stand") then
			removeStand(player)
			print("[StandService] Stand removed for", player.Name)
		else
			giveStand(player)
			print("[StandService] Stand deployed for", player.Name)
		end
		return
	end

	local stand = workspace:FindFirstChild(player.Name .. "Stand")
	if not stand or stand:GetAttribute("Owner") ~= player.UserId then
		return
	end
	-- YBA barrage hold protocol: E key-UP (holding == false) ends the active
	-- barrage early and charges the cooldown from that moment. The cooldown
	-- itself is stamped in finishBarrage, so Barrage skips the start stamp.
	print("[BarrageDebug] action:", actionName, "arg1:", select(1, ...))
	if actionName == "Barrage" and select("#", ...) > 0 and select(1, ...) == false then
		local session = activeBarrages[player.UserId]
		if session then
			finishBarrage(player, session, true)
		end
		return
	end
	-- V8: reject attacks while any move is already running. Previously,
	-- another Barrage could pass cooldown while the previous runBarrage task
	-- was still alive; the server then left the Stand punching indefinitely.
	if activeBarrages[player.UserId] then return end

	-- Stand travel jump: pure movement, so it is allowed during HeavyPunch /
	-- TimeStop states too — only an active barrage blocks it. The airborne
	-- feel-check is client-side; the server owns the cooldown.
	if actionName == "StandJump" then
		local now = os.clock()
		local bucket = lastUse[player.UserId] or {}
		if (bucket.StandJump or 0) + STAND_JUMP_COOLDOWN > now then
			standFX:FireClient(player, "MoveDenied", "StandJump", (bucket.StandJump or 0) + STAND_JUMP_COOLDOWN - now)
			return
		end
		lastUse[player.UserId] = bucket
		bucket.StandJump = now
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then return end
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		-- The impulse itself is applied by the firing client: the player owns
		-- their character's physics, so a server-side velocity write loses the
		-- replication race and gets clobbered the same frame. The server still
		-- owns the cooldown, the stand FX and the audit print.
		pulseGlow(stand)
		local whoosh = Instance.new("Sound")
		whoosh.SoundId = "rbxasset://sounds/swordslash.wav"
		whoosh.Volume = 0.7
		whoosh.PlaybackSpeed = 0.75
		whoosh.RollOffMaxDistance = 90
		whoosh.Parent = stand.PrimaryPart
		whoosh:Play()
		whoosh.Ended:Once(function() whoosh:Destroy() end)
		-- The stand soars with the player: a real state drives the arms-spread
		-- flight pose on every client through the usual clip pipeline, and the
		-- state lapses when the player lands (with a fallback in case the
		-- Landed signal is never delivered, e.g. death mid-flight).
		stand:SetAttribute("State", "StandJump")
		stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
		local function restoreIdle()
			if stand.Parent and stand:GetAttribute("State") == "StandJump" then
				stand:SetAttribute("State", "Idle")
				stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			end
		end
		-- Restore the normal pose as soon as the player is grounded again.
		-- The Landed state is not guaranteed here: a fast forward landing can
		-- go Freefall -> Running without ever firing Landed, which left the
		-- stand frozen in the flight pose. Poll real floor contact instead —
		-- first wait until the player leaves the ground, then until they
		-- touch down again.
		task.spawn(function()
			local deadline = os.clock() + 10
			while os.clock() < deadline and stand.Parent and humanoid.Parent and humanoid.Health > 0 do
				if humanoid.FloorMaterial == Enum.Material.Air then break end
				task.wait(0.05)
			end
			while os.clock() < deadline and stand.Parent and humanoid.Parent and humanoid.Health > 0 do
				if humanoid.FloorMaterial ~= Enum.Material.Air then break end
				task.wait(0.05)
			end
			restoreIdle()
		end)
		print("[StandService] StandJump for", player.Name)
		return
	end

	-- M1 light punch: fast alternating jab. Allowed from Idle or while
	-- chaining light punches; every other running move blocks it. The
	-- cooldown itself spaces rapid clicks.
	if actionName == "LightPunch" then
		local standDef = StandData.GetStand(stand:GetAttribute("StandId"))
		local move = standDef and standDef.Moves.LightPunchR
		if not move then return end
		local state = stand:GetAttribute("State")
		if state ~= "Idle" and state ~= "LightPunchR" and state ~= "LightPunchL" then return end
		lastUse[player.UserId] = lastUse[player.UserId] or {}
		local now = os.clock()
		local uid = player.UserId
		local previousPunch = lastUse[uid].LightPunch or 0
		if previousPunch + move.Cooldown > now then return end
		if (m1BlockedUntil[uid] or 0) > now then return end
		lastUse[uid].LightPunch = now
		-- The server owns the combo so all clients see the same fist fly.
		-- A pause restarts the combo on the right hand.
		if now - previousPunch > M1_COMBO_RESET then
			m1Combo[uid] = 0
		end
		m1Combo[uid] = (m1Combo[uid] or 0) + 1

		if m1Combo[uid] >= (move.ComboLength or 4) then
			m1Combo[uid] = 0
			m1BlockedUntil[uid] = now + (move.FinisherEndLag or 1)
			runComboFinisher(player, stand, standDef, move)
			return
		end

		local hand = (m1Combo[uid] % 2 == 1) and "R" or "L"
		local punchStarted = workspace:GetServerTimeNow()
		stand:SetAttribute("State", "LightPunch" .. hand)
		stand:SetAttribute("StateStarted", punchStarted)
		-- Stand cry on every M1 jab: a short one-shot of the stand's barrage
		-- voice (stopped early so the full barrage loop never runs over jabs).
		-- Stands without a barrage voice (no clip in the pack) stay silent.
		local crySource = standDef.BarrageVoicePath and resolveVoice(standDef.BarrageVoicePath)
		local cryTorso = stand:FindFirstChild("Torso") or stand:FindFirstChild("UpperTorso")
		if crySource and cryTorso then
			local cry = crySource:Clone()
			cry.Name = "PunchCry"
			cry.Looped = false
			cry.Volume = 1.2
			cry.PlaybackSpeed = 0.95 + math.random() * 0.2
			cry.RollOffMaxDistance = 120
			cry.Parent = cryTorso -- Sounds only play on a BasePart, not the Model
			cry:Play()
			task.delay(0.45, function()
				if cry.Parent then
					cry:Stop()
					cry:Destroy()
				end
			end)
		end
		task.delay(0.16, function()
			if not stand.Parent then return end
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			local targets = getTargets(player, hrp.CFrame, move.BoxSize, move.Range)
			dealDamage(targets, move.Damage, character, nil, "light")
			if #targets > 0 then
				local hitPos = targets[1].root and targets[1].root.Position
					or (hrp.CFrame * CFrame.new(0, 0, -move.Range / 2)).Position
				impactFX(hitPos, PURPLE, 8, 1.5)
				local torso = stand:FindFirstChild("Torso") or stand:FindFirstChild("UpperTorso")
				local sfx = torso and torso:FindFirstChild(hand == "R" and "BarrageHit" or "BarrageHitAlt")
				if sfx then sfx:Play() end
			end
		end)
		-- Le Stand reste en garde (fin de l'animation du coup) jusqu'au coup
		-- suivant au lieu de repasser en pose d'attente entre deux M1 ; on ne
		-- revient au repos que si aucun autre coup n'a commencé entre-temps.
		task.delay(move.Cooldown + M1_HOLD_AFTER, function()
			if stand.Parent and stand:GetAttribute("StateStarted") == punchStarted then
				stand:SetAttribute("State", "Idle")
				stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			end
		end)
		return
	end

	if stand:GetAttribute("State") ~= "Idle" then return end
	-- Les coups M1 passent uniquement par "LightPunch" (plus haut) : sans ça,
	-- envoyer "LightPunchR" bloquait le Stand dans cet état pour toujours.
	if actionName == "LightPunchR" or actionName == "LightPunchL" then return end
	local standDef = StandData.GetStand(stand:GetAttribute("StandId"))
	local move = standDef and standDef.Moves[actionName]
	if not move then return end

	lastUse[player.UserId] = lastUse[player.UserId] or {}
	local now = os.clock()
	local readyAt = (lastUse[player.UserId][actionName] or 0) + move.Cooldown
	if readyAt > now then
		print("[BarrageDebug] denied", actionName, "remaining", readyAt - now, "lastUse", lastUse[player.UserId][actionName])
		standFX:FireClient(player, "MoveDenied", actionName, readyAt - now)
		return
	end
	if actionName ~= "Barrage" then
		lastUse[player.UserId][actionName] = now
	end
	standFX:FireClient(player, "MoveStarted", actionName, move.Cooldown)

	stand:SetAttribute("State", actionName)
	stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())

	if actionName == "Barrage" then
		if not runBarrage(player, stand, move) then
			-- Defensive fallback: never leave the state stuck on Barrage.
			stand:SetAttribute("State", "Idle")
			stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
		end
	elseif actionName == "HeavyPunch" then
		runHeavy(player, stand, move)
		task.delay(0.45, function()
			if stand.Parent and stand:GetAttribute("State") == "HeavyPunch" then
				stand:SetAttribute("State", "Idle")
				stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			end
		end)
	elseif actionName == "Heal" then
		-- The channel lands when the bent-arm pose completes, not at trigger.
		task.delay(0.4, function()
			if stand.Parent and stand:GetAttribute("State") == "Heal" then
				runHeal(player, stand, move)
			end
		end)
		task.delay(move.Duration or 1.3, function()
			if stand.Parent and stand:GetAttribute("State") == "Heal" then
				stand:SetAttribute("State", "Idle")
				stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			end
		end)
	elseif actionName == "TimeStop" then
		runTimeStop(player, stand, move)
		task.delay(move.Duration, function()
			if stand.Parent and stand:GetAttribute("State") == "TimeStop" then
				stand:SetAttribute("State", "Idle")
				stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			end
		end)
	elseif move.Type then
		-- Attaques T / F / G (StandSpells) ; 1er argument = point visé
		runSpell(player, stand, standDef, move, (...), actionName)
		task.delay(move.Duration or 0.6, function()
			if stand.Parent and stand:GetAttribute("State") == actionName then
				stand:SetAttribute("State", "Idle")
				stand:SetAttribute("StateStarted", workspace:GetServerTimeNow())
			end
		end)
	end
end)

-- V9 emergency watchdog: independent of the barrage damage coroutine.
-- If any scheduled callback is missed, the server still forces Idle, which
-- stops BOTH the damage authorization and the clients' visual barrage.
local barrageWatchdogAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	barrageWatchdogAccumulator += dt
	if barrageWatchdogAccumulator < 0.15 then return end
	barrageWatchdogAccumulator = 0
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local session = activeBarrages[userId]
		if session and now >= (session.deadline + 0.15) then
			finishBarrage(player, session, false)
		end
		local stand = workspace:FindFirstChild(player.Name .. "Stand")
		if stand and stand:GetAttribute("State") == "Barrage" then
			local endsAt = stand:GetAttribute("BarrageEndsAt")
			if typeof(endsAt) ~= "number" or endsAt <= 0 then
				local def = StandData.GetStand(stand:GetAttribute("StandId"))
				local move = def and def.Moves and def.Moves.Barrage
				endsAt = (stand:GetAttribute("StateStarted") or now) + (move and move.Duration or 3.6)
			end
			if now >= endsAt + 0.15 then
				local stillActive = activeBarrages[userId]
				if stillActive and stillActive.stand == stand then
					finishBarrage(player, stillActive, false)
				end
				if stand.Parent and stand:GetAttribute("State") == "Barrage" then
					warn("[StandService V9] Forced a stale barrage to Idle for", player.Name)
					stand:SetAttribute("State", "Idle")
					stand:SetAttribute("StateStarted", now)
					stand:SetAttribute("BarrageEndsAt", 0)
				end
			end
		end
	end
end)

-- The World gets its own imported look: clone the raw Toolbox model, rename
-- its "Stand *"-prefixed rig parts to the standard R6 names every clip/FX
-- expects, and mark it NativeColors so the legacy palette recolor skips it.
local function buildTheWorldTemplate()
	local existing = ReplicatedStorage:FindFirstChild("TheWorldTemplate")
	if existing then return existing end
	local source = ServerStorage:FindFirstChild("TheWorldModel")
	if not source then
		warn("[StandService] Missing ServerStorage/TheWorldModel")
		return nil
	end
	local model = source:Clone()
	model.Name = "TheWorldTemplate"
	for oldName, newName in pairs({
		StandHumanoidRootPart = "HumanoidRootPart",
		["Stand Torso"] = "Torso",
		["Stand Head"] = "Head",
		["Stand Left Arm"] = "Left Arm",
		["Stand Right Arm"] = "Right Arm",
		["Stand Left Leg"] = "Left Leg",
		["Stand Right Leg"] = "Right Leg",
	}) do
		local part = model:FindFirstChild(oldName)
		if part then
			part.Name = newName
		else
			warn("[StandService] TheWorldModel rig part missing:", oldName)
		end
	end
	model:SetAttribute("NativeColors", true)
	model.Parent = ReplicatedStorage
	return model
end

-- Imported stands keep their own finished look. Gold Experience and Killer
-- Queen ship the same complete R15-style rig as King Crimson (LowerTorso/
-- UpperTorso/... with Motor6Ds named Root, Waist, Neck, RightShoulder, ...)
-- matching the R15 clip tables, so the rig is kept as-is. Legacy pose-lock
-- welds between rig parts (e.g. hands welded together in the iconic pose)
-- are removed so the motors can articulate; decorative meshes keep their
-- welds. Made in Heaven is an R6-style rig (RootJoint/Shoulders/Neck) whose
-- welds are all decorative, so nothing is stripped there.
local R15_RIG_PARTS = {
	HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

-- Imported sculptures name their rig parts with a "Stand" prefix
-- ("Stand Torso", "StandHumanoidRootPart", ...); rename them to the standard
-- R6 names every clip/FX attachment point expects.
local STAND_RIG_RENAMES = {
	StandHumanoidRootPart = "HumanoidRootPart",
	["Stand Torso"] = "Torso",
	["Stand Head"] = "Head",
	["Stand Left Arm"] = "Left Arm",
	["Stand Right Arm"] = "Right Arm",
	["Stand Left Leg"] = "Left Leg",
	["Stand Right Leg"] = "Right Leg",
}

local function buildImportedStandTemplate(sourceName, templateName, rigParts, renameRig)
	local existing = ReplicatedStorage:FindFirstChild(templateName)
	if existing then return existing end
	local source = ServerStorage:FindFirstChild(sourceName)
	if not source then
		warn("[StandService] Missing ServerStorage/" .. sourceName)
		return nil
	end
	local model = source:Clone()
	model.Name = templateName
	if renameRig then
		for oldName, newName in pairs(STAND_RIG_RENAMES) do
			local part = model:FindFirstChild(oldName)
			if part then
				part.Name = newName
			else
				warn("[StandService] " .. sourceName .. " rig part missing:", oldName)
			end
		end
	end
	if rigParts then
		for _, joint in model:GetDescendants() do
			if (joint:IsA("Weld") or joint:IsA("ManualWeld")) and joint.Part0 and joint.Part1
				and rigParts[joint.Part0.Name] and rigParts[joint.Part1.Name] then
				joint:Destroy()
			end
		end
	end
	model:SetAttribute("NativeColors", true)
	model.Parent = ReplicatedStorage
	return model
end

local theWorldTemplate = buildTheWorldTemplate()
if theWorldTemplate then
	setupTemplate(theWorldTemplate)
end
for _, imported in ipairs({
	{ source = "KingCrimsonModel", template = "KingCrimsonTemplate", rigParts = R15_RIG_PARTS },
	{ source = "GoldExperienceModel", template = "GoldExperienceTemplate", rigParts = R15_RIG_PARTS },
	{ source = "KillerQueenModel", template = "KillerQueenTemplate", rigParts = R15_RIG_PARTS },
	{ source = "MadeInHeavenModel", template = "MadeInHeavenTemplate", rigParts = nil },
	{ source = "TheWorldAUModel", template = "TheWorldAUTemplate", rigParts = nil },
	{ source = "StickyFingersModel", template = "StickyFingersTemplate", rigParts = R15_RIG_PARTS },
	{ source = "CrazyDiamondModel", template = "CrazyDiamondTemplate", rigParts = R15_RIG_PARTS },
	{ source = "SilverChariotModel", template = "SilverChariotTemplate", rigParts = R15_RIG_PARTS },
	{ source = "HierophantGreenModel", template = "HierophantGreenTemplate", rigParts = R15_RIG_PARTS },
	{ source = "MagicianRedModel", template = "MagicianRedTemplate", rigParts = nil },
	{ source = "GoldExperienceRequiemModel", template = "GoldExperienceRequiemTemplate", rigParts = R15_RIG_PARTS },
}) do
	local importedTemplate = buildImportedStandTemplate(imported.source, imported.template, imported.rigParts, imported.renameRig)
	if importedTemplate then
		-- R6-style imports parent their Neck motor away from the Torso;
		-- keep it on the Torso so setupTemplate's neck-pin check sees it and
		-- does not create a second competing Head driver.
		local r6Torso = importedTemplate:FindFirstChild("Torso")
		if r6Torso then
			local neck = importedTemplate:FindFirstChild("Neck", true)
			if neck and neck:IsA("Motor6D") and neck.Parent ~= r6Torso then
				neck.Parent = r6Torso
			end
		end
		setupTemplate(importedTemplate)
	end
end
setupTemplate(ReplicatedStorage:WaitForChild("StarPlatinumTemplate"))

Players.PlayerAdded:Connect(function(player)
	loadStandData(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		giveStand(player)
	end)
	-- Deploy here only when the character already exists; otherwise the
	-- CharacterAdded handler above performs the single auto-summon. Running
	-- both paths used to deploy twice at join and double-played the summon
	-- voice line.
	if player.Character then
		giveStand(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeStand(player)
	saveStandData(player)
	lastUse[player.UserId] = nil
	toggleAt[player.UserId] = nil
	m1Combo[player.UserId] = nil
	m1BlockedUntil[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveStandData(player)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		loadStandData(player)
		giveStand(player)
	end)
end

-- ==================== MAP SPAWNED ITEMS ====================
-- Stand Arrows appear around the map every 15s; touching one pierces the
-- player with a random stand. Rokakaka fruit erases the holder's stand.
local ITEM_INTERVAL = 15
local MAX_ARROWS = 6
local MAX_FRUITS = 6
local MAX_REQUIEM_ARROWS = 1
local REQUIEM_INTERVAL = 300 -- Requiem Arrows roll a spawn every 5 minutes
local REQUIEM_CHANCE = 1 / 3 -- ...and only 1 in 3 rolls actually spawns one
local ITEM_LIFETIME = 240

local itemFolder = Instance.new("Folder")
itemFolder.Name = "StandItems"
itemFolder.Parent = workspace

-- MapBuilder places/moves the map concurrently, so resolve the bounding box
-- lazily. MapBuilder parents a SpawnPads folder into the map only after the
-- map is positioned, which is our "map is ready" signal.
local itemMap = nil
local mapCF, mapSize, floorY
local spawnPoints = {}

local itemRay = RaycastParams.new()
itemRay.FilterType = Enum.RaycastFilterType.Include

local function refreshMapInfo()
	if mapCF then return true end
	itemMap = itemMap or workspace:FindFirstChild("OLD A BIZARRE DAY")
	if not itemMap or not itemMap:FindFirstChild("SpawnPads") then
		return false
	end
	mapCF, mapSize = itemMap:GetBoundingBox()
	local organs = itemMap:FindFirstChild("MapOrgans")
	local floorPart = organs and organs:FindFirstChild("Floor")
	floorY = floorPart and floorPart.Position.Y or mapCF.Position.Y
	itemRay.FilterDescendantsInstances = { itemMap }

	-- Four fixed spawn zones: the landmarks MapBuilder padded (Town Plaza,
	-- Arena, Main Street, Dio's Coffin). Items scatter around each pad.
	local pads = itemMap:FindFirstChild("SpawnPads")
	if pads then
		for _, pad in pads:GetChildren() do
			if pad:IsA("SpawnLocation") then
				table.insert(spawnPoints, pad.Position)
			end
		end
	end
	print("[StandItems] Map ready:", mapCF.Position, "size", mapSize, "| spawn points:", #spawnPoints)
	return true
end

-- Spot near one of the fixed spawn points (reject rooftops: must be near
-- floor level). Tries each point once per call before giving up.
local function findGroundSpot()
	if not refreshMapInfo() or #spawnPoints == 0 then return nil end
	local start = math.random(#spawnPoints)
	for i = 0, #spawnPoints - 1 do
		local base = spawnPoints[(start + i - 1) % #spawnPoints + 1]
		local angle = math.rad(math.random() * 360)
		local dist = 12 + math.random() * 8
		local x = base.X + math.cos(angle) * dist
		local z = base.Z + math.sin(angle) * dist
		local hit = workspace:Raycast(Vector3.new(x, base.Y + 30, z), Vector3.new(0, -150, 0), itemRay)
		if hit and hit.Position.Y < floorY + 6 then
			return Vector3.new(x, hit.Position.Y, z)
		end
	end
	return nil
end

local ServerStorage = game:GetService("ServerStorage")
local arrowTemplate = ServerStorage:WaitForChild("StandArrowModel")
local fruitTemplate = ServerStorage:WaitForChild("RokakakaModel")
local requiemTemplate = ServerStorage:FindFirstChild("RequiemArrowModel")
if not requiemTemplate then
	warn("[StandItems] Missing ServerStorage/RequiemArrowModel; Requiem Arrow disabled")
end
local REQUIEM_SCALE = 2 -- imported mesh is real-arrow scale; enlarge for map visibility
local GripUtil = require(ReplicatedStorage:WaitForChild("GripUtil"))

-- Inventory versions: what actually lands in the player's Backpack when a
-- map item is collected. Using an item goes through StandAction
-- ("UseArrow" / "UseRokakaka"), never through touching the map prop.
local function weldLooseParts(tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end
	-- An anchored Handle welds the character to a static part the instant the
	-- tool auto-equips, freezing the player in place. Every tool part must be
	-- unanchored, massless and non-collidable.
	handle.Anchored, handle.CanCollide, handle.Massless = false, false, true
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle then
			p.Anchored, p.CanCollide, p.Massless = false, false, true
			if p.AssemblyRootPart ~= handle.AssemblyRootPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = handle, p, p
			end
		end
	end
end

local function buildArrowTool()
	local tool = arrowTemplate:Clone()
	tool.Name = "StandArrow"
	tool.ToolTip = "Stand Arrow - activates a random Stand (won't work if you already have one)"
	tool.CanBeDropped = false
	weldLooseParts(tool)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		tool.Grip = GripUtil.buildGrip(handle, "axe")
	end
	return tool
end

local function buildRokakakaTool()
	local source = fruitTemplate:FindFirstChildWhichIsA("MeshPart")
	local tool = Instance.new("Tool")
	tool.Name = "Rokakaka"
	tool.ToolTip = "Rokakaka - erases your current Stand"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = source:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	local biggest = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z)
	handle.Size = handle.Size * (1.1 / biggest)
	handle.Parent = tool
	tool.Grip = GripUtil.buildGrip(handle, "axe")
	return tool
end

local function biggestPart(model)
	local best, bestVol = nil, 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local vol = part.Size.X * part.Size.Y * part.Size.Z
			if vol > bestVol then
				bestVol = vol
				best = part
			end
		end
	end
	return best
end

local function buildRequiemArrowTool()
	if not requiemTemplate then return buildArrowTool() end
	local source = requiemTemplate:Clone()
	source:ScaleTo(REQUIEM_SCALE)
	local tool = Instance.new("Tool")
	tool.Name = "RequiemArrow"
	tool.ToolTip = "Requiem Arrow - awakens a Requiem Stand the normal Arrows can never grant"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = biggestPart(source)
	for _, child in ipairs(source:GetChildren()) do
		child.Parent = tool
	end
	source:Destroy()
	if handle then
		handle.Name = "Handle"
		weldLooseParts(tool)
		tool.Grip = GripUtil.buildGrip(handle, "axe")
	end
	return tool
end

local function giveItemTool(player, kind)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	local tool = kind == "Arrow" and buildArrowTool()
		or kind == "RequiemArrow" and buildRequiemArrowTool()
		or buildRokakakaTool()
	tool.Parent = backpack
end

local function prepareItemParts(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
end

local function buildArrowItem()
	-- Rebuild the cloned Tool as a plain Model. A Tool sitting in Workspace is
	-- auto-grabbed by Roblox's built-in touch pickup, which pulls its ANCHORED
	-- Handle into the touching character and trips/freezes them.
	local source = arrowTemplate:Clone()
	local model = Instance.new("Model")
	model.Name = "StandArrow"
	for _, child in ipairs(source:GetChildren()) do
		child.Parent = model
	end
	source:Destroy()
	prepareItemParts(model)
	local shaft = model:FindFirstChild("Handle")
	if shaft then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 200, 80)
		glow.Range = 10
		glow.Brightness = 1.4
		glow.Parent = shaft

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 214, 110))
		sparkle.Rate = 10
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.25)
		sparkle.Transparency = NumberSequence.new(0.2, 1)
		sparkle.LightEmission = 1
		sparkle.Parent = shaft
	end
	return model
end

local function buildRokakakaItem()
	local model = fruitTemplate:Clone()
	model.Name = "Rokakaka"
	prepareItemParts(model)
	local fruit = model:FindFirstChildWhichIsA("MeshPart")
	if fruit then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(120, 255, 120)
		glow.Range = 8
		glow.Brightness = 1
		glow.Parent = fruit
	end
	return model
end

local function buildRequiemArrowItem()
	if not requiemTemplate then return buildArrowItem() end
	local source = requiemTemplate:Clone()
	source:ScaleTo(REQUIEM_SCALE)
	local model = Instance.new("Model")
	model.Name = "RequiemArrow"
	for _, child in ipairs(source:GetChildren()) do
		child.Parent = model
	end
	source:Destroy()
	prepareItemParts(model)
	local anchor = biggestPart(model)
	if anchor then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(190, 255, 160)
		glow.Range = 10
		glow.Brightness = 1.4
		glow.Parent = anchor

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(Color3.fromRGB(190, 255, 160), Color3.fromRGB(255, 224, 130))
		sparkle.Rate = 12
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.25)
		sparkle.Transparency = NumberSequence.new(0.2, 1)
		sparkle.LightEmission = 1
		sparkle.Parent = anchor
	end
	return model
end

-- Gentle bob + spin for every live item (one shared Heartbeat loop).
local spinBases = {}
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for item, base in pairs(spinBases) do
		if item.Parent then
			item:PivotTo(base
				* CFrame.new(0, math.sin(t * 2 + base.X * 0.7) * 0.22, 0)
				* CFrame.Angles(0, t * 1.6, 0))
		else
			spinBases[item] = nil
		end
	end
end)

local function consumeItem(item)
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.35), {
				Transparency = 1,
				CFrame = part.CFrame + Vector3.new(0, 3, 0),
			}):Play()
		end
	end
	task.delay(0.4, function() item:Destroy() end)
end

local function onItemTouched(item, kind, hit)
	if item:GetAttribute("Claimed") then return end
	local character = hit and hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	item:SetAttribute("Claimed", true)
	spinBases[item] = nil

	giveItemTool(player, kind)
	standAction:FireClient(player, "ItemPicked", kind)
	print("[StandItems]", player.Name, "collected a",
		kind == "Arrow" and "Stand Arrow"
		or kind == "RequiemArrow" and "Requiem Arrow" or "Rokakaka")

	consumeItem(item)
end

-- Item usage: the client fires these after the local confirmation UI (the
-- Rokakaka asks "are you sure?" before erasing). The server re-verifies tool
-- ownership instead of trusting the client.
local function useStandItem(player, kind)
	local toolName = kind == "Arrow" and "StandArrow"
		or kind == "RequiemArrow" and "RequiemArrow" or "Rokakaka"
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local tool = backpack and backpack:FindFirstChild(toolName)
		or (character and character:FindFirstChild(toolName))
	if not tool or not tool:IsA("Tool") then return end
	-- Items are locked while a trade session is open, so an offer can never
	-- be consumed out from under the deal mid-session.
	if player:GetAttribute("Trading") then
		standAction:FireClient(player, "ItemDenied", kind)
		return
	end
	if tool:GetAttribute("Consuming") then return end
	if kind == "Rokakaka" and player:GetAttribute("Standless") then
		standAction:FireClient(player, "ItemDenied", "Rokakaka")
		return
	end
	if kind == "RequiemArrow" then
		-- Requiem Arrows only respond to Gold Experience: they evolve it into
		-- Gold Experience Requiem rather than granting a stand from nothing.
		if player:GetAttribute("StandId") ~= "GoldExperience" then
			standAction:FireClient(player, "ItemDenied", "RequiemArrow")
			return
		end
	elseif kind ~= "Rokakaka" and not player:GetAttribute("Standless") then
		standAction:FireClient(player, "ItemDenied", kind)
		return
	end
	tool:SetAttribute("Consuming", true)

	if kind ~= "Rokakaka" then
		-- Keep the arrow in hand through the stab animation's plunge beat,
		-- then consume it. The requiem stab's plunge lands later, so the
		-- Requiem Arrow survives longer.
		task.delay(kind == "RequiemArrow" and 1.6 or 0.7, function()
			if tool and tool.Parent then tool:Destroy() end
		end)
	else
		tool:Destroy()
	end
	if kind == "Rokakaka" then
		player:SetAttribute("Standless", true)
		player:SetAttribute("StandId", nil)
		removeStand(player)
		saveStandData(player)
		standAction:FireClient(player, "StandPicked", "Rokakaka")
		print("[StandItems]", player.Name, "ate a Rokakaka; stand erased")
	else
		local standId
		if kind == "RequiemArrow" then
			-- The Requiem Arrow evolves the Gold Experience holding it into
			-- Gold Experience Requiem. The awakening burst lands on the stab
			-- animation's plunge beat (~1.0s in).
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local pos = root.Position
				task.delay(1.0, function()
					standFX:FireAllClients("RequiemAwaken", pos)
				end)
			end
			standId = "GoldExperienceRequiem"
		else
			standId = pickRandomStand()
		end
		local def = StandData.GetStand(standId)
		player:SetAttribute("Standless", nil)
		player:SetAttribute("StandId", standId)
		removeStand(player)
		giveStand(player)
		saveStandData(player)
		standAction:FireClient(player, "StandPicked", kind, standId)
		print("[StandItems]", player.Name, "used a", kind == "RequiemArrow" and "Requiem Arrow" or "Stand Arrow", "->", def and def.DisplayName or standId)
	end
end

standAction.OnServerEvent:Connect(function(player, actionName)
	if actionName == "UseArrow" then
		useStandItem(player, "Arrow")
	elseif actionName == "UseRequiemArrow" then
		useStandItem(player, "RequiemArrow")
	elseif actionName == "UseRokakaka" then
		useStandItem(player, "Rokakaka")
	end
end)

local function spawnItem(kind)
	local spot = findGroundSpot()
	if not spot then return end
	local model = kind == "Arrow" and buildArrowItem()
		or kind == "RequiemArrow" and buildRequiemArrowItem()
		or buildRokakakaItem()
	local baseCF = CFrame.new(spot + Vector3.new(0, 1.9, 0))
	model:PivotTo(baseCF)
	spinBases[model] = baseCF
	model.Parent = itemFolder

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				onItemTouched(model, kind, hit)
			end)
		end
	end

	task.delay(ITEM_LIFETIME, function()
		if model.Parent and not model:GetAttribute("Claimed") then
			spinBases[model] = nil
			model:Destroy()
		end
	end)
end

-- Seed the map immediately, then keep one Arrow + one Rokakaka spawning
-- every 30 seconds (capped so the map never floods).
task.spawn(function()
	local readyDeadline = os.clock() + 30
	while not refreshMapInfo() and os.clock() < readyDeadline do
		task.wait(0.5)
	end
	if not mapCF then
		warn("[StandItems] Map never became ready; item spawns disabled")
		return
	end
		for _ = 1, 2 do
			spawnItem("Arrow")
			spawnItem("Rokakaka")
		end
		print("[StandItems] Seeded arrows and rokakaka")
		while true do
			task.wait(ITEM_INTERVAL)
			local arrows, fruits = 0, 0
			for _, child in itemFolder:GetChildren() do
				if child.Name == "StandArrow" then
					arrows += 1
				elseif child.Name == "Rokakaka" then
					fruits += 1
				end
			end
			if arrows < MAX_ARROWS then spawnItem("Arrow") end
			if fruits < MAX_FRUITS then spawnItem("Rokakaka") end
		end
end)

-- Requiem Arrow cadence: every 5 minutes roll 1/3; only one may exist at a
-- time. Deliberately NOT seeded at startup - the first roll happens after
-- the first full 5-minute interval.
task.spawn(function()
	while true do
		task.wait(REQUIEM_INTERVAL)
		if math.random() <= REQUIEM_CHANCE then
			local requiems = 0
			for _, child in itemFolder:GetChildren() do
				if child.Name == "RequiemArrow" then
					requiems += 1
				end
			end
			if requiems < MAX_REQUIEM_ARROWS then
				spawnItem("RequiemArrow")
				print("[StandItems] Requiem Arrow spawned (1/3 roll hit)")
			end
		end
	end
end)

print("[StandService] Ready")
