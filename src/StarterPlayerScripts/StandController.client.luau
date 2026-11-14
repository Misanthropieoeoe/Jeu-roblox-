local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local StandStrikes = require(ReplicatedStorage:WaitForChild("StandStrikes"))
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")

local localPlayer = Players.LocalPlayer

-- Server mirrors per-stand voice clips from ServerStorage into
-- ReplicatedStorage/StandVoices/<StandId>/<Clip>; resolve their SoundIds.
local function resolveVoiceId(standId, clipName)
	local folder = ReplicatedStorage:FindFirstChild("StandVoices")
	local group = folder and folder:FindFirstChild(standId)
	local clip = group and group:FindFirstChild(clipName)
	if clip and clip:IsA("Sound") and clip.SoundId ~= "" then
		return clip.SoundId
	end
	return nil
end

local GOLD = Color3.fromRGB(255, 200, 80)
local BLOOD = Color3.fromRGB(255, 70, 60)

local animationsFolder = ReplicatedStorage:WaitForChild("Animations")
local STAND_CLIPS = {
	Barrage = { clip = require(animationsFolder:WaitForChild("StandBarrage")).Rigs.R6 },
	HeavyPunch = { clip = require(animationsFolder:WaitForChild("StandHeavyPunch")).Rigs.R6 },
	-- M1 coup léger : le serveur alterne main droite / main gauche (0.42 s).
	LightPunchR = { clip = require(animationsFolder:WaitForChild("Stand Right Punch")).Rigs.R6 },
	LightPunchL = { clip = require(animationsFolder:WaitForChild("Stand Left Punch")).Rigs.R6 },
	Deploying = { clip = require(animationsFolder:WaitForChild("StandSummon")).Rigs.R6 },
}

-- Coude pendant le coup léger (en radians, + = plié), en fonction du temps
-- depuis le début du coup. Le bras qui frappe s'arme (coude plié), se tend
-- d'un coup à l'impact (~0.16 s, moment où le serveur inflige les dégâts),
-- puis revient. L'autre bras reste plié en garde.
local JAB_ELBOW_KEYS = {
	{ 0.00, 0.15 },
	{ 0.09, 1.25 }, -- armement
	{ 0.17, 0.02 }, -- impact : bras tendu
	{ 0.28, 0.35 },
	{ 0.42, 0.15 },
}
local JAB_GUARD_ELBOW = 1.05

local function jabElbow(t)
	local keys = JAB_ELBOW_KEYS
	if t <= keys[1][1] then return keys[1][2] end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t < b[1] then
			local alpha = (t - a[1]) / (b[1] - a[1])
			-- ease in-out pour éviter un mouvement robotique
			alpha = alpha * alpha * (3 - 2 * alpha)
			return a[2] + (b[2] - a[2]) * alpha
		end
	end
	return keys[#keys][2]
end

-- V9: No independent Stepped loop: a clip is evaluated from the SERVER
-- action timestamp. This ensures that an old barrage cannot keep animating
-- after its action ends, even if a callback or animation release was missed.
local CLIP_FADE_IN = 0.07

local function collectJoints(model)
	local joints = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("Motor6D") and desc.Part1 then
			joints[desc.Part1.Name] = desc
		end
	end
	return joints
end

local function compileClip(clip)
	local timestamps, driven = {}, {}
	for when, frame in pairs(clip.Timestamps) do
		table.insert(timestamps, when)
		for partName in pairs(frame) do
			driven[partName] = true
		end
	end
	table.sort(timestamps)
	return {
		clip = clip,
		timestamps = timestamps,
		lastTime = timestamps[#timestamps] or 0,
		driven = driven,
	}
end

local compiledClips = {}
for key, entry in pairs(STAND_CLIPS) do
	compiledClips[key] = compileClip(entry.clip)
end

-- Attaques propres à chaque Stand (ReplicatedStorage.StandStrikes),
-- compilées pour le squelette réel du Stand (R6 ou R15) : M1, Heavy (R et
-- 4e coup du combo), Barrage (E), Time Stop (F, King Crimson / Made in
-- Heaven), Heal (T, GER) et pose d'attente des Stands R15 (les clips
-- d'origine sont en R6 et ne bougeaient rien sur un squelette R15).
-- Star Platinum garde toutes ses animations d'origine ; les autres Time Stop
-- gardent la pose "ZA WARUDO" codée plus bas.
local KEEP_ORIGINAL_STRIKES = { StarPlatinum = true }
local STATE_TO_STRIKE = {
	LightPunchR = "LightR",
	LightPunchL = "LightL",
	HeavyPunch = "Heavy",
	Barrage = "Barrage",
	TimeStop = "TimeStop",
	Heal = "Heal",
}

local function getStrikeClip(stand, rig, state)
	local standId = stand:GetAttribute("StandId")
	if not standId then return nil end
	local kind = STATE_TO_STRIKE[state]
	if not kind and (state == "Idle" or state == "Pose") and rig.joints.UpperTorso then
		kind = "Idle" -- les Stands R15 n'ont pas de pose d'attente codée
	end
	if kind and KEEP_ORIGINAL_STRIKES[standId] then return nil end
	if not kind then
		-- Attaques T / F / G (StandSpells) : animation nommée par move.Anim
		local def = StandData.GetStand(standId)
		local move = def and def.Moves and def.Moves[state]
		if move and move.Type and move.Anim then
			kind = "Anim:" .. move.Anim
		end
	end
	if not kind then return nil end
	rig.strikeClips = rig.strikeClips or {}
	local cached = rig.strikeClips[kind]
	if cached == nil then
		local clip = StandStrikes.Compile(standId, kind, rig.joints)
		cached = clip and compileClip(clip) or false
		if cached then cached.key = "Strike:" .. standId .. ":" .. kind end
		rig.strikeClips[kind] = cached
	end
	return cached or nil
end

local function clearClip(rig)
	-- Compatibility clean-up for any previously allocated animation connection.
	if rig.clipConn then
		rig.clipConn:Disconnect()
		rig.clipConn = nil
	end
	if rig.clipKey then
		local previous = rig.clipInfo or compiledClips[rig.clipKey]
		if previous then
			for partName in pairs(previous.driven) do
				local joint = rig.joints[partName]
				if joint then joint.Transform = CFrame.identity end
			end
		end
	end
	rig.clipKey = nil
	rig.clipInfo = nil
	rig.clipStart = nil
	rig.clipInitial = nil
	rig.releasing = nil
end

local function playClipFrame(rig, key, actionElapsed, info)
	info = info or compiledClips[key]
	if not info or info.lastTime <= 0 then return false end
	if rig.clipKey ~= key then
		-- Pose de départ capturée AVANT de nettoyer l'ancien clip, pour
		-- enchaîner sans repasser par la pose neutre.
		local initial = {}
		for partName in pairs(info.driven) do
			local joint = rig.joints[partName]
			if joint then initial[partName] = joint.Transform end
		end
		clearClip(rig)
		rig.clipKey = key
		rig.clipInfo = info
		rig.clipStart = actionElapsed
		rig.clipInitial = initial
	end

	local clip = info.clip
	local clipTime = math.max(0, actionElapsed)
	if clip.Settings.Loop then
		clipTime = clipTime % info.lastTime
	else
		clipTime = math.min(clipTime, info.lastTime)
	end
	local t0, t1 = info.timestamps[1], info.timestamps[#info.timestamps]
	for i = 1, #info.timestamps - 1 do
		if clipTime >= info.timestamps[i] and clipTime < info.timestamps[i + 1] then
			t0, t1 = info.timestamps[i], info.timestamps[i + 1]
			break
		end
	end
	local segment = t1 - t0
	local alpha = segment > 0 and math.clamp((clipTime - t0) / segment, 0, 1) or 1
	local frameA = clip.Timestamps[t0]
	local frameB = clip.Timestamps[t1]
	local fadeIn = math.clamp((actionElapsed - (rig.clipStart or 0)) / CLIP_FADE_IN, 0, 1)
	for partName in pairs(info.driven) do
		local joint = rig.joints[partName]
		if joint then
			local from = frameA[partName] or CFrame.identity
			local to = frameB[partName] or from
			local pose = from:Lerp(to, alpha)
			if fadeIn < 1 then
				pose = (rig.clipInitial[partName] or CFrame.identity):Lerp(pose, fadeIn)
			end
			joint.Transform = pose
		end
	end
	return true
end

local function getMotor(model, containerName, motorName)
	local container = model:FindFirstChild(containerName, true)
	if not container then return nil end
	return container:FindFirstChild(motorName)
end

local function scaleSequence(seq, mult)
	local scaled = {}
	for _, kp in seq.Keypoints do
		table.insert(scaled, NumberSequenceKeypoint.new(kp.Time, math.clamp(kp.Value * mult, 0, 10), kp.Envelope))
	end
	if #scaled == 1 then
		return NumberSequence.new(scaled[1].Value)
	end
	return NumberSequence.new(scaled)
end


-- ===================== POSES =====================
-- V25: POSE PAR CIBLES (IK) : les poings ont une position precise près de la
-- ceinture et les coudes choisissent une direction vers l'exterieur.
-- Plus de rotation arbitraire des avant-bras qui restent verticaux de profil.
local IDLE_BLEND_SECONDS = 0.52
-- V26: pose "derriere son utilisateur" (reference art) : bras ouverts et
-- legerement en arriere le long du corps, coudes presque tendus, poings au
-- niveau des hanches, poitrine ouverte, tete haute, releve stable.
local function referenceIdleTarget(now, motors)
	local breath = math.sin(now * 1.12)
	local sway = math.sin(now * 0.70)
	local flex = breath * 0.02
	return {
		root = CFrame.new(0, -0.025 + breath * 0.013, 0.02)
			* CFrame.Angles(math.rad(-4) + breath * 0.004,
				math.rad(-6) + sway * 0.006, math.rad(-1)),
		neck = CFrame.Angles(math.rad(-4), math.rad(4) + sway * 0.006, 0),
		rightShoulder = CFrame.Angles(0.14 + flex, -0.08, -0.55),
		rightElbow = CFrame.Angles(0.15, 0, 0),
		leftShoulder = CFrame.Angles(0.14 - flex, 0.08, 0.55),
		leftElbow = CFrame.Angles(0.15, 0, 0),
		rightHip = CFrame.Angles(math.rad(-3), math.rad(2), math.rad(-6)),
		leftHip = CFrame.Angles(math.rad(-4), math.rad(-2), math.rad(6)),
	}
end

local function playIdle(rig, now)
    local target = referenceIdleTarget(now, rig.motors)
    local alpha = 1
    if rig.idleTransitionStarted then
        local progress = math.clamp((now - rig.idleTransitionStarted) / IDLE_BLEND_SECONDS, 0, 1)
        alpha = progress * progress * (3 - 2 * progress)
        if progress >= 1 then
            rig.idleTransitionStarted = nil
            rig.idleTransitionFrom = nil
        end
    end
    for name, motor in pairs(rig.motors) do
        local goal = target[name]
        if motor and goal then
            local previous = rig.idleTransitionFrom and rig.idleTransitionFrom[name]
            motor.Transform = (previous and alpha < 1)
                and previous:Lerp(goal, alpha) or goal
        end
    end
end

-- ORA rush: full-extension alternating punches with violent body twist
local function playBarrage(motors, t)
	local cycle = math.floor(t * 16) % 2
	local jitter = math.sin(t * 47) * 0.12
	local punchOut = CFrame.new(0, -0.45 + jitter, -1.05) * CFrame.Angles(-math.pi / 2, 0, 0)
	local chamberR = CFrame.new(0, -0.1, 0.35) * CFrame.Angles(0.75, 0, -0.35)
	local chamberL = CFrame.new(0, -0.1, 0.35) * CFrame.Angles(0.75, 0, 0.35)
	if cycle == 0 then
		if motors.rightShoulder then motors.rightShoulder.Transform = punchOut end
		if motors.leftShoulder then motors.leftShoulder.Transform = chamberL end
	else
		if motors.rightShoulder then motors.rightShoulder.Transform = chamberR end
		if motors.leftShoulder then motors.leftShoulder.Transform = punchOut end
	end
	local twist = (cycle == 0) and -0.2 or 0.2
	if motors.root then
		motors.root.Transform = CFrame.new(0, -0.12, 0) * CFrame.Angles(0.25, twist, math.sin(t * 34) * 0.06)
	end
	if motors.neck then
		motors.neck.Transform = CFrame.Angles(0.18, -twist * 0.5, 0)
	end
	if motors.leftHip then
		motors.leftHip.Transform = CFrame.Angles(0.12, 0, 0.05)
	end
	if motors.rightHip then
		motors.rightHip.Transform = CFrame.Angles(0.12, 0, -0.05)
	end
end

-- Star finger-crusher: overhead cock, then explosive straight
local function playHeavy(motors, t)
	local windup = math.clamp(t / 0.22, 0, 1)
	local strike = math.clamp((t - 0.22) / 0.13, 0, 1)
	local settle = math.clamp((t - 0.35) / 0.25, 0, 1)
	local rightPose, rootPose, neckPose
	if strike <= 0 then
		rightPose = CFrame.new(0, 0.3 * windup, 0.5 * windup) * CFrame.Angles(2.4 * windup, 0, -0.9 * windup)
		rootPose = CFrame.Angles(-0.18 * windup, 0.45 * windup, 0)
		neckPose = CFrame.Angles(-0.1 * windup, -0.3 * windup, 0)
	else
		rightPose = CFrame.new(0, -0.45, -1.15 * (1 - settle * 0.3)) * CFrame.Angles(-math.pi / 2, 0, 0)
		rootPose = CFrame.new(0, 0, -0.35 * (1 - settle)) * CFrame.Angles(0.3 * (1 - settle), -0.45 * (1 - settle), 0)
		neckPose = CFrame.Angles(0.25 * (1 - settle), 0.2 * (1 - settle), 0)
	end
	if motors.rightShoulder then motors.rightShoulder.Transform = rightPose end
	if motors.leftShoulder then
		motors.leftShoulder.Transform = CFrame.Angles(-0.7, 0.3, 0.7)
	end
	if motors.root then motors.root.Transform = rootPose end
	if motors.neck then motors.neck.Transform = neckPose end
end

-- ZA WARUDO: arms sweep into a crossed X while the stand rises
local function playTimeStop(motors, t)
	local sweep = math.clamp(t / 0.35, 0, 1)
	local ease = 1 - (1 - sweep) * (1 - sweep)
	local armPitch = -0.4 - 0.9 * ease
	if motors.rightShoulder then
		motors.rightShoulder.Transform = CFrame.Angles(armPitch, 0.35 * ease, -0.9 * ease)
	end
	if motors.leftShoulder then
		motors.leftShoulder.Transform = CFrame.Angles(armPitch, -0.35 * ease, 0.9 * ease)
	end
	if motors.root then
		motors.root.Transform = CFrame.new(0, 0.25 * ease + math.sin(t * 2.5) * 0.05, 0) * CFrame.Angles(-0.08 * ease, 0, 0)
	end
	if motors.neck then
		local lift = math.clamp((t - 0.5) / 2, 0, 1)
		motors.neck.Transform = CFrame.Angles(0.35 * ease - 0.55 * lift, 0, 0)
	end
end

-- ===================== CINEMATIC STAR PLATINUM DEPLOYMENT V2 =====================
-- Film-like 2.05s sequence: charging sigil, silhouette, portal flare, impact,
-- floating settle. Purely client-side visuals; attack authorization stays on server.
-- Does not modify the Barrage / HeavyPunch animation tracks.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local SUMMON_DROP = 4.3
local SUMMON_PURPLE = Color3.fromRGB(145, 62, 255)
local SUMMON_PINK = Color3.fromRGB(250, 105, 233)
local SUMMON_GOLD = Color3.fromRGB(255, 213, 107)
local summonStarted = setmetatable({}, { __mode = "k" })
local summonImpacted = setmetatable({}, { __mode = "k" })
local summonFinished = setmetatable({}, { __mode = "k" })
local summonWasVisible = setmetatable({}, { __mode = "k" })
local summonPoseStruck = setmetatable({}, { __mode = "k" })
-- One cry per summon: remembers the last reveal roar per owner+stand so a
-- racing/replacement Deploying model cannot double-play the voice line.
local lastRoarAt = {}
local playerPoseConnection = nil

local function smooth01(x)
	x = math.clamp(x, 0, 1)
	return x*x*(3-2*x)
end
local function easeOutQuint(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1-x)^5
end
local function summonRise(p)
	-- The stand is an ominous low silhouette at first, then bursts upward.
	return easeOutQuint((p - 0.16)/0.67)
end

local function fadeSummoningStand(stand,p,complete)
	local reveal = complete and 1 or smooth01((p-0.12)/0.50)
	local halo = math.sin(math.pi*smooth01((p-0.08)/0.83))
	for _,obj in stand:GetDescendants() do
		if obj:IsA("BasePart") then
			obj.LocalTransparencyModifier = 1-reveal
		elseif obj:IsA("Highlight") and obj.Name == "StandHighlight" then
			obj.FillColor = SUMMON_PURPLE
			obj.FillTransparency = complete and 1 or math.clamp(0.24+reveal*0.79,0,1)
			obj.OutlineTransparency = complete and 0.1 or math.clamp(0.62-reveal*0.48,0.08,1)
		elseif obj:IsA("ParticleEmitter") and obj.Name == "StandAura" then
			obj.Rate = complete and 18 or (4+31*halo)*reveal
		elseif obj:IsA("PointLight") and obj.Name == "StandGlow" then
			obj.Brightness = complete and 1.2 or (1.2+3*halo)*reveal
		end
	end
end

local function play3DSound(parent,name,id,volume,pitch,rollOffMin,rollOffMax)
	if not id or id == "" then return end
	local sound=Instance.new("Sound")
	sound.Name=name
	sound.SoundId=id
	sound.Volume=volume
	sound.PlaybackSpeed=pitch or 1
	if rollOffMin then
		-- Spatialized clips (summon voice): inverse-tapered curve fades the
		-- line out naturally between the min/max distance pair.
		sound.RollOffMode=Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance=rollOffMin
		sound.RollOffMaxDistance=rollOffMax or 105
	else
		sound.RollOffMinDistance=9
		sound.RollOffMaxDistance=105
	end
	sound.Parent=parent
	sound:Play()
	Debris:AddItem(sound,5)
end

local function burst(parent,name,colorA,colorB,amount,speed,life,size)
	local emitter=Instance.new("ParticleEmitter")
	emitter.Name=name
	emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color=ColorSequence.new(colorA,colorB)
	emitter.Lifetime=NumberRange.new(life*0.65,life)
	emitter.Speed=NumberRange.new(speed*0.62,speed)
	emitter.SpreadAngle=Vector2.new(180,180)
	emitter.Rotation=NumberRange.new(0,360)
	emitter.RotSpeed=NumberRange.new(-220,220)
	emitter.Drag=3
	emitter.LightEmission=1
	emitter.Rate=0
	emitter.Size=NumberSequence.new({
		NumberSequenceKeypoint.new(0,size*0.27),
		NumberSequenceKeypoint.new(0.24,size),
		NumberSequenceKeypoint.new(1,0),
	})
	emitter.Transparency=NumberSequence.new({
		NumberSequenceKeypoint.new(0,0.15),
		NumberSequenceKeypoint.new(0.65,0.12),
		NumberSequenceKeypoint.new(1,1),
	})
	emitter.Parent=parent
	emitter:Emit(amount)
	return emitter
end

local function effectPart(name,color,size,cf,transparency,shape)
	local part=Instance.new("Part")
	part.Name=name
	part.Anchored=true
	part.CanCollide=false
	part.CanTouch=false
	part.CanQuery=false
	part.CastShadow=false
	part.Material=Enum.Material.Neon
	part.Color=color
	part.Transparency=transparency or 0
	part.Size=size
	if shape=="Ball" then part.Shape=Enum.PartType.Ball end
	if shape=="Cylinder" then part.Shape=Enum.PartType.Cylinder end
	part.CFrame=cf
	part.Parent=workspace
	return part
end

local function centerAnchor(pos,lifetime)
	local anchor=effectPart("SPV2_EffectAnchor",SUMMON_PURPLE,Vector3.new(.13,.13,.13),
		CFrame.new(pos),1,"Ball")
	Debris:AddItem(anchor,lifetime or 3)
	return anchor
end

local function pulse(pos,diameter,lifetime,color,transparency)
	local obj=effectPart("SPV2_Shockwave",color,Vector3.new(.35,.35,.35),
		CFrame.new(pos),transparency or .65,"Ball")
	TweenService:Create(obj,TweenInfo.new(lifetime,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
		Size=Vector3.new(diameter,diameter,diameter),Transparency=1,
	}):Play()
	Debris:AddItem(obj,lifetime+.15)
	return obj
end

-- A rotating-looking sigil assembled from separate emissive segments: no
-- external mesh IDs or copyrighted textures required.
local function summonRing(pos,base,distance,segments,color,lifetime,angleOffset)
	for i=1,segments do
		local a=(i-1)/segments*math.pi*2+(angleOffset or 0)
		local cf=base*CFrame.new(distance*math.cos(a),distance*math.sin(a),0)
			*CFrame.Angles(0,0,a+math.pi/2)
		local part=effectPart("SPV2_SealSegment",color,
			Vector3.new(0.09,2*math.pi*distance/segments*.80,0.095),
			CFrame.new(pos)*cf,0.12)
		TweenService:Create(part,TweenInfo.new(lifetime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
			Transparency=1,Size=Vector3.new(0.015,part.Size.Y*1.35,0.015),
		}):Play()
		Debris:AddItem(part,lifetime+0.10)
	end
end

local function shockRays(pos,count)
	for i=1,count do
		local a=(i-1)/count*math.pi*2
		local length=math.random(26,40)/10
		local ray=effectPart("SPV2_RadialShard",i%3==0 and SUMMON_GOLD or SUMMON_PINK,
			Vector3.new(0.08,0.08,length),
			CFrame.new(pos)*CFrame.Angles(0,a,0)*CFrame.new(0,0,-1.5),0.12)
		local cf=ray.CFrame
		TweenService:Create(ray,TweenInfo.new(.38,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
			CFrame=cf*CFrame.new(0,0,-3.5),Transparency=1,
			Size=Vector3.new(.015,.015,length*0.45),
		}):Play()
		Debris:AddItem(ray,.45)
	end
end

-- Radial floor ripple + dust burst when the stand deploys: two neon discs
-- race outward across the ground while matte dust is kicked up from it.
local function groundRipple(position)
	local origin = position + Vector3.new(0, 3, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		workspace:FindFirstChild(localPlayer.Name .. "Stand"),
		localPlayer.Character,
	}
	local hit = workspace:Raycast(origin, Vector3.new(0, -14, 0), params)
	local groundPos = hit and hit.Position or (position - Vector3.new(0, 2.9, 0))

	for _, info in ipairs({
		{ delay = 0.00, diameter = 7.5, life = 0.55, color = SUMMON_PURPLE, trans = 0.45 },
		{ delay = 0.10, diameter = 11.5, life = 0.70, color = SUMMON_GOLD, trans = 0.55 },
	}) do
		task.delay(info.delay, function()
			local ring = effectPart("SPV2_FloorRipple", info.color,
				Vector3.new(0.14, 0.6, 0.6),
				CFrame.new(groundPos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				info.trans, "Cylinder")
			TweenService:Create(ring, TweenInfo.new(info.life, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.02, info.diameter, info.diameter),
				Transparency = 1,
			}):Play()
			Debris:AddItem(ring, info.life + 0.1)
		end)
	end

	local dustAnchor = effectPart("SPV2_DustAnchor", Color3.new(1, 1, 1),
		Vector3.new(0.1, 0.1, 0.1), CFrame.new(groundPos + Vector3.new(0, 0.4, 0)), 1, "Ball")
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "SPV2_DustBurst"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(168, 142, 108), Color3.fromRGB(112, 94, 74))
	dust.Lifetime = NumberRange.new(0.5, 0.95)
	dust.Speed = NumberRange.new(5, 11)
	dust.SpreadAngle = Vector2.new(75, 75)
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-140, 140)
	dust.Drag = 3.5
	dust.Acceleration = Vector3.new(0, -7, 0)
	dust.LightEmission = 0.15
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.4, 1.15),
		NumberSequenceKeypoint.new(1, 1.9),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = dustAnchor
	dust:Emit(26)
	Debris:AddItem(dustAnchor, 1.5)
end

local function localCameraImpact()
	local camera=workspace.CurrentCamera
	if not camera then return end
	local initialFOV=camera.FieldOfView
	local fovUp=TweenService:Create(camera,TweenInfo.new(.10,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
		{FieldOfView=initialFOV+5})
	fovUp:Play()
	task.delay(.12,function()
		if camera.Parent then
			TweenService:Create(camera,TweenInfo.new(.48,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
				{FieldOfView=initialFOV}):Play()
		end
	end)
	local filter=Instance.new("ColorCorrectionEffect")
	filter.Name="SPV2_LocalImpactColor"
	filter.TintColor=Color3.fromRGB(223,190,255)
	filter.Contrast=.35
	filter.Saturation=-.25
	filter.Parent=Lighting
	TweenService:Create(filter,TweenInfo.new(.58,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
		Contrast=0,Saturation=0,TintColor=Color3.new(1,1,1),
	}):Play()
	Debris:AddItem(filter,.65)
	local begun=os.clock()
	local name="SPV2_LocalCameraShake"
	RunService:UnbindFromRenderStep(name)
	RunService:BindToRenderStep(name,Enum.RenderPriority.Camera.Value+1,function()
		local age=os.clock()-begun
		if age>.36 then RunService:UnbindFromRenderStep(name);return end
		local amp=(1-age/.36)^2*.20
		local shake=Vector3.new(math.sin(age*87),math.cos(age*110),math.sin(age*67))*amp
		local cam=workspace.CurrentCamera
		if cam then cam.CFrame=cam.CFrame*CFrame.new(shake) end
	end)
end

local function localSummonTitle(standDef)
	local playerGui=localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local old=playerGui:FindFirstChild("SPV2_SummonTitle")
	if old then old:Destroy() end
	local standName=(standDef and standDef.DisplayName or "Stand"):upper()
	local gui=Instance.new("ScreenGui")
	gui.Name="SPV2_SummonTitle"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=60
	gui.Parent=playerGui
	local panel=Instance.new("TextLabel")
	panel.Name="StandReveal"
	panel.AnchorPoint=Vector2.new(.5,.5)
	panel.Position=UDim2.fromScale(.5,.74)
	panel.Size=UDim2.fromScale(.40,.075)
	panel.BackgroundTransparency=1
	panel.Text=standName
	panel.Font=Enum.Font.GothamBlack
	panel.TextScaled=true
	panel.TextColor3=SUMMON_GOLD
	panel.TextTransparency=1
	panel.Parent=gui
	local outline=Instance.new("UIStroke")
	outline.Color=SUMMON_PURPLE
	outline.Thickness=2
	outline.Transparency=1
	outline.Parent=panel
	TweenService:Create(panel,TweenInfo.new(.17,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{
		TextTransparency=0,Position=UDim2.fromScale(.5,.70),
	}):Play()
	TweenService:Create(outline,TweenInfo.new(.12),{Transparency=0}):Play()
	task.delay(.65,function()
		if panel.Parent then
			TweenService:Create(panel,TweenInfo.new(.40),{
				TextTransparency=1,Position=UDim2.fromScale(.5,.66),
			}):Play()
			TweenService:Create(outline,TweenInfo.new(.40),{Transparency=1}):Play()
		end
	end)
	Debris:AddItem(gui,1.25)
end

-- Player briefly throws up an arm at the reveal; the default Roblox Animate
-- controller resumes after the cinematic. Does not change server movement.
local function localCasterPose(character,duration)
	if not character then return end
	if playerPoseConnection then playerPoseConnection:Disconnect();playerPoseConnection=nil end
	local rig=character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not rig then return end
	local right=rig:FindFirstChild("Right Shoulder") or rig:FindFirstChild("RightShoulder")
	local left=rig:FindFirstChild("Left Shoulder") or rig:FindFirstChild("LeftShoulder")
	if not (right and left) then return end
	local begun=os.clock()
	playerPoseConnection=RunService.PreSimulation:Connect(function()
		if not character.Parent or not rig.Parent then
			if playerPoseConnection then playerPoseConnection:Disconnect();playerPoseConnection=nil end
			return
		end
		local t=(os.clock()-begun)/duration
		if t>=.9 then
			right.Transform=CFrame.identity
			left.Transform=CFrame.identity
			if playerPoseConnection then playerPoseConnection:Disconnect();playerPoseConnection=nil end
			return
		end
		local inA=smooth01(t/.22)
		local outA=1-smooth01((t-.53)/.30)
		local weight=inA*outA
		right.Transform=CFrame.Angles(-1.30*weight,0,-.70*weight)
		left.Transform=CFrame.Angles(-.45*weight,0,.42*weight)
	end)
end

local function summonStart(stand,character,standDef)
	if summonStarted[stand] or not stand.PrimaryPart then return end
	summonStarted[stand]=true
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local position=root and (root.CFrame* CFrame.new(standDef.FollowOffset)).Position
		or (stand.PrimaryPart.Position+Vector3.new(0,SUMMON_DROP,0))
	local camera=workspace.CurrentCamera
	if camera and (camera.CFrame.Position-position).Magnitude>160 then return end
	local direction=root and root.CFrame.LookVector or Vector3.new(0,0,-1)
	local base=CFrame.lookAt(Vector3.zero,direction)
	local anchor=centerAnchor(position,3)
	groundRipple(position)
	summonRing(position,base,1.55,20,SUMMON_PURPLE,1.05,.05)
	summonRing(position,base,2.12,24,SUMMON_PINK,.87,.16)
	local core=pulse(position,4.5,.80,SUMMON_PURPLE,.82)
	burst(anchor,"SPV2_Charge",SUMMON_PURPLE,SUMMON_GOLD,66,9,.8,.37)
	local light=Instance.new("PointLight")
	light.Color=SUMMON_PINK
	light.Range=18
	light.Brightness=4
	light.Parent=core
	TweenService:Create(light,TweenInfo.new(.69),{Brightness=0}):Play()
	play3DSound(anchor,"SPV2_ChargeWhoosh","rbxasset://sounds/swordslash.wav",.55,.62)
	if stand:GetAttribute("Owner")==localPlayer.UserId then
		localCasterPose(character,standDef.SummonDuration or 2.05)
	end
end

local function summonReveal(stand,standDef)
	if summonImpacted[stand] or not stand.PrimaryPart then return end
	summonImpacted[stand]=true
	-- The summon voice line plays exactly one time per summon: a replacement
	-- model of the same player's stand (server race echo) is skipped.
	local standId = stand:GetAttribute("StandId")
	local roarKey = tostring(stand:GetAttribute("Owner")) .. ":" .. tostring(standId)
	local nowClock = os.clock()
	if lastRoarAt[roarKey] and nowClock - lastRoarAt[roarKey] < 1.25 then
		return
	end
	lastRoarAt[roarKey] = nowClock
	local pos=stand.PrimaryPart.Position+Vector3.new(0,.8,0)
	local camera=workspace.CurrentCamera
	if camera and (camera.CFrame.Position-pos).Magnitude>160 then return end
	local anchor=centerAnchor(pos,3)
	pulse(pos,10,.46,SUMMON_PINK,.56)
	pulse(pos,7,.32,SUMMON_GOLD,.73)
	shockRays(pos,14)
	burst(anchor,"SPV2_EnergyDetonation",SUMMON_GOLD,SUMMON_PURPLE,92,19,.68,.54)
	local light=Instance.new("PointLight")
	light.Color=SUMMON_GOLD
	light.Brightness=8
	light.Range=24
	light.Parent=anchor
	TweenService:Create(light,TweenInfo.new(.40),{Brightness=0}):Play()
	-- Summon shout rework: the verified Summon roar fires on the reveal impact,
	-- then the "ORA!" quote lands just after it for a layered shout.
	play3DSound(anchor,"SPV2_SummonRoar",resolveVoiceId(standId,"Summon") or standDef.SummonShoutId,1.25,1,14,65)
	task.delay(.35,function()
		if anchor.Parent then
			play3DSound(anchor,"SPV2_StandQuote",resolveVoiceId(standId,"Quote") or standDef.SummonQuoteId,1.1,1,14,65)
		end
	end)
	if stand:GetAttribute("Owner")==localPlayer.UserId then
		localCameraImpact()
		localSummonTitle(standDef)
	end
end

local function summonFinale(stand)
	if summonFinished[stand] or not stand.PrimaryPart then return end
	summonFinished[stand]=true
	local pos=stand.PrimaryPart.Position
	local camera=workspace.CurrentCamera
	if camera and (camera.CFrame.Position-pos).Magnitude>160 then return end
	local anchor=centerAnchor(pos,2)
	burst(anchor,"SPV2_FinaleSparkles",SUMMON_GOLD,SUMMON_PINK,42,6,.68,.18)
	pulse(pos,4.6,.56,SUMMON_PURPLE,.86)
end

-- ===================== RIG / FX =====================

local function cacheEyeFX(stand)
	local fx = {}
	local detail = stand:FindFirstChild("Detail")
	local headModel = detail and detail:FindFirstChild("Head")
	local eyesMesh = headModel and headModel:FindFirstChild("Eyes")
	if eyesMesh then
		for _, inst in eyesMesh:GetDescendants() do
			if inst:IsA("ParticleEmitter") then
				table.insert(fx, { obj = inst, rate = inst.Rate, size = inst.Size, color = inst.Color })
			elseif inst:IsA("Trail") then
				table.insert(fx, { obj = inst, isTrail = true, color = inst.Color })
			end
		end
	end
	return fx
end

local rigCache = setmetatable({}, { __mode = "k" })

local function getRig(stand)
	local rig = rigCache[stand]
	if not rig then
		rig = {
			motors = {
				rightShoulder = getMotor(stand, "Torso", "Right Shoulder"),
				leftShoulder = getMotor(stand, "Torso", "Left Shoulder"),
				rightElbow = getMotor(stand, "Right Arm", "Right Elbow"),
				leftElbow = getMotor(stand, "Left Arm", "Left Elbow"),
				root = getMotor(stand, "HumanoidRootPart", "RootJoint") or getMotor(stand, "HumanoidRootPart", "Root Hip"),
				neck = getMotor(stand, "Torso", "Neck"),
				leftHip = getMotor(stand, "Torso", "Left Hip"),
				rightHip = getMotor(stand, "Torso", "Right Hip"),
			},
			trails = {},
			eyes = cacheEyeFX(stand),
			eyeMode = nil,
			aura = stand:FindFirstChild("StandAura", true),
			glow = stand:FindFirstChild("StandGlow", true),
			auraMode = nil,
			joints = collectJoints(stand),
			clipConn = nil,
			clipKey = nil,
            lastVisualState = nil,
            idleTransitionStarted = nil,
            idleTransitionFrom = nil,
            poseBlendStart = nil,
            poseBlendFrom = nil,
			shout = nil,
			shoutLabel = nil,
			lastShout = -1,
		}
		local shout = stand:FindFirstChild("Shout", true)
		if shout then
			rig.shout = shout
			rig.shoutLabel = shout:FindFirstChild("Text")
			-- Per-stand cry word ("ORA", "MUDA", "DORARARA", ...) from the
			-- stand definition; the hardcoded ORA flicker is gone.
			local standDef = StandData.GetStand(stand:GetAttribute("StandId"))
			rig.shoutWord = ((standDef and standDef.ShoutText) or "ORA!"):gsub("!+$", "")
		end
		for _, armName in { "Left Arm", "Right Arm" } do
			local arm = stand:FindFirstChild(armName)
			if arm then
				local trail = arm:FindFirstChild("PunchTrail")
				if trail then
					rig.trails[armName] = trail
				end
			end
		end
        -- Aide au diagnostic : avertir seulement pour le gabarit Detail
        -- (l'ancien modele). Le nouveau gabarit n'a volontairement pas de coudes.
        if (not rig.motors.rightElbow or not rig.motors.leftElbow)
            and stand:FindFirstChild("Detail") then
            warn("[StarPlatinum V14] Coude introuvable sur le Stand : verifier le script StandService.")
        end
		rigCache[stand] = rig
	end
	return rig
end

local function applyEyeFX(rig, state)
	local mode = (state == "Barrage" or state == "HeavyPunch") and "rage"
		or state == "TimeStop" and "frenzy"
		or "idle"
	if rig.eyeMode == mode then return end
	rig.eyeMode = mode
	for _, fx in rig.eyes do
		if fx.isTrail then
			if mode ~= "idle" then
				fx.obj.Color = ColorSequence.new(mode == "frenzy" and BLOOD or GOLD)
			else
				fx.obj.Color = fx.color
			end
		else
			if mode == "idle" then
				fx.obj.Rate = fx.rate
				fx.obj.Size = fx.size
				fx.obj.Color = fx.color
			else
				fx.obj.Rate = math.max(fx.rate, 10) * (mode == "frenzy" and 2.5 or 3)
				fx.obj.Size = scaleSequence(fx.size, mode == "frenzy" and 1.5 or 1.7)
				fx.obj.Color = ColorSequence.new(mode == "frenzy" and BLOOD or GOLD)
			end
		end
	end
end

-- Iconic STAR PLATINUM pose (reference art), struck right after the
-- deployment cinematic: right arm thrust straight overhead with a clenched
-- fist (overhead-cock shoulder axes proven by the HeavyPunch windup), left
-- elbow flared out with the fist planted at the hip, chest puffed, head
-- tilted up, wide stance, with a subtle power tremble.
local POSE_BLEND_SECONDS = 0.30
local function playStarPose(motors, t, now, rig)
	local flex = math.sin(t * 9) * 0.025
	local goal = {
		rightShoulder = CFrame.new(0, 0.18, 0.10) * CFrame.Angles(2.95, 0, -0.50),
		rightElbow = CFrame.Angles(0.08 + flex, 0, 0),
		leftShoulder = CFrame.Angles(0.55, -0.30, 1.25),
		leftElbow = CFrame.Angles(1.50 - flex, 0, 0),
		root = CFrame.new(0, -0.14, 0.08) * CFrame.Angles(0.12, -0.30, 0.03),
		neck = CFrame.Angles(-0.32, 0.18, 0),
		leftHip = CFrame.Angles(0.18, 0, 0.10),
		rightHip = CFrame.Angles(-0.12, 0, -0.10),
	}
	if rig.poseBlendStart == nil then
		rig.poseBlendStart = now
		rig.poseBlendFrom = {}
		for name, motor in pairs(rig.motors) do
			if motor then rig.poseBlendFrom[name] = motor.Transform end
		end
	end
	local alpha = smooth01(math.clamp((now - rig.poseBlendStart) / POSE_BLEND_SECONDS, 0, 1))
	for name, motor in pairs(rig.motors) do
		local target = goal[name]
		if motor and target then
			local from = rig.poseBlendFrom and rig.poseBlendFrom[name] or CFrame.identity
			motor.Transform = from:Lerp(target, alpha)
		end
	end
end

-- V9: One pose owner per frame. The action timestamp, not a separate
-- animation loop, decides whether punches can still be shown.
local function animateStand(stand, state, t, now)
    local rig = getRig(stand)
    -- Record the LAST attack/deployment frame once, then blend into Idle.
    -- This does not create a new heartbeat or interfere with V9 barrage limits.
    if rig.lastVisualState ~= state then
        if state == "Idle" then
            rig.idleTransitionFrom = {}
            for name, motor in pairs(rig.motors) do
                if motor then rig.idleTransitionFrom[name] = motor.Transform end
            end
            rig.idleTransitionStarted = now
        else
            rig.idleTransitionStarted = nil
            rig.idleTransitionFrom = nil
        end
        if state ~= "Pose" then
            rig.poseBlendStart = nil
            rig.poseBlendFrom = nil
        end
        rig.lastVisualState = state
    end
    local strike = getStrikeClip(stand, rig, state)
    local desired = strike or compiledClips[state]
	if desired then
		playClipFrame(rig, strike and strike.key or state, t, desired)
		local rightElbow = rig.motors.rightElbow
		local leftElbow = rig.motors.leftElbow
		if strike then
			-- Coudes ajoutés sur un Stand R6 : ils suivent la frappe du Stand.
			if rightElbow or leftElbow then
				local r, l = StandStrikes.ElbowsAt(strike.clip, math.max(0, t))
				if r and rightElbow then rightElbow.Transform = CFrame.Angles(r, 0, 0) end
				if l and leftElbow then leftElbow.Transform = CFrame.Angles(l, 0, 0) end
			end
		elseif state == "LightPunchR" or state == "LightPunchL" then
			-- Coup léger : le bras qui frappe s'arme puis se tend, l'autre garde.
			local punching = jabElbow(math.max(0, t))
			local guard = JAB_GUARD_ELBOW
			local right = state == "LightPunchR" and punching or guard
			local left = state == "LightPunchL" and punching or guard
			if rightElbow then rightElbow.Transform = CFrame.Angles(right, 0, 0) end
			if leftElbow then leftElbow.Transform = CFrame.Angles(left, 0, 0) end
		elseif state == "Barrage" or state == "HeavyPunch" then
			-- Strong straight punch silhouette during Barrage / HeavyPunch.
			if rightElbow then rightElbow.Transform = CFrame.Angles(0.10, 0, 0) end
			if leftElbow then leftElbow.Transform = CFrame.Angles(0.11, 0, 0) end
		end
	else
		if rig.clipKey or rig.clipConn then
			clearClip(rig)
		end
		local motors = rig.motors
		if state == "Pose" then
			playStarPose(motors, t, now, rig)
		elseif state == "TimeStop" then
			playTimeStop(motors, t)
			if motors.rightElbow then motors.rightElbow.Transform = CFrame.Angles(0.82, 0, 0) end
			if motors.leftElbow then motors.leftElbow.Transform = CFrame.Angles(0.82, 0, 0) end
		else
			-- Idle is also the mandatory fallback after a barrage ends.
			playIdle(rig, now)
		end
	end

	if rig.shout then
		local jab = state == "LightPunchR" or state == "LightPunchL"
		local active = state == "Barrage" or jab
		rig.shout.Enabled = active
		if active and rig.shoutLabel then
			local flick = jab and 0 or (math.floor(t * 16) % 3)
			if flick ~= rig.lastShout then
				rig.lastShout = flick
				local word = rig.shoutWord or "ORA"
				if flick == 0 then
					rig.shoutLabel.Text = word .. "!"
				elseif flick == 1 then
					rig.shoutLabel.Text = word .. " " .. word .. "!"
				else
					rig.shoutLabel.Text = word .. " " .. word .. " " .. word .. "!"
				end
				rig.shoutLabel.Rotation = jab and 0 or math.random(-10, 10)
			end
		else
			rig.lastShout = -1
		end
	end
	local trailsOn = state == "Barrage" or state == "HeavyPunch"
	for _, trail in rig.trails do
		trail.Enabled = trailsOn
	end
	-- Raging aura: the stand burns brighter and vents more energy while attacking.
	local rage = trailsOn
	if rig.aura and state ~= "Deploying" and rig.auraMode ~= rage then
		rig.auraMode = rage
		rig.aura.Rate = rage and 85 or 18
		rig.aura.Speed = NumberRange.new(rage and 4 or 1, rage and 8.5 or 2.5)
		rig.aura.Size = NumberSequence.new(rage and 0.58 or 0.4)
	end
	if rig.glow and state ~= "Deploying" then
		rig.glow.Brightness = rage and 2.8 or 1.2
	end
	applyEyeFX(rig, state)
	stand:SetAttribute("VisualState", state)
	stand:SetAttribute("AttackClipActive", desired ~= nil)
end

-- ===================== STAR PLATINUM BARRAGE V7 (VISIBLE + CLEAN) =====================
-- Client-only VFX. The server remains authoritative for damage and cooldowns.
-- Stand-relative spread; rapid purple/gold 3D afterimages with a short readable hold.
local BARRAGE_VISUALS = {
    PunchesPerSecond = 36,       -- visual punches (damage ticks unchanged)
    Lifetime = 0.31,            -- absolute per-punch destruction deadline
    TravelTime = 0.21,          -- readable forward thrust
    FadeTime = 0.09,            -- fade only at the END, not during entire punch
    Scale = 0.88,
    MaxViewDistance = 150,
    Primary = Color3.fromRGB(116, 63, 199),
    Light = Color3.fromRGB(195, 152, 255),
    Gold = Color3.fromRGB(237, 190, 77),
}

local barrageVisualCache = setmetatable({}, { __mode = "k" })
local legacyBarrageCleaned = false

local function clearLegacyBarrage()
    local camera = workspace.CurrentCamera
    if not camera then return end
    for _, item in ipairs(camera:GetChildren()) do
        if item.Name:match("^SPV[345]_Local")
           or item.Name:match("^SPV[67]_Barrage_") then
            item:Destroy()
        end
    end
end

local function ghostPiece(original, name, color, folder)
    local part = original:Clone()
    part:ClearAllChildren()
    part.Name = name
    if part:IsA("MeshPart") then
        part.TextureID = ""
    end
    part.Size = original.Size * BARRAGE_VISUALS.Scale
    part.Material = Enum.Material.SmoothPlastic
    part.Color = color
    part.Reflectance = 0.06
    part.Transparency = 0.07
    part.CastShadow = false
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Parent = folder
    return part
end

local function findArmParts(stand)
    local detail = stand:FindFirstChild("Detail")
    local leftGroup = detail and detail:FindFirstChild("LeftArm")
    local rightGroup = detail and detail:FindFirstChild("RightArm")
    local left = leftGroup and leftGroup:FindFirstChild("LArm")
    local right = rightGroup and rightGroup:FindFirstChild("RArm")
    if not (left and right and left:IsA("MeshPart") and right:IsA("MeshPart")) then
        -- Fallback for the new display-style template: its arm meshes live
        -- inside the R6 "Left Arm"/"Right Arm" hosts. The biggest mesh (the
        -- arm skin) becomes the ghost-fist source, the rest act as armor.
        local function armMesh(armName)
            local arm = stand:FindFirstChild(armName)
            if not arm then return nil end
            local best, bestSize
            for _, child in ipairs(arm:GetChildren()) do
                if child:IsA("MeshPart") then
                    local mag = child.Size.Magnitude
                    if not bestSize or mag > bestSize then
                        best, bestSize = child, mag
                    end
                end
            end
            return best
        end
        left = armMesh("Left Arm")
        right = armMesh("Right Arm")
        if not (left and right) then
            return nil
        end
        local function getArmor(arm)
            local pieces = {}
            for _, child in ipairs(arm.Parent:GetChildren()) do
                if child:IsA("MeshPart") and child ~= arm then
                    table.insert(pieces, child)
                end
            end
            table.sort(pieces, function(a, b)
                return a.Size.Magnitude > b.Size.Magnitude
            end)
            return pieces
        end
        return left, right, getArmor(left), getArmor(right)
    end
    local function getArmor(arm)
        local pieces = {}
        for _, child in ipairs(arm.Parent:GetChildren()) do
            if child:IsA("MeshPart") and child ~= arm then
                table.insert(pieces, child)
            end
        end
        table.sort(pieces, function(a, b)
            return a.Size.Magnitude > b.Size.Magnitude
        end)
        return pieces
    end
    return left, right, getArmor(left), getArmor(right)
end

local function startBarrageVisuals(stand)
    local left, right, leftArmor, rightArmor = findArmParts(stand)
    if not left then
        if not stand:GetAttribute("SPV7_MissingArmsWarned") then
            stand:SetAttribute("SPV7_MissingArmsWarned", true)
            warn("[SPV7] Detail.LeftArm.LArm / Detail.RightArm.RArm missing: cannot create 3D punch visuals")
        end
        return nil
    end
    local folder = Instance.new("Folder")
    folder.Name = "SPV7_Barrage_" .. tostring(stand:GetAttribute("Owner") or 0)
    folder.Parent = workspace.CurrentCamera or workspace
    -- Safety cleanup if a RenderStepped callback errors. Normal cleanup occurs
    -- immediately at the end of the Barrage, and each punch has its own expiry.
    Debris:AddItem(folder, 4.45)
    return {
        folder = folder,
        left = left,
        right = right,
        leftArmor = leftArmor,
        rightArmor = rightArmor,
        lastPunch = -1,
        lastUpdate = os.clock(),
    }
end

local function stopBarrageVisuals(stand)
    local session = barrageVisualCache[stand]
    if not session then return end
    barrageVisualCache[stand] = nil
    if session.folder and session.folder.Parent then
        session.folder:Destroy()
    end
end

local function animateGhost(part, origin, target, offset, initialTransparency)
    part.CFrame = origin * offset
    part.Transparency = initialTransparency
    TweenService:Create(part, TweenInfo.new(BARRAGE_VISUALS.TravelTime,
        Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = target * offset,
        }):Play()
    task.delay(BARRAGE_VISUALS.TravelTime - 0.01, function()
        if part.Parent then
            TweenService:Create(part, TweenInfo.new(BARRAGE_VISUALS.FadeTime,
                Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Transparency = 1,
                }):Play()
        end
    end)
end

local function spawnBarragePunch(stand, session, index)
    local rootPart = stand.PrimaryPart
    if not rootPart or not session.folder.Parent then return end
    local isRight = index % 2 == 0
    local source = isRight and session.right or session.left
    if not source or not source.Parent then return end
    local armor = isRight and session.rightArmor or session.leftArmor

    local packet = Instance.new("Folder")
    packet.Name = "SPV7_Punch"
    packet.Parent = session.folder
    Debris:AddItem(packet, BARRAGE_VISUALS.Lifetime)

    local root = rootPart.CFrame
    local side = isRight and 1 or -1
    local sway = math.sin(index * 2.399963) * 0.34
    local elevation = math.sin(index * 1.731) * 0.37
    -- Fists are close enough to Star Platinum to form a dense fan rather than
    -- scattering around the player; short-lived anchored meshes cannot linger.
    local base = root.Position
    local startPos = base + root.LookVector * 1.05
        + root.RightVector * (side * 0.48 + sway)
        + root.UpVector * (0.17 + elevation)
    local endPos = base + root.LookVector * 2.75
        + root.RightVector * (side * 0.66 + sway * 0.75)
        + root.UpVector * (0.19 + elevation * 0.80)
    local orientation = source.CFrame.Rotation
    local startCF = CFrame.new(startPos) * orientation
    local endCF = CFrame.new(endPos) * orientation

    local fist = ghostPiece(source, "SPV7_VioletFist", BARRAGE_VISUALS.Primary, packet)
    animateGhost(fist, startCF, endCF, CFrame.identity, 0.08)

    for i = 1, math.min(2, #armor) do
        local original = armor[i]
        if original and original.Parent then
            local detail = ghostPiece(original, "SPV7_FistArmor" .. i,
                i == 1 and BARRAGE_VISUALS.Light or BARRAGE_VISUALS.Gold, packet)
            local armOffset = source.CFrame:ToObjectSpace(original.CFrame)
            local scaledOffset = CFrame.new(armOffset.Position * BARRAGE_VISUALS.Scale)
                * armOffset.Rotation
            animateGhost(detail, startCF, endCF, scaledOffset, i == 1 and 0.15 or 0.22)
        end
    end

    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(-0.22, 0.32, 0)
    a0.Parent = fist
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0.22, -0.32, 0)
    a1.Parent = fist
    local trail = Instance.new("Trail")
    trail.Name = "SPV7_PurpleStreak"
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Color = ColorSequence.new(BARRAGE_VISUALS.Light, BARRAGE_VISUALS.Primary)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.13),
        NumberSequenceKeypoint.new(0.6, 0.48),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.90),
        NumberSequenceKeypoint.new(1, 0.02),
    })
    trail.LightEmission = 0.85
    trail.FaceCamera = true
    trail.Lifetime = 0.13
    trail.MinLength = 0.01
    trail.Parent = fist

    -- Impact pop: each fist detonates on landing with a flash, sparks and light.
    task.delay(BARRAGE_VISUALS.TravelTime, function()
        if not packet.Parent or not fist.Parent then return end
        local popColor = (index % 3 == 0) and BARRAGE_VISUALS.Gold or BARRAGE_VISUALS.Light
        pulse(endPos, 1.7 + math.random() * 0.6, 0.17, popColor, 0.38)
        local anchor = effectPart("SPV7_ImpactAnchor", popColor,
            Vector3.new(0.1, 0.1, 0.1), CFrame.new(endPos), 1, "Ball")
        Debris:AddItem(anchor, 0.45)
        burst(anchor, "SPV7_ImpactSparks", popColor, BARRAGE_VISUALS.Primary, 9, 12, 0.22, 0.15)
        local light = Instance.new("PointLight")
        light.Color = popColor
        light.Range = 6
        light.Brightness = 3
        light.Parent = anchor
        TweenService:Create(light, TweenInfo.new(0.16), { Brightness = 0 }):Play()
        -- Every 12th punch lands harder: a wider violet shockwave.
        if index % 12 == 0 then
            pulse(endPos, 3.6, 0.30, BARRAGE_VISUALS.Primary, 0.30)
        end
    end)
end

local function updateBarrageVisuals(stand, state, t, now)
    if not legacyBarrageCleaned then
        legacyBarrageCleaned = true
        clearLegacyBarrage()
    end
    if state ~= "Barrage" or not stand.PrimaryPart then
        stopBarrageVisuals(stand)
        return
    end
    local camera = workspace.CurrentCamera
    if camera and (camera.CFrame.Position - stand.PrimaryPart.Position).Magnitude
        > BARRAGE_VISUALS.MaxViewDistance then
        stopBarrageVisuals(stand)
        return
    end
    local session = barrageVisualCache[stand]
    if not session or not session.folder.Parent then
        session = startBarrageVisuals(stand)
        if not session then return end
        barrageVisualCache[stand] = session
    end
    session.lastUpdate = os.clock()
    local pulse = math.floor(math.max(0, t) * BARRAGE_VISUALS.PunchesPerSecond)
    if pulse ~= session.lastPunch then
        session.lastPunch = pulse
        spawnBarragePunch(stand, session, pulse)
    end
end

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for stand, session in pairs(barrageVisualCache) do
        if not stand.Parent or not stand.PrimaryPart or not session.folder.Parent
            or now - session.lastUpdate > 0.32 then
            stopBarrageVisuals(stand)
        end
    end
end)
-- =================== END STAR PLATINUM BARRAGE V7 ===================


-- ============ HEAVY PUNCH V2: CHARGE-UP + FLYING FIST + DETONATION ============
-- Client-only VFX driven by the replicated HeavyPunch state timestamp.
-- Timeline mirrors the animation: cock 0.00-0.22s, strike 0.22-0.35s.
local heavySessions = setmetatable({}, { __mode = "k" })

local function stopHeavyVisuals(stand)
    local session = heavySessions[stand]
    if not session then return end
    heavySessions[stand] = nil
    if session.anchor and session.anchor.Parent then
        session.anchor:Destroy()
    end
end

local function updateHeavyPunchVisuals(stand, state, t, character)
    if state ~= "HeavyPunch" or not stand.PrimaryPart then
        stopHeavyVisuals(stand)
        return
    end
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        stopHeavyVisuals(stand)
        return
    end
    local root = stand.PrimaryPart
    local camera = workspace.CurrentCamera
    if camera and (camera.CFrame.Position - root.Position).Magnitude
        > BARRAGE_VISUALS.MaxViewDistance then
        stopHeavyVisuals(stand)
        return
    end

    local flat = root.CFrame.LookVector
    flat = Vector3.new(flat.X, 0, flat.Z)
    flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
    local hitPos = hrp.Position + flat * 4.4 + Vector3.new(0, 0.4, 0)

    local session = heavySessions[stand]
    if not session then
        session = {
            anchor = centerAnchor(hitPos, 1.2),
            orb = effectPart("SPV2_HeavyChargeOrb", SUMMON_PURPLE,
                Vector3.new(0.25, 0.25, 0.25), CFrame.new(hitPos), 0.25, "Ball"),
            struck = false,
        }
        Debris:AddItem(session.orb, 1.2)
        session.sparks = burst(session.anchor, "SPV2_HeavyCharge",
            SUMMON_PURPLE, SUMMON_GOLD, 0, 6, 0.45, 0.30)
        session.sparks.Rate = 42
        local glow = Instance.new("PointLight")
        glow.Color = SUMMON_PURPLE
        glow.Range = 10
        glow.Brightness = 0
        glow.Parent = session.anchor
        session.light = glow
        heavySessions[stand] = session
    end

    -- Charging: the orb swells at the impact point and turns gold right before the hit.
    local windup = math.clamp(t / 0.22, 0, 1)
    if session.orb and session.orb.Parent then
        local swell = 0.25 + windup * 1.15
            + (t > 0.22 and math.sin(t * 46) * 0.14 or 0)
        session.orb.Size = Vector3.new(swell, swell, swell)
        session.orb.CFrame = CFrame.new(hitPos)
        session.orb.Color = windup < 1 and SUMMON_PURPLE or SUMMON_GOLD
    end
    if session.light and session.light.Parent then
        session.light.Brightness = windup * 5
    end

    -- Detonation: flash ball, layered shockwaves, radial shards, gold seal ring.
    if not session.struck and t >= 0.30 then
        session.struck = true
        if session.sparks and session.sparks.Parent then
            session.sparks.Rate = 0
        end
        burst(session.anchor, "SPV2_HeavyDetonation", SUMMON_GOLD, SUMMON_PURPLE, 80, 22, 0.6, 0.5)
        pulse(hitPos, 13, 0.34, SUMMON_GOLD, 0.45)
        pulse(hitPos, 9, 0.26, Color3.new(1, 1, 1), 0.20)
        pulse(hitPos, 16, 0.50, SUMMON_PURPLE, 0.70)
        shockRays(hitPos, 12)
        summonRing(hitPos, CFrame.lookAt(Vector3.zero, flat), 1.7, 14, SUMMON_GOLD, 0.30, 0)
        if session.light and session.light.Parent then
            session.light.Color = SUMMON_GOLD
            session.light.Range = 26
            session.light.Brightness = 9
            TweenService:Create(session.light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
        end
        -- A giant golden afterimage fist rockets into the impact point.
        local left, right = findArmParts(stand)
        local source = right or left
        if source then
            local folder = Instance.new("Folder")
            folder.Name = "SPV2_HeavyFist"
            folder.Parent = camera or workspace
            Debris:AddItem(folder, 0.6)
            local fist = ghostPiece(source, "SPV2_HeavyFistMesh", SUMMON_GOLD, folder)
            fist.Size = fist.Size * 1.45
            fist.Transparency = 0.05
            local startCF = root.CFrame * CFrame.new(0, 0.4, 1.2)
            TweenService:Create(fist,
                TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { CFrame = CFrame.new(hitPos) * root.CFrame.Rotation, Transparency = 0.45 }):Play()
            task.delay(0.13, function()
                if fist.Parent then
                    TweenService:Create(fist, TweenInfo.new(0.12), { Transparency = 1 }):Play()
                end
            end)
        end
        if stand:GetAttribute("Owner") == localPlayer.UserId then
            localCameraImpact()
        end
    end
end


-- M1 : le Stand passe devant le joueur pendant le coup léger et y reste un
-- moment après le dernier coup, pour ne pas faire d'allers-retours entre
-- deux clics du combo.
local JAB_HOLD_FRONT = 0.8 -- secondes devant après le dernier coup
local JAB_LUNGE = 0.9 -- élan vers l'avant à l'impact (en studs)
local DEFAULT_LIGHT_OFFSET = Vector3.new(0, 1.2, -3.2)
local lastJabAt = setmetatable({}, { __mode = "k" })

local function updateStand(stand, standDef, character, now)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not stand.PrimaryPart then return end

	local state = stand:GetAttribute("State") or "Idle"
	local started = stand:GetAttribute("StateStarted") or 0
	local t = now - started
	local summonDuration = standDef.SummonDuration or 1.25
	-- V9: hard visual cutoff from BOTH the absolute server deadline and
	-- the move duration. The animation is evaluated only for this time window.
	local barrage = standDef.Moves and standDef.Moves.Barrage
	if state == "Barrage" and barrage then
		local duration = math.min(barrage.Duration, barrage.Cooldown)
		local endsAt = stand:GetAttribute("BarrageEndsAt")
		if t >= duration or (typeof(endsAt) == "number" and endsAt > 0 and now >= endsAt) then
			state = "Idle"
		end
	end

	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)

	local moveDef = standDef.Moves and standDef.Moves[state]
	local targetPos, smooth
	if state == "Deploying" then
		local p = math.clamp(t / summonDuration, 0, 1)
		local rise = summonRise(p)
		local overshoot = math.sin(math.pi * smooth01((p - 0.43) / 0.49)) * 0.24
		targetPos = hrp.Position + hrp.CFrame:VectorToWorldSpace(standDef.FollowOffset)
			+ Vector3.new(0, -SUMMON_DROP * (1 - rise) + overshoot, 0)
			- flat * (0.38 * (1 - rise))
		smooth = p < 0.31 and 0.27 or 0.52
	elseif state == "Barrage" and moveDef and moveDef.BarrageOffset then
		local lunge = math.abs(math.sin(t * math.pi * 16)) * 1.1
		targetPos = hrp.Position + flat * (-moveDef.BarrageOffset.Z + lunge)
			+ Vector3.new(0, moveDef.BarrageOffset.Y + math.sin(now * 3) * 0.08, 0)
		smooth = moveDef.BarrageSmoothness
	elseif state == "HeavyPunch" and moveDef and moveDef.HeavyOffset then
		local strike = math.clamp((t - 0.22) / 0.13, 0, 1)
		local reach = 3 + strike * 1.7
		targetPos = hrp.Position + flat * reach + Vector3.new(0, moveDef.HeavyOffset.Y, 0)
		smooth = moveDef.HeavySmoothness
	elseif state == "LightPunchR" or state == "LightPunchL"
		or (state == "Idle" and lastJabAt[stand] and now - lastJabAt[stand] < JAB_HOLD_FRONT) then
		local jab = standDef.Moves and standDef.Moves.LightPunchR
		local offset = (jab and jab.LightOffset) or DEFAULT_LIGHT_OFFSET
		local lunge = 0
		if state ~= "Idle" then
			lastJabAt[stand] = now
			-- élan qui culmine à l'impact (~0.17 s) puis revient
			lunge = math.sin(math.pi * math.clamp((t - 0.04) / 0.3, 0, 1)) * JAB_LUNGE
		end
		targetPos = hrp.Position + flat * (-offset.Z + lunge)
			+ Vector3.new(0, offset.Y + math.sin(now * 1.55) * 0.06, 0)
		smooth = (jab and jab.LightSmoothness) or 0.45
	elseif moveDef and moveDef.Type then
		-- Attaques T / F / G : le Stand passe devant le joueur
		local forward = moveDef.StandForward or 3.4
		local lunge = math.sin(math.pi * math.clamp(t / math.max(moveDef.Duration or 0.6, 0.1), 0, 1)) * 0.8
		targetPos = hrp.Position + flat * (forward + lunge) + Vector3.new(0, 1.3, 0)
		smooth = 0.4
	elseif state == "TimeStop" and moveDef and moveDef.TimeStopOffset then
		targetPos = hrp.Position + flat * (-moveDef.TimeStopOffset.Z)
			+ Vector3.new(0, moveDef.TimeStopOffset.Y + math.sin(now * 1.4) * 0.12, 0)
		smooth = moveDef.TimeStopSmoothness
	else
        local bob = math.sin(now * 1.55) * 0.085
        targetPos = hrp.Position + hrp.CFrame:VectorToWorldSpace(standDef.FollowOffset) + Vector3.new(0, bob, 0)
        smooth = standDef.Smoothness
	end
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + flat)
	stand.PrimaryPart.CFrame = stand.PrimaryPart.CFrame:Lerp(targetCFrame, smooth)

	if state == "Deploying" then
		local p = math.clamp(t / summonDuration, 0, 1)
		fadeSummoningStand(stand, p, false)
		summonWasVisible[stand] = true
		-- Effects trigger once per newly replicated summon for each nearby client.
		if t < summonDuration then
			summonStart(stand, character, standDef)
			if p >= 0.48 then summonReveal(stand, standDef) end
			if p >= 0.82 then summonFinale(stand) end
		end
	elseif state == "Pose" then
		if summonWasVisible[stand] then
			fadeSummoningStand(stand, 1, true)
			summonWasVisible[stand] = nil
		end
		-- Golden flare the instant the iconic pose locks in.
		if not summonPoseStruck[stand] and stand.PrimaryPart then
			summonPoseStruck[stand] = true
			local pos = stand.PrimaryPart.Position
			local cam = workspace.CurrentCamera
			if cam and (cam.CFrame.Position - pos).Magnitude <= 160 then
				local anchor = centerAnchor(pos, 2)
				pulse(pos, 5.5, 0.5, SUMMON_GOLD, 0.6)
				pulse(pos, 3.4, 0.4, SUMMON_PURPLE, 0.7)
				burst(anchor, "SPV2_PoseFlare", SUMMON_GOLD, SUMMON_PINK, 36, 8, 0.6, 0.28)
			end
		end
	elseif summonWasVisible[stand] then
		fadeSummoningStand(stand, 1, true)
		summonWasVisible[stand] = nil
	end

	local rig = getRig(stand)
	rig.summonDuration = summonDuration
	animateStand(stand, state, t, now)
	updateBarrageVisuals(stand, state, t, now)
	updateHeavyPunchVisuals(stand, state, t, character)
end

RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local stand = workspace:FindFirstChild(player.Name .. "Stand")
			if stand then
				local standId = stand:GetAttribute("StandId")
				local standDef = standId and StandData.GetStand(standId)
				if standDef then
					updateStand(stand, standDef, character, now)
				end
			end
		end
	end
end)

local SPELL_KEYS = {
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.T] = "T",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.G] = "G",
}

local function actionForKey(keyName)
	local standId = localPlayer:GetAttribute("StandId")
	local def = (standId and StandData.GetStand(standId)) or StandData.GetStand(StandData.DefaultStand)
	if not def or not def.Moves then return nil end
	for name, move in pairs(def.Moves) do
		if move.Key == keyName and name ~= "LightPunchR" and name ~= "LightPunchL" then
			return name
		end
	end
	return nil
end

-- Ruée (attaques "Dash") : le serveur demande, le client pousse son
-- personnage puisqu'il possède sa physique.
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX").OnClientEvent:Connect(function(kind, speed, duration)
	if kind ~= "SpellDash" or typeof(speed) ~= "number" or typeof(duration) ~= "number" then return end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local endsAt = os.clock() + math.clamp(duration, 0, 1)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent or os.clock() >= endsAt then
			connection:Disconnect()
			if root.Parent then
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = flat * 16 + Vector3.new(0, v.Y, 0)
			end
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = flat * speed + Vector3.new(0, math.max(v.Y, 0), 0)
	end)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local character = localPlayer.Character
	if not character then return end

	-- Chaque Stand a ses attaques sur E / R / T / F / G (champ Key dans
	-- StandData et StandSpells) : on envoie celle du Stand équipé.
	local keyName = SPELL_KEYS[input.KeyCode]
	local fired = keyName and actionForKey(keyName)
	if fired then
		standAction:FireServer(fired)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		standAction:FireServer("Toggle")
	end
end)

-- ===================== M1 LIGHT PUNCH =====================
-- Left click jabs. A client gate spaces clicks just under the server's
-- cooldown (read from the stand data) so spam never reaches the remote.
local lastM1 = 0
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not localPlayer.Character then return end
	if localPlayer:GetAttribute("Standless") then return end
	local standId = localPlayer:GetAttribute("StandId")
	local standDef = (standId and StandData.GetStand(standId)) or StandData.GetStand(StandData.DefaultStand)
	local move = standDef and standDef.Moves and standDef.Moves.LightPunchR
	local gate = math.max((move and move.Cooldown or 0.6) - 0.05, 0.1)
	local now = os.clock()
	if now - lastM1 < gate then return end
	lastM1 = now
	standAction:FireServer("LightPunch")
end)

-- ===================== TIME STOP VOICE =====================

local function playTimeStopVoice()
	-- clean up any leftover voice rig from a previous cast
	for _, child in SoundService:GetChildren() do
		if child:GetAttribute("TimeStopVoice") then
			child:Destroy()
		end
	end

	local standId = localPlayer:GetAttribute("StandId") or "StarPlatinum"
	local standDef = StandData.GetStand(standId)

	-- recorded cry (TimeStopVoicePath mirrored as StandVoices/<StandId>/TimeStop)
	-- replaces the synthesized voice for stands that ship one (The World...)
	local recordedId = resolveVoiceId(standId, "TimeStop")
	if recordedId then
		local clip = Instance.new("Sound")
		clip.Name = "TimeStopVoice_Recorded"
		clip:SetAttribute("TimeStopVoice", true)
		clip.SoundId = recordedId
		clip.Volume = 1.2
		clip.Parent = SoundService
		clip:Play()
		clip.Ended:Once(function()
			clip:Destroy()
		end)
		task.delay(15, function()
			if clip.Parent then clip:Destroy() end
		end)
		return
	end

	-- dramatic impact sting under the cry
	local sting = Instance.new("Sound")
	sting.Name = "TimeStopSting"
	sting:SetAttribute("TimeStopVoice", true)
	sting.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sting.PlaybackSpeed = 0.45
	sting.Volume = 0.8
	sting.Parent = SoundService
	sting:Play()
	sting.Ended:Once(function()
		sting:Destroy()
	end)

	-- synthesized cry: "Star Platinum! The World!"
	local voice = Instance.new("AudioTextToSpeech")
	voice.Name = "TimeStopVoice_Gen"
	voice:SetAttribute("TimeStopVoice", true)
	voice.Text = (standDef and standDef.TimeStopCry) or "Time Stop!"
	local okVoice = pcall(function()
		voice.VoiceId = 3
	end)
	if not okVoice then
		voice.VoiceID = 3
	end
	voice.Pitch = -12
	voice.Speed = 1.1
	voice.Parent = SoundService

	local output = Instance.new("AudioDeviceOutput")
	output.Name = "TimeStopVoice_Out"
	output:SetAttribute("TimeStopVoice", true)
	output.Parent = SoundService

	local wire = Instance.new("Wire")
	wire.Name = "TimeStopVoice_Wire"
	wire:SetAttribute("TimeStopVoice", true)
	wire.SourceInstance = voice
	wire.TargetInstance = output
	wire.Parent = SoundService

	voice:Play()

	-- safety cleanup in case the Ended event never fires
	task.delay(10, function()
		if voice.Parent then voice:Destroy() end
		if wire.Parent then wire:Destroy() end
		if output.Parent then output:Destroy() end
	end)
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX").OnClientEvent:Connect(function(kind, duration)
	if kind == "TimeStop" then
		playTimeStopVoice()
	end
end)

print("[StandController] Ready")
