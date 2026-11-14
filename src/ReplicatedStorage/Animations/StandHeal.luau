-- StandHeal. GER's mercy gesture: the stand lifts its right arm in front of
-- its chest and folds the forearm up, palm open, channeling life energy into
-- the person the stand strikes. Hand-authored keyframes; edit freely.
local R15 = {
	Settings = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0.00] = {
			["RightUpperArm"] = CFrame.identity,
			["RightLowerArm"] = CFrame.identity,
			["Head"] = CFrame.identity,
		},
		[0.14] = {
			["RightUpperArm"] = CFrame.Angles(math.rad(-42), 0, math.rad(-12)),
			["RightLowerArm"] = CFrame.Angles(math.rad(50), 0, 0),
			["Head"] = CFrame.Angles(math.rad(5), math.rad(-8), 0),
		},
		[0.34] = {
			["RightUpperArm"] = CFrame.Angles(math.rad(-58), math.rad(6), math.rad(-18)),
			["RightLowerArm"] = CFrame.Angles(math.rad(104), 0, 0),
			["Head"] = CFrame.Angles(math.rad(8), math.rad(-12), 0),
		},
		[0.62] = {
			["RightUpperArm"] = CFrame.Angles(math.rad(-54), math.rad(2), math.rad(-15)),
			["RightLowerArm"] = CFrame.Angles(math.rad(92), 0, 0),
			["Head"] = CFrame.Angles(math.rad(6), math.rad(-10), 0),
		},
		[0.88] = {
			["RightUpperArm"] = CFrame.Angles(math.rad(-58), math.rad(6), math.rad(-18)),
			["RightLowerArm"] = CFrame.Angles(math.rad(106), 0, 0),
			["Head"] = CFrame.Angles(math.rad(8), math.rad(-12), 0),
		},
		[1.08] = {
			["RightUpperArm"] = CFrame.Angles(math.rad(-26), 0, math.rad(-8)),
			["RightLowerArm"] = CFrame.Angles(math.rad(34), 0, 0),
			["Head"] = CFrame.Angles(math.rad(3), math.rad(-5), 0),
		},
		[1.30] = {
			["RightUpperArm"] = CFrame.identity,
			["RightLowerArm"] = CFrame.identity,
			["Head"] = CFrame.identity,
		},
	},
}

-- R6 rigs have a single-piece arm (no elbow motor): raise it forward across
-- the chest so the channeling read stays close to the R15 silhouette.
local R6 = {
	Settings = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0.00] = {
			["Right Arm"] = CFrame.identity,
			["Head"] = CFrame.identity,
		},
		[0.16] = {
			["Right Arm"] = CFrame.Angles(math.rad(-72), 0, math.rad(-16)),
			["Head"] = CFrame.Angles(math.rad(6), math.rad(-10), 0),
		},
		[0.40] = {
			["Right Arm"] = CFrame.Angles(math.rad(-84), math.rad(8), math.rad(-22)),
			["Head"] = CFrame.Angles(math.rad(9), math.rad(-13), 0),
		},
		[0.70] = {
			["Right Arm"] = CFrame.Angles(math.rad(-78), math.rad(4), math.rad(-19)),
			["Head"] = CFrame.Angles(math.rad(7), math.rad(-11), 0),
		},
		[0.95] = {
			["Right Arm"] = CFrame.Angles(math.rad(-84), math.rad(8), math.rad(-22)),
			["Head"] = CFrame.Angles(math.rad(9), math.rad(-13), 0),
		},
		[1.12] = {
			["Right Arm"] = CFrame.Angles(math.rad(-30), 0, math.rad(-10)),
			["Head"] = CFrame.Angles(math.rad(3), math.rad(-5), 0),
		},
		[1.30] = {
			["Right Arm"] = CFrame.identity,
			["Head"] = CFrame.identity,
		},
	},
}

return { Rigs = { R6 = R6, R15 = R15 } }
