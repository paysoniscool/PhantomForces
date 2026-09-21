if getgenv().ns__PhantomPlus__Executed then
	return
end

getgenv().ns__PhantomPlus__Executed = true
pcall(clearteleportqueue or clear_teleport_queue or clearqueueonteleport)

local Module = loadstring(game:HttpGet("https://raw.githubusercontent.com/430L/PhantomPlus/refs/heads/main/core/Module.luau"))()

local clonerefFunction = cloneref or clone_ref or clonereference or clone_reference
local ns__cloneref = function(Object)
	if clonerefFunction then
		local Success, Result = pcall(clonerefFunction, Object)
		return Success and Result or Object
	end
	return Object
end

local VirtualInputManager = ns__cloneref(Instance.new("VirtualInputManager"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = ns__cloneref(game:GetService("CoreGui"))
local LocalPlayer, Terrain = Module.LocalPlayer, ns__cloneref(workspace.Terrain)

local IgnoreFolder = workspace:WaitForChild("Ignore", 9e9)
local DeadBodyFolder = IgnoreFolder:WaitForChild("DeadBody", 9e9)
local Camera, Map = workspace:WaitForChild("Camera", 9e9), workspace:WaitForChild("Map", 9e9)

local AimingRaycastParams = RaycastParams.new()
AimingRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
AimingRaycastParams.FilterDescendantsInstances = {IgnoreFolder, workspace:WaitForChild("Players", 9e9), workspace:WaitForChild("Roots", 9e9), Camera, Terrain}

local TransparentRaycastParams = RaycastParams.new()
TransparentRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local BulletRaycastParams = RaycastParams.new()
BulletRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
BulletRaycastParams.FilterDescendantsInstances = {IgnoreFolder, Camera, Terrain}

local GrenadeRaycastParams = RaycastParams.new()
GrenadeRaycastParams.FilterType = Enum.RaycastFilterType.Include
GrenadeRaycastParams.FilterDescendantsInstances = {Map}
GrenadeRaycastParams.IgnoreWater = true

local GrenadeImpactParams = RaycastParams.new()
GrenadeImpactParams.FilterType = Enum.RaycastFilterType.Include
GrenadeImpactParams.IgnoreWater = true

local function SetProperty(Object, Property, Value)
	if Object[Property] ~= Value then
		Object[Property] = Value
	end
end

local BodyParts = {"Head", "Torso", "Arms", "Legs"}
local DarkerColorCache = setmetatable({}, {__mode = "kv", __index = function(self, Color)
	local DarkerColor = Color3.new(Color.R * 0.85, Color.G * 0.85, Color.B * 0.85)
	rawset(self, Color, DarkerColor)
	return DarkerColor
end})

local function Create(Type, Parent, Properties, ...)
	local Object = ns__cloneref(Instance.new(Type))
	if Properties then
		for Property, Value in next, Properties do
			Object[Property] = Value
		end
	end

	if Parent then
		Object.Parent = Parent
	end

	if (...) then
		for _,Child in next, {...} do
			Child.Parent = Object
		end
	end

	return Object
end

local function CreateDrawing(Type, Properties)
	local DrawingObject = Drawing.new(Type)
	if Properties then
		for Property, Value in next, Properties do
			if Property == "NumSides" or Property == "Filled" then
				pcall(function()
					DrawingObject[Property] = Value
				end)
				continue
			end
			DrawingObject[Property] = Value
		end
	end
	return DrawingObject
end

local AimbotTarget = nil
local AimbotTargetPart = nil
local IsAimbotLocking = false
local IsAimbotTargetVisible = false

local Aiming = {
	Aimbot_Enabled = false,
	Aimbot_Keybind = "MB2",
	Aimbot_Type = "None",
	Aimbot_Part = "Head",
	Aimbot_Smoothness = 3,
	Aimbot_SmoothingMode = "Linear",
	Aimbot_TargetStickiness = 30,
	Aimbot_Prediction = false,
	Aimbot_AutoFire = false,
	Aimbot_AutoWall = false,
	Aimbot_AutoDelay = 0,
	Aimbot_SilentHitChance = 100,
	Aimbot_WallCheck = false,
	Aimbot_DeathNotification = true,
	Aimbot_ShowFOV = true,
	Aimbot_FOVColor = Color3.fromRGB(255, 255, 255),
	Aimbot_FOVOpacity = 0.5,
	Aimbot_FOVFollowRecoil = false,
	Aimbot_FOVRadius = 150,
	Aimbot_TargetTracer = true,
	Aimbot_TargetTracerColor = Color3.fromRGB(255, 255, 255),
	Aimbot_TargetTracerOpacity = 0.5,
	Aimbot_DynamicFOV = false,
	Aimbot_GrenadeRedirect = false,
	Aimbot_FuseAssist = false,

	RageBot_Enabled = false,
	RageBot_Keybind = "None",
	RageBot_Part = "Head",
	RageBot_WallPenetrationDetection = true,
	RageBot_MultiTarget = false,
	RageBot_HitScanning = true,
	RageBot_HitScanningMode = "Cardinal",
	RageBot_HitScanningRadius = 1,
	RageBot_FireScanning = true,
	RageBot_FireScanningMode = "Cardinal",
	RageBot_FireScanningRadius = 3,
	RageBot_FireScanningCount = 8,
	RageBot_Prediction = true
}

-- Aimkey input tracking (callback-driven, avoids GetState() in render loop)
local AimkeyBoundCode = nil
local AimkeyIsMB2 = false
local IsAimkeyDown = false

local function UpdateAimkeyBinding(keyName)
	if not keyName or keyName == "None" or keyName == "" then
		AimkeyBoundCode = nil
		AimkeyIsMB2 = false
	elseif keyName == "MB2" or keyName == "MouseButton2" then
		AimkeyBoundCode = nil
		AimkeyIsMB2 = true
	else
		AimkeyIsMB2 = false
		local ok, code = pcall(function() return Enum.KeyCode[keyName] end)
		AimkeyBoundCode = ok and code or nil
	end
	IsAimkeyDown = false
end

UpdateAimkeyBinding(Aiming.Aimbot_Keybind)

UserInputService.InputBegan:Connect(function(input, processed)
	if AimkeyIsMB2 and input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsAimkeyDown = true
		return
	end
	if processed then return end
	if AimkeyBoundCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == AimkeyBoundCode then
		IsAimkeyDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if AimkeyIsMB2 and input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsAimkeyDown = false
	elseif AimkeyBoundCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == AimkeyBoundCode then
		IsAimkeyDown = false
	end
end)

local Visuals = {
	Combat_BulletTracers = false,
	Combat_BulletTracerColor = Color3.fromRGB(255, 255, 255),
	Combat_BulletTracerAlpha = 0.85,
	Combat_BulletTracerWavy = false,
	Combat_BulletTracerFadeMode = "Width",
	Combat_BulletTracerThickness = 3.5,
	Combat_BulletTracerDuration = 0.55,
	Combat_HitMarkerEnabled = false,
	Combat_HitMarkerColor = Color3.fromRGB(255, 255, 255),
	Combat_HitMarkerStyle = "X",
	Combat_HitMarkerSize = 8,
	Combat_HitMarkerGap = 3,
	Combat_HitMarkerDuration = 0.5,
	Combat_HitMarkerSpin = false,
	Combat_HitMarkerSpinSpeed = 5,
	Combat_GrenadeTrajectory = false,
	Combat_GrenadeTrajectoryColor = Color3.fromRGB(255, 165, 0),
	Combat_GrenadeTrajectoryCustomImpact = false,
	Combat_GrenadeTrajectoryImpactColor = Color3.fromRGB(255, 50, 50),
	Combat_GrenadeTrajectoryBounces = 1,
	Combat_GrenadeTrajectoryThickness = 2,
	Combat_RadarHack = false,

	ESPVisuals_MasterEnabled = true,
	ESPVisuals_Keybind = "None",
	ESPVisuals_MasterOpacity = 100,
	ESPVisuals_Chams = false,
	ESPVisuals_ChamsColor = Color3.fromRGB(255, 0, 0),
	ESPVisuals_ChamsRendering = {Fill = true, Outline = true},
	ESPVisuals_ChamsStyle = "Solid",
	ESPVisuals_ChamsVisibleColor = Color3.fromRGB(0, 255, 0),
	ESPVisuals_ChamsOccluded = false,
	ESPVisuals_Dots = false,
	ESPVisuals_DotColor = Color3.fromRGB(255, 255, 255),
	ESPVisuals_DotSize = 3,
	ESPVisuals_Skeletons = false,
	ESPVisuals_SkeletonsColor = Color3.fromRGB(255, 255, 255),
	ESPVisuals_SkeletonsThickness = 1.5,
	ESPVisuals_HeadTags = false,
	ESPVisuals_TagColor = Color3.fromRGB(255, 255, 255),
	ESPVisuals_HeadTagElements = {Name = true, Health = true, Distance = true, Visibility = true},
	ESPVisuals_TagSize = 13,
	ESPVisuals_Boxes = false,
	ESPVisuals_BoxColor = Color3.fromRGB(255, 255, 255),
	ESPVisuals_Healthbars = false,
	ESPVisuals_HealthbarColor = Color3.fromRGB(0, 255, 0),
	ESPVisuals_HealthbarWidth = 5,
	ESPVisuals_BoxThickness = 1.5,
	ESPVisuals_Tracers = false,
	ESPVisuals_TracerColor = Color3.fromRGB(255, 255, 255),
	ESPVisuals_TracerTarget = "Torso",
	ESPVisuals_TracerOrigin = "Bottom",
	ESPVisuals_TracerThickness = 1.5,
	ESPVisuals_OffscreenArrows = false,
	ESPVisuals_OffscreenArrowColor = Color3.fromRGB(255, 255, 255),
	ESPVisuals_OffscreenArrowSize = 14,
	ESPVisuals_OffscreenArrowDistance = 300,
	ESPVisuals_GrenadeTags = false,
	ESPVisuals_GrenadeTagColor = Color3.fromRGB(255, 165, 0),

	Camera_NoBob = false,
	Camera_NoSuppression = false,
	Camera_FOVModificationEnabled = false,
	Camera_ApplyToAim = false,
	Camera_FOVValue = 120,
	Camera_ThirdPersonView = false,
	Camera_ThirdPersonViewKeybind = "None",
	Camera_ThirdPersonCameraCollision = true,
	Camera_ThirdPersonHideViewModel = false,
	Camera_ThirdPersonOffsetX = 0,
	Camera_ThirdPersonOffsetY = 0,
	Camera_ThirdPersonOffsetZ = 7,
	Camera_ThirdPersonShowCharacter = false,
	Camera_ThirdPersonShowCharacterWhileAiming = false,
	Camera_ThirdPersonApplyAntiAimToCharacter = true,

	Viewmodel_Chams = false,
	Viewmodel_ChamsColor = Color3.fromRGB(100, 0, 255),
	Viewmodel_ChamsTargets = {Arms = true, Weapon = true},
	Viewmodel_ChamsType = "ForceField",
	Viewmodel_ChamsTranslucent = false,
	Viewmodel_NoSleeves = false,
	Viewmodel_CustomOffset = false,
	Viewmodel_OffsetX = 0,
	Viewmodel_OffsetY = 0,
	Viewmodel_OffsetZ = 0,
	Viewmodel_CustomRotation = false,
	Viewmodel_RotationX = 0,
	Viewmodel_RotationY = 0,
	Viewmodel_RotationZ = 0,
	Viewmodel_CustomRoll = false,
	Viewmodel_Roll = 0,

	Lighting_ModifyLighting = false,
	Lighting_ExposureCompensation = 0.5,
	Lighting_Ambient = Color3.fromRGB(150, 150, 150),
	Lighting_OutdoorAmbient = Color3.fromRGB(150, 150, 150),
	Lighting_EnvironmentDiffuseScale = 0.5,
	Lighting_EnvironmentSpecularScale = 0.5,
	Lighting_ShadowSoftness = 0.5,
	Lighting_Flashlight = false,
	Lighting_FlashlightColor = Color3.fromRGB(177, 165, 165),
	Lighting_FlashlightBrightness = 4,
	Lighting_FlashlightRange = 60,
	Lighting_FlashlightAngle = 70,

	Combat_CustomGrenadeFuse = false,
	Combat_FuseOnImpact = false,
	Combat_FuseAmount = 5
}

local Miscellaneous = {
	WeaponMods_RecoilAdjustment = 100,
	WeaponMods_SpreadAdjustment = 100,
	WeaponMods_NoWeaponSway = false,
	WeaponMods_NoScopeSway = false,
	WeaponMods_NoWalkSway = false,

	WeaponMods_AutomaticGun = false,
	WeaponMods_InstantReload = false,
	WeaponMods_InstantEquip = false,
	WeaponMods_InstantAim = false,
	WeaponMods_UncookableGrenade = false,

	HitLogs_Enabled = false,
	HitLogs_ShowDamage = false,
	HitLogs_ShowDistance = false,

	SoundOverride_ShootSound = "None",
	SoundOverride_HitSound = "None",
	SoundOverride_KillSound = "None",
	SoundOverride_GotHitSound = "None",

	RagdollEffects_Mode = "None",
	RagdollEffects_LaunchForce = 150,
	RagdollEffects_FlingForce = 150,
	RagdollEffects_FloatSpeed = 10,

	KnifeAura_Enabled = false,
	KnifeAura_Keybind = "None",
	KnifeAura_Range = 10,
	KnifeAura_Delay = 0.35,
	KnifeAura_Wallbang = true,
	KnifeAura_MultiHit = false,
	KnifeAura_Part = "Head",

	Movement_NoFallDamage = false,
	Movement_BunnyHop = false,
	Movement_BunnyHopKeybind = "None",
	Movement_NoSlideCooldown = false,
	Movement_Speed = false,
	Movement_SpeedKeybind = "None",
	Movement_SpeedAmount = 16,
	Movement_Fly = false,
	Movement_FlyKeybind = "None",
	Movement_FlySpeed = 16,

	AntiAim_Enabled = false,
	AntiAim_Keybind = "None",
	AntiAim_Yaw = false,
	AntiAim_YawMode = "Custom - Relative",
	AntiAim_YawAmount = 180,
	AntiAim_YawSpeed = 5,
	AntiAim_Pitch = false,
	AntiAim_PitchMode = "Custom - Relative",
	AntiAim_PitchAmount = 90,
	AntiAim_PitchSpeed = 5,
	AntiAim_Jitter = false,
	AntiAim_JitterAmount = 30,
	AntiAim_SpinBot = false,
	AntiAim_SpinDirection = "Right",
	AntiAim_SpinSpeed = 360,

	Extras_LoopBreakAllWindows = false,
	Extras_HopOnVotekick = false,

	ClientSessionUnlocks_AttachmentsUnlocked = false,
	ClientSessionUnlocks_CamosUnlocked = false,
	ClientSessionUnlocks_KnivesUnlocked = false
}

local Settings = {
	Advanced_MultiPointEnabled = true,
	Advanced_MultiPointLayers = 2,
	Advanced_MultiPointScale = 2,
	Debug_PassthroughACPackets = false
}

local LightingCache = {
	OriginalValues = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		ShadowSoftness = Lighting.ShadowSoftness,
		LightingStyle = Lighting.LightingStyle
	}, Connections = {}
}
local MovementCache = table.create(Module.Players.MaxPlayers)

local function RefreshLighting(Revert)
	if not Revert then
		Lighting.Ambient = Visuals.Lighting_Ambient
		Lighting.OutdoorAmbient = Visuals.Lighting_OutdoorAmbient
		Lighting.ExposureCompensation = Visuals.Lighting_ExposureCompensation
		Lighting.EnvironmentDiffuseScale = Visuals.Lighting_EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = Visuals.Lighting_EnvironmentSpecularScale
		Lighting.ShadowSoftness = Visuals.Lighting_ShadowSoftness
		return
	end

	for Property, OriginalValue in next, LightingCache.OriginalValues do
		Lighting[Property] = OriginalValue
	end
end

local WeaponControllerInterface = Module.__get("WeaponControllerInterface")
local PlayerDataClientInterface = Module.__get("PlayerDataClientInterface")
local ReplicationInterface = Module.__get("ReplicationInterface")
local CharacterInterface = Module.__get("CharacterInterface")
local _,CameraInterface = coroutine.resume(coroutine.create(function(CameraInterface)
	pcall(function()
		local FunctionEnvironment = getfenv(CameraInterface.setCameraType)
		FunctionEnvironment.warn = function() end
		FunctionEnvironment.print = function() end
	end)
	return CameraInterface
end), Module.__get("CameraInterface"))

local PlayerDataUtils = Module.__get("PlayerDataUtils")
local PublicSettings = Module.__get("PublicSettings")
local FirearmObject = Module.__get("FirearmObject")
local NetworkClient = Module.__get("NetworkClient")
local CharacterObject = Module.__get("CharacterObject")
local AudioSystem = Module.__get("AudioSystem")
local BulletCheck = Module.__get("BulletCheck")
local GrenadeObject = Module.__get("GrenadeObject")
local MeleeObject = Module.__get("MeleeObject")
local RoundSystemClient = Module.__get("RoundSystemClientInterface")
local Effects = Module.__get("Effects")

local MuzzleFlash = Effects.muzzleflash
local FireImpulse = Module.__get("HudCrosshairsInterface").fireImpulse
local GetGameClockTime = Module.__get("GameClock").getTime

local function GetCharacter(Entry)
	local ThirdPersonObject = Entry._thirdPersonObject
	local Character = ThirdPersonObject and ThirdPersonObject._characterModelHash
	local Head = Character and Character.Head
	if Head and Head.Parent then
		return Character
	end
end

local NetworkClientSend = NetworkClient.send
local GetLocalCharacter = CharacterInterface.getCharacterObject
local GetActiveCamera = CameraInterface.getActiveCamera
local PlayGameSound = AudioSystem.play
local GetPlayerStatusEntry = Module.__get("PlayerStatusInterface").getEntry
local GetPlayerEntry = ReplicationInterface.getEntry
local OperateOnAllEntries = ReplicationInterface.operateOnAllEntries

local BulletLifeTime = PublicSettings.bulletLifeTime
local BulletAcceleration = PublicSettings.bulletAcceleration

local function GetActiveWeapon()
	local ActiveWeaponController = WeaponControllerInterface.getActiveWeaponController()
	if ActiveWeaponController then
		return ActiveWeaponController:getActiveWeapon()
	end
end

local LocalHead = nil
local function GetLocalPosition()
	if not LocalHead or not LocalHead.Parent then
		for _,Child in next, IgnoreFolder:GetChildren() do
			local Head = Child:IsA("Model") and Child:FindFirstChild("Head")
			if Head then
				LocalHead = Head
				return Head.Position
			end
		end
		return Camera.CFrame.Position
	end
	return LocalHead.Position
end

local function SolvePolynomial(Coeff1, Coeff2, Coeff3, Coeff4, Coeff5)
	if not Coeff1 then
		return
	end

	if Coeff1 > -1e-10 and Coeff1 < 1e-10 then
		return SolvePolynomial(Coeff2, Coeff3, Coeff4, Coeff5)
	end

	if Coeff5 then
		local QuarticShift = -Coeff2 / (4 * Coeff1)
		local DepressedB = (Coeff3 + QuarticShift * (3 * Coeff2 + 6 * Coeff1 * QuarticShift)) / Coeff1
		local DepressedC = (Coeff4 + QuarticShift * (2 * Coeff3 + QuarticShift * (3 * Coeff2 + 4 * Coeff1 * QuarticShift))) / Coeff1
		local DepressedD = (Coeff5 + QuarticShift * (Coeff4 + QuarticShift * (Coeff3 + QuarticShift * (Coeff2 + Coeff1 * QuarticShift)))) / Coeff1
		if DepressedC > -1e-10 and DepressedC < 1e-10 then
			local BiquadRoot1, BiquadRoot2 = SolvePolynomial(1, DepressedB, DepressedD)
			if BiquadRoot2 and not (BiquadRoot2 < 0) then
				local RootSqrt1 = math.sqrt(BiquadRoot1)
				local RootSqrt2 = math.sqrt(BiquadRoot2)
				return QuarticShift - RootSqrt2, QuarticShift - RootSqrt1, QuarticShift + RootSqrt1, QuarticShift + RootSqrt2
			end
			return
		end

		local Resolvent,_,CubicRoot = SolvePolynomial(1, 2 * DepressedB, DepressedB * DepressedB - 4 * DepressedD, -DepressedC * DepressedC)
		local Base = CubicRoot or Resolvent
		local ResolventRoot = math.sqrt(Base)
		local QuadraticA1, QuadraticA2 = SolvePolynomial(1, ResolventRoot, (Base + DepressedB - DepressedC / ResolventRoot) * 0.5)
		local QuadraticB1, QuadraticB2 = SolvePolynomial(1, -ResolventRoot, (Base + DepressedB + DepressedC / ResolventRoot) * 0.5)
		if QuadraticA1 and QuadraticB1 then
			return QuarticShift + QuadraticA1, QuarticShift + QuadraticA2, QuarticShift + QuadraticB1, QuarticShift + QuadraticB2
		end

		if QuadraticA1 then
			return QuarticShift + QuadraticA1, QuarticShift + QuadraticA2
		end

		if QuadraticB1 then
			return QuarticShift + QuadraticB1, QuarticShift + QuadraticB2
		end
	elseif Coeff4 then
		local CubicShift = -Coeff2 / (3 * Coeff1)
		local CubicP = -(Coeff3 + CubicShift * (2 * Coeff2 + 3 * Coeff1 * CubicShift)) / (3 * Coeff1)
		local CubicQ = -(Coeff4 + CubicShift * (Coeff3 + CubicShift * (Coeff2 + Coeff1 * CubicShift))) / (2 * Coeff1)
		local Discriminant = CubicQ * CubicQ - CubicP * CubicP * CubicP
		local AbsDisc = math.sqrt(math.abs(Discriminant))
		if not (Discriminant > 0) then
			local Angle = math.atan2(AbsDisc, CubicQ) / 3
			local Spread = math.sqrt(CubicP) * 2
			return CubicShift - Spread * math.sin(Angle + 0.5235987755982988), CubicShift + Spread * math.sin(Angle - 0.5235987755982988), CubicShift + Spread * math.cos(Angle)
		end

		local CubeTermA = CubicQ + AbsDisc
		local CubeTermB = CubicQ - AbsDisc
		local CubeRootA = CubeTermA < 0 and -(-CubeTermA) ^ 0.3333333333333333 or CubeTermA ^ 0.3333333333333333
		local CubeRootB
		if CubeTermB < 0 then
			CubeRootB = -(-CubeTermB) ^ 0.3333333333333333
			if CubeRootB then
				return CubicShift + CubeRootA + CubeRootB
			else
				CubeRootB = CubeTermB ^ 0.3333333333333333
				return CubicShift + CubeRootA + CubeRootB
			end
		else
			CubeRootB = CubeTermB ^ 0.3333333333333333
			return CubicShift + CubeRootA + CubeRootB
		end
	elseif Coeff3 then
		local Vertex = -Coeff2 / (2 * Coeff1)
		local Discriminant = Vertex * Vertex - Coeff3 / Coeff1
		if Discriminant < 0 then
			return
		end

		local Spread = math.sqrt(Discriminant)
		return Vertex - Spread, Vertex + Spread
	elseif Coeff2 then
		return -Coeff2 / Coeff1
	end
end

local function MinPositive(...)
	local Best = nil
	for Index = 1, select("#", ...) do
		local Value = select(Index, ...)
		if not (Value < 0 or Best and Best < Value) then
			Best = Value
		end
	end
	return Best
end

local BallisticsModule = {}

function BallisticsModule:Solve(Origin, Target, Speed, TargetVelocity, Gravity, BulletAccel)
	local Delta, RelativeVelocity, RelativeAcceleration = Target - Origin, TargetVelocity, Vector3.zero - Gravity
	local Time = MinPositive(SolvePolynomial(
		RelativeAcceleration:Dot(RelativeAcceleration) - BulletAccel * BulletAccel, 4 * (RelativeAcceleration:Dot(
			RelativeVelocity
		) - BulletAccel * Speed),4 * (RelativeAcceleration:Dot(Delta) + RelativeVelocity:Dot(
			RelativeVelocity) - Speed * Speed
		), 8 * Delta:Dot(RelativeVelocity), 4 * Delta:Dot(Delta)
	))

	if Time then
		return (Delta + Time * RelativeVelocity + Time * Time / 2 * RelativeAcceleration) / (Time * Speed + Time * Time / 2 * BulletAccel), Time
	end
end

local function GetTrajectory(Origin, Acceleration, Target, Speed, Velocity)
	local Weapon = GetActiveWeapon()
	local BulletAccel = Weapon and Weapon:getWeaponStat("bulletaccel") or 0
	local Direction = BallisticsModule:Solve(Origin, Target, Speed, Velocity or Vector3.zero, Acceleration, BulletAccel)
	if Direction then
		return Direction * Speed
	end
end

local function GetBulletVelocity(Origin, Target, Speed)
	local Gravity = -BulletAcceleration
	local Displacement = Target - Origin

	local AccelerationSquared = Gravity:Dot(Gravity)
	if AccelerationSquared <= 1e-12 then
		local Distance = Displacement.Magnitude
		if Distance <= 1e-6 then
			return nil
		end
		return Displacement / Distance * Speed, Distance / Speed
	end

	local MidTimeSquared = (2 * (Gravity:Dot(Displacement) + Speed * Speed)) / AccelerationSquared
	local Discriminant = MidTimeSquared * MidTimeSquared - (4 * Displacement:Dot(Displacement)) / AccelerationSquared
	if Discriminant < 0 then
		return nil
	end

	local Root = Discriminant ^ 0.5
	local TimeLow, TimeHigh = MidTimeSquared - Root, MidTimeSquared + Root
	local TimeSquared = TimeLow < 0 and TimeHigh or TimeLow
	if TimeSquared < 0 then
		return nil
	end

	local Time = TimeSquared ^ 0.5
	return Gravity * Time * 0.5 + Displacement / Time, Time
end

local ViewportSize = Camera.ViewportSize
local ViewportSizeX, ViewportSizeY = ViewportSize.X, ViewportSize.Y
local ScreenXCenter, ScreenYCenter = ViewportSizeX * 0.5, ViewportSizeY * 0.5
local ScreenBottom, ScreenTop = Vector2.new(ScreenXCenter, ViewportSizeY), Vector2.new(ScreenXCenter, 0)
local ScreenCenter = Vector2.new(ScreenXCenter, ScreenYCenter)
local ScreenCenterX, ScreenCenterY = ScreenCenter.X, ScreenCenter.Y
local TwoPi, Quarter = math.pi * 2, math.pi * 0.5

local function WorldToViewportPoint(Position, KeepZ)
	local Screen, OnScreen = Camera:WorldToViewportPoint(Position)
	return Vector2.new(Screen.X, Screen.Y), OnScreen
end

local function GetFOVOrigin()
	if Aiming.Aimbot_FOVFollowRecoil then
		local Weapon = GetActiveWeapon()
		if Weapon then
			local Barrel = Weapon._barrelPart
			if Barrel then
				local Screen, OnScreen = WorldToViewportPoint(Barrel.CFrame * Vector3.new(0, 0, -100))
				if OnScreen then
					return Screen
				end
			end
		end
	end
	return ScreenCenter
end

local TransparentRaycastExcluded = {}
local function TransparentRaycast(Origin, Direction, BaseFilter)
	local BaseList = BaseFilter.FilterDescendantsInstances
	local BaseCount = #BaseList
	for Index = 1, BaseCount do
		TransparentRaycastExcluded[Index] = BaseList[Index]
	end

	local ExcludedCount, RemainingDirection, RemainingOrigin = BaseCount, Direction, Origin
	for _ = 1, 8 do
		for Index = ExcludedCount + 1, #TransparentRaycastExcluded do
			TransparentRaycastExcluded[Index] = nil
		end

		TransparentRaycastParams.FilterDescendantsInstances = TransparentRaycastExcluded
		local Result = workspace:Raycast(RemainingOrigin, RemainingDirection, TransparentRaycastParams)
		if not Result then
			return
		end

		local Hit = Result.Instance
		if Hit.Transparency > 0.9 then
			ExcludedCount += 1
			TransparentRaycastExcluded[ExcludedCount] = Hit
			local FixedDirection = Direction.Unit * 0.01
			RemainingDirection = RemainingDirection - (Result.Position - RemainingOrigin) - FixedDirection
			RemainingOrigin = Result.Position + FixedDirection
			continue
		end

		return Result
	end
end

local function DrawBone(Line, PointA, PointB)
	if PointA and PointB then
		local ScreenA, OnA = WorldToViewportPoint(PointA)
		local ScreenB, OnB = WorldToViewportPoint(PointB)
		if OnA and OnB then
			SetProperty(Line, "From", ScreenA)
			SetProperty(Line, "To", ScreenB)
			SetProperty(Line, "Visible", true)
			return
		end
	end
	SetProperty(Line, "Visible", false)
end

local GoldenAngle = math.pi * (3 - math.sqrt(5))
local MultiPointCache = {}
local function GetOffsets(Points)
	local BasePoints = MultiPointCache[Points]
	if BasePoints then
		return BasePoints
	end

	local Step = 2 / Points
	local NewPoints = table.create(Points)
	for Index = 1, Points do
		local IndexOffset = Index - 1
		local Y = IndexOffset * Step - 1 + Step * 0.5
		local Radius, Angle = math.sqrt(math.max(0, 1 - Y * Y)), IndexOffset * GoldenAngle
		NewPoints[Index] = Vector3.new(math.cos(Angle) * Radius, Y, math.sin(Angle) * Radius)
	end

	MultiPointCache[Points] = NewPoints
	return NewPoints
end

local CanSeeFrameCounter = 0
local CanSeeCachePool = {}
local CanSeeCache = {}

local function GetCanSeeCache(Result, Layers)
	local Entry = table.remove(CanSeeCachePool)
	if Entry then
		Entry[1] = Result
		Entry[2] = CanSeeFrameCounter
		Entry[3] = Layers
		return Entry
	end
	return {Result, CanSeeFrameCounter, Layers}
end

local function CanSee(Part)
	local Layers, Entry = Settings.Advanced_MultiPointLayers, CanSeeCache[Part]
	if Entry and Entry[2] == CanSeeFrameCounter and Entry[3] == Layers then
		return Entry[1]
	end

	local Origin = GetLocalPosition()
	local Position = Part.Position
	local Delta = Position - Origin

	if not TransparentRaycast(Origin, Delta, AimingRaycastParams) then
		CanSeeCache[Part] = GetCanSeeCache(true, Layers)
		return true
	end

	if not Settings.Advanced_MultiPointEnabled then
		CanSeeCache[Part] = GetCanSeeCache(false, Layers)
		return
	end

	local PartCFrame = Part.CFrame
	local ObjectDelta = PartCFrame:VectorToObjectSpace(Origin - Position)
	local ObjectMagnitude = ObjectDelta.Magnitude

	if ObjectMagnitude <= 1e-6 then
		CanSeeCache[Part] = GetCanSeeCache(false, Layers)
		return
	end

	local ViewDirection = ObjectDelta * (1 / ObjectMagnitude)
	local ViewDirectionX, ViewDirectionY, ViewDirectionZ = ViewDirection.X, ViewDirection.Y, ViewDirection.Z

	local HalfSize = Part.Size * 0.5
	local HalfSizeX, HalfSizeY, HalfSizeZ = HalfSize.X, HalfSize.Y, HalfSize.Z
	local RightVector, UpVector, LookVector = PartCFrame.RightVector, PartCFrame.UpVector, PartCFrame.LookVector

	local Offsets = GetOffsets(Settings.Advanced_MultiPointScale)
	local Count = #Offsets

	local ActiveLayers = math.clamp(math.floor(1 + math.log(1 + 4 / math.max(Delta.Magnitude, 0.1))), 1, Layers)
	for Layer = ActiveLayers, 1, -1 do
		local LayerScale = Layer / ActiveLayers
		local LayerScaleX, LayerScaleY, LayerScaleZ = LayerScale * HalfSizeX, LayerScale * HalfSizeY, LayerScale * HalfSizeZ
		for Index = 1, Count do
			local Point  = Offsets[Index]
			local PointX, PointY, PointZ = Point.X, Point.Y, Point.Z

			if PointX * ViewDirectionX + PointY * ViewDirectionY + PointZ * ViewDirectionZ <= 0 then
				continue
			end

			if not TransparentRaycast(Origin, (Position + RightVector * (PointX * LayerScaleX) + UpVector * (
				PointY * LayerScaleY
			) + LookVector * (PointZ * LayerScaleZ)) - Origin, AimingRaycastParams) then
				CanSeeCache[Part] = GetCanSeeCache(true, Layers)
				return true
			end
		end
	end

	CanSeeCache[Part] = GetCanSeeCache(false, Layers)
end

local RaycastStep = 1/60
local RageBotModule = {NextShot = 0}

local HitScanSphereOffsets = {}
for Index = 0, 11 do
	local Height = 1 - (Index / 11) * 2
	local Ring = math.sqrt(math.max(0, 1 - Height * Height))
	local Theta = GoldenAngle * Index
	HitScanSphereOffsets[Index + 1] = Vector3.new(math.cos(Theta) * Ring, Height, math.sin(Theta) * Ring)
end

local CardinalAxes = {Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis}
local CornerSigns = {
	{-1, -1, -1, -Vector3.one.Unit}, {-1, -1, 1, Vector3.new(-1, -1, 1).Unit},
	{-1, 1, -1, Vector3.new(-1, 1, -1).Unit}, {-1, 1, 1, Vector3.new(-1, 1, 1).Unit},
	{1, -1, -1, Vector3.new(1, -1, -1).Unit}, {1, -1, 1, Vector3.new(1, -1, 1).Unit},
	{1, 1, -1, Vector3.new(1, 1, -1).Unit}, {1, 1, 1, Vector3.one.Unit},
}

local FireScanningSphereCount = -1

function RageBotModule:GetHitPoints(Origin, Part)
	local Center = Part.Position
	local Points, Facing = {Center}, Origin - Center
	local Distance = Facing.Magnitude
	if Distance <= 1e-6 then
		return Points
	end

	local Mode = Aiming.RageBot_HitScanningMode
	Facing *= 1 / Distance

	if Mode == "Cardinal" then
		local Radius = Aiming.RageBot_HitScanningRadius
		for _,Axis in next, CardinalAxes do
			if Axis.X * Facing.X + Axis.Y * Facing.Y + Axis.Z * Facing.Z > -0.2 then
				Points[#Points + 1] = Center + Axis * Radius
			end
		end
	elseif Mode == "Sphere" then
		local Radius = Aiming.RageBot_HitScanningRadius
		for _,Offset in next, HitScanSphereOffsets do
			if Offset.X * Facing.X + Offset.Y * Facing.Y + Offset.Z * Facing.Z > -0.2 then
				Points[#Points + 1] = Center + Offset * Radius
			end
		end
	else
		local Radius, HalfSize = Aiming.RageBot_HitScanningRadius, Part.Size * 0.5
		for _,Sign in next, CornerSigns do
			local Corner = Vector3.new(Sign[1] * HalfSize.X, Sign[2] * HalfSize.Y, Sign[3] * HalfSize.Z)
			local Direction = Corner.Magnitude > 1e-6 and Corner.Unit or Facing
			if Direction.X * Facing.X + Direction.Y * Facing.Y + Direction.Z * Facing.Z > -0.2 then
				Points[#Points + 1] = Center + Corner + Direction * Radius * 0.5
			end
		end
	end
	return Points
end

function RageBotModule:GetFireOrigins(Origin)
	local Origins = {Origin}
	if Aiming.RageBot_FireScanning then
		local Radius, Mode = Aiming.RageBot_FireScanningRadius, Aiming.RageBot_FireScanningMode
		if Mode == "Sphere" then
			local Count = Aiming.RageBot_FireScanningCount
			if FireScanningSphereCount ~= Count then
				local Offsets = {}
				for Index = 0, Count - 1 do
					local Height = Count == 1 and 0 or 1 - (Index / (Count - 1)) * 2
					local Ring = math.sqrt(math.max(0, 1 - Height * Height))
					local Theta = GoldenAngle * Index
					Offsets[Index + 1] = Vector3.new(math.cos(Theta) * Ring, Height, math.sin(Theta) * Ring)
				end
				FireScanningSphereCount, Count = Count, Offsets
			end

			for _,Offset in next, Count do
				Origins[#Origins + 1] = Origin + Offset * Radius
			end
		elseif Mode == "Corners" then
			for _,Sign in next, CornerSigns do
				Origins[#Origins + 1] = Origin + Sign[4] * Radius
			end
		else
			for _,Axis in next, CardinalAxes do
				Origins[#Origins + 1] = Origin + Axis * Radius
			end
		end
	end
	return Origins
end

function RageBotModule:SolveEntry(Targets, TargetCount, IsPart, Origins, BulletSpeed, Penetration, PenetrationDepth, Cache)
	local LifeTime = BulletSpeed * BulletLifeTime
	local function CheckShot(FireOrigin, AimAt, Part, IsInstance)
		local ShotDelta = AimAt - FireOrigin
		if ShotDelta.Magnitude > LifeTime then
			return
		end

		local BulletVelocity = GetBulletVelocity(FireOrigin, AimAt, BulletSpeed)
		if not BulletVelocity then
			return
		end

		if Penetration then
			if not TransparentRaycast(FireOrigin, ShotDelta, AimingRaycastParams) or BulletCheck(FireOrigin, AimAt, BulletVelocity, BulletAcceleration, PenetrationDepth, RaycastStep) then
				return FireOrigin, AimAt, BulletVelocity, IsInstance and Part
			end
		elseif not TransparentRaycast(FireOrigin, ShotDelta, AimingRaycastParams) then
			return FireOrigin, AimAt, BulletVelocity, IsInstance and Part
		end
	end

	for _,FireOrigin in next, Origins do
		for TargetIndex = 1, TargetCount do
			local TargetPart, IsPart = Targets[TargetIndex], IsPart[TargetIndex]
			local SolvedOrigin, SolvedTarget, SolvedVelocity, SolvedPart = CheckShot(FireOrigin, IsPart and TargetPart.Position or TargetPart, TargetPart, IsPart)
			if SolvedOrigin then
				return SolvedOrigin, SolvedTarget, SolvedVelocity, SolvedPart
			end
		end
	end

	if Aiming.RageBot_HitScanning then
		for _,Origin in next, Origins do
			for TargetIndex = 1, TargetCount do
				local TargetPart, IsInstance = Targets[TargetIndex], IsPart[TargetIndex]
				if IsInstance then
					local Candidates = Cache and Cache[TargetPart]
					if not Candidates then
						Candidates = self:GetHitPoints(Origin, TargetPart)
						if Cache then
							Cache[TargetPart] = Candidates
						end
					end

					for CandidateIndex = 2, #Candidates do
						local SolvedOrigin, SolvedTarget, SolvedVelocity, SolvedPart = CheckShot(Origin, Candidates[CandidateIndex], TargetPart, true)
						if SolvedOrigin then
							return SolvedOrigin, SolvedTarget, SolvedVelocity, SolvedPart
						end
					end
				end
			end
		end
	end
end

function RageBotModule:GetTargets(Entry, Targets, IsPart)
	local Character = Entry._thirdPersonObject._characterModelHash
	local Head, Torso = Character.Head, Character.Torso
	local LeftArm, RightArm = Character["Left Arm"], Character["Right Arm"]
	local LeftLeg, RightLeg = Character["Left Leg"], Character["Right Leg"]
	local RageBotPart = Aiming.RageBot_Part

	local Count = 0

	if RageBotPart == "Head" then
		if Head then
			Count = 1
			Targets[1] = Head
			IsPart[1] = true
		end
	elseif RageBotPart == "Torso" then
		if Torso then
			Count = 1
			Targets[1] = Torso
			IsPart[1] = true
		end
	elseif RageBotPart == "Best" then
		for _,Name in ipairs(BodyParts) do
			if Name == "Head" then
				if Head then
					Count += 1
					Targets[Count] = Head
					IsPart[Count] = true
				end
			elseif Name == "Torso" then
				if Torso then
					Count += 1
					Targets[Count] = Torso
					IsPart[Count] = true
				end
			else
				local PartA, PartB
				if Name == "Arms" then
					PartA, PartB = LeftArm, RightArm
				else
					PartA, PartB = LeftLeg, RightLeg
				end

				if PartA then
					Count += 1
					Targets[Count] = PartA
					IsPart[Count] = true
				end

				if PartB then
					Count += 1
					Targets[Count] = PartB
					IsPart[Count] = true
				end
			end
		end
	end

	if Count == 0 then
		Count = 1
		Targets[1] = Entry._receivedPosition
		IsPart[1] = false
	end

	return Count
end

function RageBotModule:GetHitPartName(Character, HitPart)
	return ((not HitPart or HitPart == Character.Head) and "Head") or (HitPart == Character.Torso and "Torso") or (
		HitPart == Character["Left Arm"] and "Left Arm"
	) or (HitPart == Character["Right Arm"] and "Right Arm") or (
		HitPart == Character["Left Leg"] and "Left Leg"
	) or (HitPart == Character["Right Leg"] and "Right Leg") or "Head"
end

local function GetTargetPart(Character, AimbotPart, IsWallCheckOff)
	local Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg = Character.Head, Character.Torso, Character["Left Arm"], Character["Right Arm"], Character["Left Leg"], Character["Right Leg"]
	if AimbotPart == "Head" then
		if not Head then
			return nil, nil, false
		end

		local Screen, OnScreen = WorldToViewportPoint(Head.Position)
		if not OnScreen then
			return nil, nil, false
		end

		local Status = CanSee(Head)
		if IsWallCheckOff or Status then
			return Head, Screen, Status
		end

		return nil, nil, false
	elseif AimbotPart == "Torso" then
		if not Torso then
			return nil, nil, false
		end

		local Screen, OnScreen = WorldToViewportPoint(Torso.Position)
		if not OnScreen then
			return nil, nil, false
		end

		local Status = CanSee(Torso)
		if IsWallCheckOff or Status then
			return Torso, Screen, Status
		end

		return nil, nil, false
	elseif AimbotPart == "Best" then
		for _,Name in ipairs(BodyParts) do
			if Name == "Head" then
				if Head then
					local Screen, OnScreen = WorldToViewportPoint(Head.Position)
					if OnScreen then
						local Status = CanSee(Head)
						if IsWallCheckOff or Status then
							return Head, Screen, Status
						end
					end
				end
			elseif Name == "Torso" then
				if Torso then
					local Screen, OnScreen = WorldToViewportPoint(Torso.Position)
					if OnScreen then
						local Status = CanSee(Torso)
						if IsWallCheckOff or Status then
							return Torso, Screen, Status
						end
					end
				end
			else
				local PartA, PartB = Name == "Arms" and LeftArm or LeftLeg, Name == "Arms" and RightArm or RightLeg
				if PartA then
					local Screen, OnScreen = WorldToViewportPoint(PartA.Position)
					if OnScreen then
						local Status = CanSee(PartA)
						if IsWallCheckOff or Status then
							return PartA, Screen, Status
						end
					end
				end
				if PartB then
					local Screen, OnScreen = WorldToViewportPoint(PartB.Position)
					if OnScreen then
						local Status = CanSee(PartB)
						if IsWallCheckOff or Status then
							return PartB, Screen, Status
						end
					end
				end
			end
		end
		return nil, nil, false
	elseif AimbotPart == "Closest" then
		local BestPart, BestScreen, BestVisible, BestScore, Parts = nil, nil, false, math.huge, {Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg}
		for Index = 1, 6 do
			local Part = Parts[Index]
			if not Part then
				continue
			end

			local Screen, OnScreen = WorldToViewportPoint(Part.Position)
			if not OnScreen then
				continue
			end

			local DeltaX, DeltaY = Screen.X - ScreenCenterX, Screen.Y - ScreenCenterY
			local Distance = DeltaX * DeltaX + DeltaY * DeltaY
			if Distance < BestScore then
				local Status = CanSee(Part)
				if IsWallCheckOff or Status then
					BestScore = Distance
					BestPart = Part
					BestScreen = Screen
					BestVisible = Status
				end
			end
		end
		return BestPart, BestScreen, BestVisible
	end
	return nil, nil, false
end

local function ns__hookfunction(Table, Index, Replacement, Helper)
    local Original = Table[Index]
    Table[Index] = Helper and function(...)
		return Replacement(Helper, Original, ...)
	end or function(...)
		return Replacement(Original, ...)
	end
    return Original
end

local LocalHumanoid = nil
local IsSpawned = false
for _,Child in next, IgnoreFolder:GetChildren() do
	if Child:IsA("Model") and Child:FindFirstChildOfClass("Humanoid") then
		IsSpawned = true
		LocalHumanoid = Child:FindFirstChildOfClass("Humanoid")
	end
end

local function CorrectPositionHook(Original, NewPosition, ...)
	if LocalHumanoid and (
		Miscellaneous.Movement_Speed or Miscellaneous.Movement_Fly or Miscellaneous.Movement_BunnyHop
	) and LocalHumanoid.FloorMaterial == Enum.Material.Air then
		local Hit = workspace:Raycast(GetLocalPosition(), Vector3.new(0, -1000, 0), AimingRaycastParams)
		if Hit then
			return Original(Hit.Position + Vector3.new(0, 2, 0), ...)
		end
	end
	return Original(NewPosition, ...)
end

if typeof(debug.getupvalue) == "function" then
	local Success, NetworkEvents = pcall(debug.getupvalue, NetworkClient.fireReady, 5)
	if Success and NetworkEvents then
		ns__hookfunction(NetworkEvents, "correctposition", CorrectPositionHook)
	elseif typeof(debug.getupvalues) == "function" then
		local Success2, Upvalues = pcall(debug.getupvalues, NetworkClient.fireReady)
		if Success2 and Upvalues then
			for _,Upvalue in next, Upvalues do
				if type(Upvalue) == "table" and rawget(Upvalue, "correctposition") then
					return ns__hookfunction(Upvalue, "correctposition", CorrectPositionHook)
				end
			end
		end
	end
end

ns__hookfunction(FirearmObject, "computeWalkSway", function(Original, self, ...)
	return Miscellaneous.WeaponMods_NoWalkSway and Original(self, 0, 0) or Original(self, ...)
end)

ns__hookfunction(FirearmObject, "computeGunSway", function(Original, self, ...)
	return Miscellaneous.WeaponMods_NoWeaponSway and CFrame.identity or Original(self, ...)
end)

ns__hookfunction(FirearmObject, "getFiremode", function(Original, self, ...)
	return Miscellaneous.WeaponMods_AutomaticGun and true or Original(self, ...)
end)

ns__hookfunction(FirearmObject, "getWeaponStat", function(Original, self, Stat, ...)
	if (Stat == "equiptime" or Stat == "unequiptime") and Miscellaneous.WeaponMods_InstantEquip then
		return 0
	elseif (Stat == "unaimspeed" or Stat == "unmagnifyspeed") and Miscellaneous.WeaponMods_InstantAim then
		return 100
	elseif Stat == "variablechoke" or Stat == "spread" or Stat == "choke" or Stat == "aimchoke" or Stat == "hipchoke" then
		local Value = Miscellaneous.WeaponMods_SpreadAdjustment * 0.01
		if Value == 0 then
			return 0
		elseif Value < 1 then
			return (Original(self, Stat, ...) or 0) * Value
		end
	end
	return Original(self, Stat, ...)
end)

ns__hookfunction(FirearmObject, "getActiveAimStat", function(Original, self, Stat, ...)
	if (Stat == "aimspeed" or Stat == "unaimspeed" or Stat == "magnifyspeed") and Miscellaneous.WeaponMods_InstantAim then
		return 100
	elseif Stat == "swayamp" and Miscellaneous.WeaponMods_NoScopeSway then
		return 0
	end
	return Original(self, Stat, ...)
end)

ns__hookfunction(Module.__get("RecoilSprings"), "applyImpulse", function(Original, self, Offset, Scale, ...)
	if IsAimbotLocking and (Aiming.Aimbot_Type == "Camera" or Aiming.Aimbot_Type == "Mouse") then
		return
	end

	local Value = Miscellaneous.WeaponMods_RecoilAdjustment * 0.01
	if Value == 0 then
		return
	end

	if Value < 1 then
		return Original(self, Offset, (Scale or 1) * Value, ...)
	end

	return Original(self, Offset, Scale, ...)
end)

ns__hookfunction(CharacterObject, "preSimulationStep", function(Original, self, DeltaTime)
	Original(self, DeltaTime)

	if Miscellaneous.Movement_Speed then
		local Root = self._rootPart
		local Horizontal = Vector3.new(Root.Velocity.X, 0, Root.Velocity.Z)
		local Speed = Horizontal.Magnitude
		if Speed > 0.5 then
			Root.CFrame += Horizontal.Unit * (Miscellaneous.Movement_SpeedAmount - Speed) * DeltaTime
		end
	end

	if Miscellaneous.Movement_Fly then
		local CameraCFrame = Camera.CFrame
		local Direction = CameraCFrame.LookVector * ((UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (
			UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0
		)) + CameraCFrame.RightVector * ((UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (
			UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0
		))

		if Direction.Magnitude > 0 then
			Direction = Direction.Unit * Miscellaneous.Movement_FlySpeed
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			Direction += Vector3.new(0, Miscellaneous.Movement_FlySpeed, 0)
		end

		local Root = self._rootPart
		Root.Velocity = Direction
		Root.CFrame += Root.Velocity * DeltaTime
	end
end)

ns__hookfunction(FirearmObject, "reload", function(Original, self, ...)
	if self:isEquipping() or self:isUnequipping() or self:isChambering() then
		return
	end

	if Miscellaneous.WeaponMods_InstantReload then
		NetworkClientSend(NetworkClient, "reload")
		self:applyReloadCount(self:getWeaponStat("magsize"))
		return self:fireInput("reloadFinish", GetGameClockTime())
	end

	return Original(self)
end)

local TicketCache = {}
local TicketAddition = 0

local LastSilent = {Target = nil, Velocity = nil, Frame = 0, Player = nil, Time = 0, Entry = nil}

local SilentAimbotModule = {}

function SilentAimbotModule:GetClosest()
	local IsWallCheckOff = not Aiming.Aimbot_WallCheck
	local FOVRadius = Aiming.Aimbot_ShowFOV and Aiming.Aimbot_FOVRadius or math.huge
	local MaxScore, AimbotPart = math.huge, Aiming.Aimbot_Part
	local FOVOrigin = Aiming.Aimbot_ShowFOV and GetFOVOrigin() or ScreenCenter
	local CenterX, CenterY, LocalHeadPosition = FOVOrigin.X, FOVOrigin.Y, GetLocalPosition()
	local BestPosition, BestEntry, BestPart

	OperateOnAllEntries(function(_,Entry)
		if not Entry._alive or not Entry._isEnemy or not Entry._velspring.t then
			return
		end

		local Character = GetCharacter(Entry)
		if not Character then
			return
		end

		local Part, Screen = GetTargetPart(Character, AimbotPart, IsWallCheckOff)
		if not Part or not Screen then
			return
		end

		local DeltaX, DeltaY = Screen.X - CenterX, Screen.Y - CenterY
		local Distance = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY)
		if Distance > FOVRadius then
			return
		end

		local Position = Part.Position
		DeltaX, DeltaY = Position.X - LocalHeadPosition.X, Position.Y - LocalHeadPosition.Y
		local DeltaZ = Position.Z - LocalHeadPosition.Z
		local Score = Distance + math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ) * 0.15
		if Score < MaxScore then
			MaxScore = Score
			BestPosition = Position
			BestEntry = Entry
			BestPart = Part
		end
	end)

	return BestPosition, BestEntry, BestPart
end

function SilentAimbotModule:Solve(Origin, Acceleration, Speed)
	if RoundSystemClient.roundLock then
		return
	end
	if Aiming.Aimbot_SilentHitChance < math.random(1, 100) then
		return
	end

	local Now = os.clock()
	local Target, Entry = self:GetClosest()
	if not Target or not Entry then
		return
	end

	local Cache = MovementCache[Entry._player]
	if not Cache then
		return
	end

	local Velocity = nil
	local CacheSize = #Cache
	if CacheSize >= 2 then
		local TotalWeight, WeightedVelocity = 0, Vector3.zero
		for i = 1, math.min(CacheSize - 1, 5) do
			local Newer, Older = Cache[i], Cache[i + 1]
			if Newer and Older and (Newer.Time - Older.Time) > 0.001 then
				local Weight = 1 / i
				local SampleVelocity = (Newer.Position - Older.Position) / (Newer.Time - Older.Time)
				WeightedVelocity = WeightedVelocity + SampleVelocity * Weight
				TotalWeight = TotalWeight + Weight
			end
		end
		if TotalWeight > 0 then
			Velocity = WeightedVelocity / TotalWeight
		end
	end

	local Trajectory = GetTrajectory(Origin, Acceleration, Target, Speed, Velocity or Vector3.zero)
	if Trajectory then
		return Trajectory.Unit, Target, Entry, Now
	end
end

local AntiAimCycleFrames = 0
local function GetAntiAimAngles(Angles)
	local Pitch, Yaw, Roll = Angles.X, Angles.Y, Angles.Z
	local ClockTime = os.clock()
	AntiAimCycleFrames += 1

	if Miscellaneous.AntiAim_Pitch then
		local Mode = Miscellaneous.AntiAim_PitchMode
		if Mode == "Custom - Relative" then
			Pitch = math.clamp(Pitch + math.rad(Miscellaneous.AntiAim_PitchAmount), -Quarter, Quarter)
		elseif Mode == "Custom - Absolute" then
			Pitch = math.clamp(math.rad(Miscellaneous.AntiAim_PitchAmount), -2, 2)
		elseif Mode == "Rotate" then
			Pitch = math.sin(ClockTime * (Miscellaneous.AntiAim_PitchSpeed * 0.5)) * 2
		elseif Mode == "Random" then
			Pitch = math.random() * 4 - 2
		end
	end

	if Miscellaneous.AntiAim_Yaw then
		local Mode = Miscellaneous.AntiAim_YawMode
		if Mode == "Custom - Relative" then
			Yaw += math.rad(Miscellaneous.AntiAim_YawAmount)
		elseif Mode == "Custom - Absolute" then
			Yaw = math.rad(Miscellaneous.AntiAim_YawAmount)
		elseif Mode == "Backwards" then
			Yaw += math.pi
		elseif Mode == "Rotate" then
			Yaw = (ClockTime * (Miscellaneous.AntiAim_YawSpeed * 0.5)) % TwoPi
		elseif Mode == "Random" then
			Yaw = math.rad(math.random(-180, 180))
		elseif Mode == "Cycle" then
			local Speed = 76.5 - (Miscellaneous.AntiAim_YawSpeed * 1.5)
			Yaw = AntiAimCycleFrames % Speed >= (Speed * 0.5) and 2 or -2
		end
	end

	if Miscellaneous.AntiAim_Jitter then
		Yaw += (math.random() * 2 - 1) * math.rad(Miscellaneous.AntiAim_JitterAmount) * 0.25
	end

	if Miscellaneous.AntiAim_SpinBot then
		Yaw += ((ClockTime * math.rad(Miscellaneous.AntiAim_SpinSpeed)) % TwoPi) * (Miscellaneous.AntiAim_SpinDirection == "Left" and 1 or -1)
	end

	return Vector3.new(Pitch, Yaw, Roll) * 0.99
end

local GrenadeModule = {Segments = {}, Marker = Create("SphereHandleAdornment", CoreGui, {Radius = 0.25, ZIndex = 5, AlwaysOnTop = true, Adornee = Terrain})}

function GrenadeModule:GetVelocity(Target, Position)
	local Delta = Target - Position
	local Distance = Delta.Magnitude
	if Distance <= 1 then
		return
	end

	local FlightTime = Distance * 0.01
	local Solved = (Delta - Vector3.new(0, -40, 0) * FlightTime * FlightTime) / FlightTime
	if Solved.Magnitude > 150 then
		return
	end

	local Fuse
	if Aiming.Aimbot_FuseAssist and not Visuals.Combat_CustomGrenadeFuse then
		Fuse = math.min(FlightTime, GetActiveWeapon():getWeaponStat("fusetime")) or 5
	end
	return Solved, Fuse
end

function GrenadeModule:ImpactFuse(Position, Velocity)
	local Filter = {Map}
	OperateOnAllEntries(function(Player, Entry)
		if Player ~= LocalPlayer and Entry._alive and Entry._velspring.t then
			local Character = GetCharacter(Entry)
			if Character then
				table.insert(Filter, Character.Head.Parent)
			end
		end
	end)
	GrenadeImpactParams.FilterDescendantsInstances = Filter

	local Gravity = Vector3.new(0, -80, 0)
	local LastPosition, Traveled = Position, 0
	for Step = 1, 300 do
		local Elapsed = Step * RaycastStep
		local Next = Position + Velocity * Elapsed + 0.5 * Gravity * Elapsed * Elapsed
		local Hit = workspace:Raycast(LastPosition, Next - LastPosition, GrenadeImpactParams)
		Traveled += (Next - LastPosition).Magnitude
		if Hit and Hit.Instance.Name ~= "Window" and Hit.Instance.Name ~= "Col" and Traveled >= 3 then
			local SegmentLength = (Next - LastPosition).Magnitude
			return Elapsed - (SegmentLength > 0 and RaycastStep * (Next - Hit.Position).Magnitude / SegmentLength or 0)
		end
		LastPosition = Next
	end
end

ns__hookfunction(PlayerDataUtils, "getUnlocksData", function(Helper, Original, PlayerData)
	local Unlocks = Original(PlayerData)
	if Miscellaneous.ClientSessionUnlocks_AttachmentsUnlocked and PlayerData == Helper() then
		local OldUnlocks = Unlocks
		Unlocks = setmetatable({}, {
			__index = function(_,Index)
				local Unlock = OldUnlocks[Index] or {}
				Unlock.kills = 1000000000
				OldUnlocks[Index] = Unlock
				return Unlock
			end, __newindex = function(_,Index, Value)
				OldUnlocks[Index] = Value
				return
			end
		})
	end
	return Unlocks
end, PlayerDataClientInterface.getPlayerData)

ns__hookfunction(PlayerDataUtils, "ownsWeapon", function(Helper, Original, Player, WeaponName)
	if Miscellaneous.ClientSessionUnlocks_KnivesUnlocked then
		local Source = Helper(WeaponName)
		local Data = Source and Source.baseWeaponData
		if Data and Data.type == "KNIFE" then
			return true
		end
	end
	return Original(Player, WeaponName)
end, Module.__get("ContentInterface").getWeaponSource)

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	ViewportSize = Camera.ViewportSize
	ViewportSizeX = ViewportSize.X
	ViewportSizeY = ViewportSize.Y
	ScreenXCenter = ViewportSizeX * 0.5
	ScreenYCenter = ViewportSizeY * 0.5
	ScreenBottom = Vector2.new(ScreenXCenter, ViewportSizeY)
	ScreenTop = Vector2.new(ScreenXCenter, 0)
	ScreenCenter = Vector2.new(ScreenXCenter, ScreenYCenter)
	ScreenCenterX, ScreenCenterY = ScreenCenter.X, ScreenCenter.Y
end)

local BulletTracerModule = {Active = {}}
function BulletTracerModule:Update()
	local Now = os.clock()
	for Index = #BulletTracerModule.Active, 1, -1 do
		local Data = BulletTracerModule.Active[Index]
		local Elapsed, Duration = Now - Data.StartTime, Data.Duration
		if Elapsed >= Duration then
			Data.Beam:Destroy()
			Data.Attachment0:Destroy()
			Data.Attachment1:Destroy()
			table.remove(BulletTracerModule.Active, Index)
		else
			local Progress = Elapsed / Duration
			if Visuals.Combat_BulletTracerFadeMode == "Width" then
				local Beam, Thickness = Data.Beam, Data.Thickness * (1 - Progress)
				Beam.Width0 = Thickness
				Beam.Width1 = Thickness
			else
				local Alpha = Data.Alpha
				Data.Beam.Transparency = NumberSequence.new((1 - Alpha) + (Alpha * Progress))
			end
		end
	end
end

local SoundOptions = {
	"None", "Osu", "Pop", "MLG", "Ouch", "Fire", "Bonk", "Bell", "Rust", "Metal", "Skeet", "Quack", "Katana",
	"Neverlose", "Undertale", "Jet Set Radio", "TF2 Critical", "TF2 Frying Pan", "TF2 Alternative"
}

local CustomSounds = {
	["None"] = "", ["Osu"] = "rbxassetid://7172607676", ["Pop"] = "rbxassetid://9125402735", ["MLG"] = "rbxassetid://109817519733426", ["Ouch"] = "rbxassetid://136844926219636",
	["Fire"] = "rbxassetid://130412184952886", ["Bonk"] = "rbxassetid://5682262154", ["Bell"] = "rbxassetid://131573697", ["Rust"] = "rbxassetid://5043539486",
	["Metal"] = "rbxassetid://8917041751", ["Skeet"] = "rbxassetid://83717596220569", ["Quack"] = "rbxassetid://6435400690", ["Katana"] = "rbxassetid://7122613461",
	["Neverlose"] = "rbxassetid://18391691942", ["Undertale"] = "rbxassetid://1471213022", ["Jet Set Radio"] = "rbxassetid://97113622160405",
	["TF2 Critical"] = "rbxassetid://8255306220", ["TF2 Frying Pan"] = "rbxassetid://18922477538", ["TF2 Alternative"] = "rbxassetid://2868331684"
}

local PlaySoundId = AudioSystem.playSoundId
AudioSystem.playSoundId = function(AssetId, Priority, Volume, ...)
	local ShootSound = Miscellaneous.SoundOverride_ShootSound
	if ShootSound == "None" then
		return PlaySoundId(AssetId, Priority, Volume, ...)
	end

	local ActiveWeapon = GetActiveWeapon()
	if ActiveWeapon and AssetId == ActiveWeapon._weaponData.firesoundid then
		return PlaySoundId(CustomSounds[ShootSound], Priority, Volume)
	end
end

ns__hookfunction(AudioSystem, "playSound", function(Original, Name, ...)
	local Arguments = table.pack(...)
	if Miscellaneous.SoundOverride_HitSound ~= "None" and Name == "hitmarker" then
		return PlaySoundId(CustomSounds[Miscellaneous.SoundOverride_HitSound], 1, Arguments[3])
	elseif Miscellaneous.SoundOverride_KillSound ~= "None" and (Name == "killshot" or Name == "headshotkill") then
		return PlaySoundId(CustomSounds[Miscellaneous.SoundOverride_KillSound], 1, Arguments[3])
	elseif Miscellaneous.SoundOverride_GotHitSound ~= "None" and (Name == "crackSmall" or Name == "crackBig") then
		return PlaySoundId(CustomSounds[Miscellaneous.SoundOverride_GotHitSound], 1, Arguments[3])
	end
	return Original(Name, ...)
end)

local function CreateBulletTracer(StartPosition, Direction, TracerColor)
	local Attachment0 = ns__cloneref(Instance.new("Attachment"))
	Attachment0.Parent = Terrain
	Attachment0.Position = StartPosition
	local Attachment1 = ns__cloneref(Instance.new("Attachment"))
	Attachment1.Parent = Terrain
	local RaycastResult = workspace:Raycast(StartPosition, Direction, BulletRaycastParams)
	Attachment1.Position = RaycastResult and RaycastResult.Position or (StartPosition + Direction)

	local Beam = ns__cloneref(Instance.new("Beam"))
	Beam.FaceCamera = true
	Beam.TextureMode = Enum.TextureMode.Wrap
	Beam.TextureLength = 30
	Beam.LightEmission = 1
	Beam.Parent = Terrain

	local Thickness = Visuals.Combat_BulletTracerThickness
	if Visuals.Combat_BulletTracerWavy then
		Beam.Texture = "rbxassetid://446111271"
	else
		Thickness *= 0.05
		Beam.Texture = ""
	end

	Beam.Width0 = Thickness
	Beam.Width1 = Thickness
	Beam.Color = ColorSequence.new(TracerColor or Visuals.Combat_BulletTracerColor)
	Beam.Transparency = NumberSequence.new(1 - Visuals.Combat_BulletTracerAlpha)
	Beam.Attachment0 = Attachment0
	Beam.Attachment1 = Attachment1

	table.insert(BulletTracerModule.Active, {
		StartTime = os.clock(),
		Duration = Visuals.Combat_BulletTracerDuration,
		Beam = Beam,
		Attachment0 = Attachment0,
		Attachment1 = Attachment1,
		Thickness = Thickness,
		Alpha = Visuals.Combat_BulletTracerAlpha
	})
	return Beam
end

ns__hookfunction(Module.__get("BulletObject"), "new", function(Original, BulletData, ...)
	if not BulletData.onplayerhit then
		return Original(BulletData)
	end

	if Aiming.Aimbot_Enabled and Aiming.Aimbot_Type == "Silent" then
		local Speed = BulletData.velocity.Magnitude
		local Direction, Target, Entry, ShotTime = SilentAimbotModule:Solve(BulletData.position, BulletData.acceleration, Speed)
		if Direction and Target and Entry then
			BulletData.velocity = Direction * Speed
			LastSilent.Target = Target
			LastSilent.Velocity = Direction * Speed
			LastSilent.Frame = ShotTime
			LastSilent.Player = Entry._player
			LastSilent.Entry = Entry
			LastSilent.Time = ShotTime
		end
	end

	local Bullet = Original(BulletData)
	if Visuals.Combat_BulletTracers then
		CreateBulletTracer(BulletData.position, BulletData.velocity.Unit * 1500, Visuals.Combat_BulletTracerColor)
		for _,Object in next, Bullet._beamObject.beams do
			Object.Enabled = false
		end
	end
	return Bullet
end)

ns__hookfunction(GrenadeObject, "getWeaponStat", function(Original, self, Stat, ...)
	if (Stat == "equiptime" or Stat == "unequiptime") and Miscellaneous.WeaponMods_InstantEquip then
		return 0
	 elseif Stat == "uncookable" and Miscellaneous.WeaponMods_UncookableGrenade then
		return true
	end
	return Original(self, Stat, ...)
end)

ns__hookfunction(MeleeObject, "getWeaponStat", function(Original, self, Stat, ...)
	if (Stat == "equiptime" or Stat == "unequiptime") and Miscellaneous.WeaponMods_InstantEquip then
		return 0
	end
	return Original(self, Stat, ...)
end)

ns__hookfunction(Module.__get("MainCameraObject"), "step", function(Original, self, DeltaTime, ...)
	local LocalCharacter, Speed
	if Visuals.Camera_NoBob then
		LocalCharacter = GetLocalCharacter()
		if LocalCharacter then
			Speed = LocalCharacter._speed
			LocalCharacter._speed = 0
		end
	end

	Original(self, DeltaTime, ...)

	if LocalCharacter and Speed then
		LocalCharacter._speed = Speed
	end

	if Visuals.Camera_NoSuppression then
		self._suppressionSpring.p = Vector3.zero
	end
end)

ns__hookfunction(MeleeObject, "meleeSway", function(Original, self, ...)
	if Miscellaneous.WeaponMods_NoWeaponSway then
		return CFrame.identity
	end
	return Original(self, ...)
end)

ns__hookfunction(GrenadeObject, "modelSway", function(Original, self, ...)
	if Miscellaneous.WeaponMods_NoWeaponSway then
		return CFrame.identity
	end
	return Original(self, ...)
end)

local FlashlightPart = ns__cloneref(Instance.new("Part"))
FlashlightPart.Anchored = true
FlashlightPart.CanCollide = false
FlashlightPart.CanQuery = false
FlashlightPart.CanTouch = false
FlashlightPart.Transparency = 1
FlashlightPart.Size = Vector3.new(0.1, 0.1, 0.1)
FlashlightPart.Parent = workspace

local SpotLight = ns__cloneref(Instance.new("SpotLight"))
SpotLight.Brightness = 4
SpotLight.Range = 60
SpotLight.Angle = 70
SpotLight.Color = Color3.fromRGB(255, 255, 255)
SpotLight.Shadows = true
SpotLight.Parent = FlashlightPart

local ModelHighlights = setmetatable({}, {__mode = "k"})
local ViewmodelCache = setmetatable({}, {__mode = "k"})
local ModelBaseParts = setmetatable({}, {__mode = "k"})
local SleevesCache = setmetatable({}, {__mode = "k"})

local function OnCameraModelAdded(Model)
	ModelBaseParts[Model] = {}

	for _,Part in ipairs(Model:GetDescendants()) do
		if Part.Name == "Sleeves" and Part:IsA("MeshPart") then
			SleevesCache[Part] = Part.Parent
		end

		if Part:IsA("BasePart") then
			table.insert(ModelBaseParts[Model], Part)
		end
	end

	Model.DescendantAdded:Connect(function(Part)
		if Part.Name == "Sleeves" and Part:IsA("MeshPart") then
			SleevesCache[Part] = Part.Parent
		end

		if Part:IsA("BasePart") then
			table.insert(ModelBaseParts[Model], Part)
		end
	end)

	local Highlight = ns__cloneref(Instance.new("Highlight"))
	Highlight.Name = HttpService:GenerateGUID(false)
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Enabled = false
	Highlight.Adornee = Model
	Highlight.Parent = CoreGui
	ModelHighlights[Model] = Highlight

	Model.Destroying:Once(function()
		local HighlightObject = ModelHighlights[Model]
		if HighlightObject then
			HighlightObject:Destroy()
			ModelHighlights[Model] = nil
		end
		ModelBaseParts[Model] = nil
	end)
end

for _,Child in ipairs(Camera:GetChildren()) do
	if Child:IsA("Model") then
		OnCameraModelAdded(Child)
	end
end

Camera.ChildAdded:Connect(function(Child)
	if Child:IsA("Model") then
		OnCameraModelAdded(Child)
	end
end)

ns__hookfunction(Module.__get("ScreenCull"), "step", function(Original, ...)
	Original(...)

	if Visuals.Camera_ThirdPersonView then
		local CameraOffset = Vector3.new(Visuals.Camera_ThirdPersonOffsetX, Visuals.Camera_ThirdPersonOffsetY, Visuals.Camera_ThirdPersonOffsetZ)
		local DidCollide = false

		if Visuals.Camera_ThirdPersonCameraCollision and CameraOffset.Magnitude > 0 then
			local OriginalPosition = Camera.CFrame.Position
			local Raycast = workspace:Raycast(OriginalPosition, (Camera.CFrame * CFrame.new(CameraOffset)).Position - OriginalPosition, AimingRaycastParams)
			if Raycast then
				Camera.CFrame *= CFrame.new(CameraOffset * ((Raycast.Position - OriginalPosition).Magnitude / CameraOffset.Magnitude) * 0.99)
				DidCollide = true
			end
		end

		if not DidCollide then
			Camera.CFrame *= CFrame.new(CameraOffset)
		end
	end

	if Visuals.Camera_FOVModificationEnabled then
		local ApplyToAim = Visuals.Camera_ApplyToAim
		if not ApplyToAim then
			local ActiveWeapon = GetActiveWeapon()
			ApplyToAim = not (ActiveWeapon and ActiveWeapon._aiming)
		end

		if ApplyToAim then
			Camera.FieldOfView = Visuals.Camera_FOVValue
			Original(Camera.CFrame, Camera.ViewportSize, Visuals.Camera_FOVValue)
		end
	end
end)

IgnoreFolder.ChildAdded:Connect(function(Child)
	local Humanoid = Child:IsA("Model") and (Child:FindFirstChildOfClass("Humanoid") or Child:WaitForChild("Humanoid", 2))
	if Humanoid then
		LocalHumanoid = Humanoid
		Child.Destroying:Once(function()
			LocalHumanoid = nil
		end)
	end
end)

DeadBodyFolder.ChildAdded:Connect(function(Child)
	local RagdollMode = Miscellaneous.RagdollEffects_Mode
	if RagdollMode ~= "None" then
		local Torso = Child:FindFirstChild("Torso") or Child:FindFirstChildWhichIsA("BasePart")
		if not Torso then
			return
		end

		if RagdollMode == "Launch" then
			Torso.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), Miscellaneous.RagdollEffects_LaunchForce, math.random(-15, 15))
			return
		elseif RagdollMode == "Fling" then
			local Force = Miscellaneous.RagdollEffects_FlingForce
			Torso.AssemblyLinearVelocity = Vector3.new(math.random(-Force, Force), math.random(0, Force), math.random(-Force, Force))
			Torso.AssemblyAngularVelocity = Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
			return
		end

		Torso.AssemblyLinearVelocity = Vector3.new(0, Miscellaneous.RagdollEffects_FloatSpeed, 0)
		for _,Object in next, Child:GetChildren() do
			if Object:IsA("BasePart") then
				local BodyForce = ns__cloneref(Instance.new("BodyForce"))
				BodyForce.Name = HttpService:GenerateGUID(false)
				BodyForce.Force = Vector3.new(0, Object:GetMass() * workspace.Gravity, 0)
				BodyForce.Parent = Object
			end
		end
	end
end)

local function RotatePoint(Angle, Point, Center)
	local CosineAngle, SineAngle = math.cos(Angle), math.sin(Angle)
	local Offset = Point - Center
	local OffsetX, OffsetY = Offset.X, Offset.Y
	return Vector2.new(
		Center.X + (OffsetX * CosineAngle - OffsetY * SineAngle),
		Center.Y + (OffsetX * SineAngle + OffsetY * CosineAngle)
	)
end

local function HandleLine(Line, FromPoint, ToPoint, Center, Angle, Color, Spin)
	if Spin then
		FromPoint = RotatePoint(Angle, FromPoint, Center)
		ToPoint = RotatePoint(Angle, ToPoint, Center)
	end
	SetProperty(Line, "From", FromPoint)
	SetProperty(Line, "To", ToPoint)
	SetProperty(Line, "Color", Color)
	SetProperty(Line, "Visible", true)
end

local FOVCircle = CreateDrawing("Circle", {Visible = false, Filled = false, Color = Aiming.Aimbot_FOVColor, Position = ScreenCenter, Thickness = 1})
local TargetTracer = CreateDrawing("Line", {Visible = false, Color = Aiming.Aimbot_TargetTracerColor, Thickness = 1.5})
local ESPModule = {
	Objects = {},
	Highlights = {},
	Grenades = {}
}

function ESPModule:UpdateProperty(Table, Property, Value)
	for _,Group in next, self.Objects do
		for _,Name in next, Table do
			Group[Name][Property] = Value
		end
	end
end

function ESPModule:Clear(Player)
	local DrawingGroup = self.Objects[Player]
	if DrawingGroup then
		for _,DrawingObject in next, DrawingGroup do
			DrawingObject:Remove()
		end
		self.Objects[Player] = nil
	end

	local HighlightGroup = self.Highlights[Player]
	if HighlightGroup then
		local Full = HighlightGroup.Full
		if Full then
			Full:Destroy()
		end
		self.Highlights[Player] = nil
	end
end

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/430L/PhantomPlus/refs/heads/main/core/Library.luau"))()
local Window = Library:CreateWindow({Title = "PhantomWare | discord.gg/DwRT2nH93D" .. (Module.ExecutorName and (" | " .. Module.ExecutorName) or ""), TabPadding = 8, MenuFadeTime = 0.2}, 1)
local Toggles = Library.Toggles
local Options = Library.Options

local Tabs = {
	Aiming = Window:AddTab("Aiming"),
	Visuals = Window:AddTab("Visuals"),
	Miscellaneous = Window:AddTab("Miscellaneous"),
	Settings = Window:AddTab("Settings")
}

local function UpdateTable(Table, Setting, Value, Callback)
	Table[Setting] = Value
	if Callback then
		Callback(Value)
	end
end

local function BuildAimingTab()
	local Aiming_RageBot = Tabs.Aiming:AddRightGroupbox("RageBot")
	local Aiming_Aimbot = Tabs.Aiming:AddLeftGroupbox("Aimbot")

	Aiming_Aimbot:AddToggle("Aimbot_Enabled", {Text = "Aimbot", Default = Aiming.Aimbot_Enabled, Callback = function(Value)
		Aiming.Aimbot_Enabled = Value
	end}):AddKeyPicker("Aimbot_Keybind", {Default = Aiming.Aimbot_Keybind, Mode = "Hold", Modes = {"Hold"}, Text = "Aiming Keybind",
		Callback = function(State)
			if type(State) == "boolean" then
				IsAimkeyDown = State
			elseif type(State) == "string" then
				UpdateAimkeyBinding(State)
			end
		end,
		ChangedCallback = function(Keybind)
			Aiming.Aimbot_Keybind = Keybind
			UpdateAimkeyBinding(Keybind)
		end
	})

	local AimbotDependencyBox = Aiming_Aimbot:AddDependencyBox():SetupDependencies({{Toggles.Aimbot_Enabled, true}})

	AimbotDependencyBox:AddDropdown("Aimbot_Type", {Text = "Type", Default = Aiming.Aimbot_Type, Values = {"None", "Camera", "Mouse", "Silent"}, Callback = function(Value)
		Aiming.Aimbot_Type = Value
	end})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, {"Camera", "Mouse"}}}):AddDropdown("Aimbot_Part", {Text = "Part", Default = Aiming.Aimbot_Part, Values = {"Head", "Torso", "Closest", "Best"}, Callback = function(Value)
		Aiming.Aimbot_Part = Value
	end})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, {"Camera", "Mouse"}}}):AddDropdown("Aimbot_SmoothingMode", {
		Text = "Smoothing Mode", Default = Aiming.Aimbot_SmoothingMode, Values = {"Linear", "Ease-Out"}, Callback = function(Value)
			Aiming.Aimbot_SmoothingMode = Value
		end
	})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, {"Camera", "Mouse"}}}):AddSlider("Aimbot_Smoothness", {
		Text = "Smoothness", Default = Aiming.Aimbot_Smoothness, Min = 1, Max = 20, Rounding = 1, Callback = function(Value)
			Aiming.Aimbot_Smoothness = Value
		end
	})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, {"Camera", "Mouse"}}}):AddSlider("Aimbot_TargetStickiness", {
		Text = "Target Stickiness", Default = Aiming.Aimbot_TargetStickiness, Min = 0, Max = 100, Rounding = 0, Callback = function(Value)
			Aiming.Aimbot_TargetStickiness = Value
		end
	})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, {"Camera", "Mouse"}}}):AddToggle("Aimbot_Prediction", {
		Text = "Movement Prediction", Default = Aiming.Aimbot_Prediction, Callback = function(Value)
			Aiming.Aimbot_Prediction = Value
		end
	})

	local AutoFireDependencyBox = AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, "Silent"}})
	AutoFireDependencyBox:AddToggle("Aimbot_AutoFire", {
		Text = "Auto Fire", Default = Aiming.Aimbot_AutoFire, Callback = function(Value)
			Aiming.Aimbot_AutoFire = Value
		end
	})
	AutoFireDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Aimbot_AutoFire, true}}):AddToggle("Aimbot_AutoWall", {
		Text = "Auto Wall", Default = Aiming.Aimbot_AutoWall, Callback = function(Value)
			Aiming.Aimbot_AutoWall = Value
		end
	})
	AutoFireDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Aimbot_AutoFire, true}}):AddSlider("Aimbot_AutoDelay", {
		Text = "Delay (ms)", Default = Aiming.Aimbot_AutoDelay, Min = 0, Max = 500, Rounding = 0, Callback = function(Value)
			Aiming.Aimbot_AutoDelay = Value
		end
	})

	local SilentAimbotDependencyBox = AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Options.Aimbot_Type, "Silent"}})

	SilentAimbotDependencyBox:AddDropdown("Aimbot_Part", {Text = "Part", Default = Aiming.Aimbot_Part, Values = {"Head", "Torso", "Closest", "Best"}, Callback = function(Value)
		Aiming.Aimbot_Part = Value
	end})

	SilentAimbotDependencyBox:AddSlider("Aimbot_SilentHitChance", {
		Text = "Hit Chance", Default = Aiming.Aimbot_SilentHitChance, Min = 0, Max = 100, Rounding = 0, Callback = function(Value)
			Aiming.Aimbot_SilentHitChance = Value
		end
	})

	AimbotDependencyBox:AddToggle("Aimbot_WallCheck", {Text = "Wall Check", Default = Aiming.Aimbot_WallCheck, Callback = function(Value)
		Aiming.Aimbot_WallCheck = Value
	end})

	AimbotDependencyBox:AddToggle("Aimbot_DeathNotification", {Text = "Death Notification", Default = Aiming.Aimbot_DeathNotification, Callback = function(Value)
		Aiming.Aimbot_DeathNotification = Value
	end})

	AimbotDependencyBox:AddToggle("Aimbot_ShowFOV", {Text = "FOV Circle", Default = Aiming.Aimbot_ShowFOV, Callback = function(Value)
		Aiming.Aimbot_ShowFOV = Value
	end}):AddColorPicker("Aimbot_FOVColor", {Default = Aiming.Aimbot_FOVColor, Title = "FOV Color", Transparency = Aiming.Aimbot_FOVOpacity}).Callback = function(Value)
		Aiming.Aimbot_FOVColor = Value
		Aiming.Aimbot_FOVOpacity = 1 - Options.Aimbot_FOVColor.Transparency
		FOVCircle.Color = Value
		FOVCircle.Transparency = Aiming.Aimbot_FOVOpacity
	end

	AimbotDependencyBox:AddToggle("Aimbot_FOVFollowRecoil", {Text = "Follow Recoil", Default = Aiming.Aimbot_FOVFollowRecoil, Callback = function(Value)
		Aiming.Aimbot_FOVFollowRecoil = Value
	end})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Aimbot_ShowFOV, true}}):AddSlider("Aimbot_FOVRadius", {
		Text = "FOV Radius", Default = Aiming.Aimbot_FOVRadius, Min = 10, Max = 800, Rounding = 0, Callback = function(Value)
			Aiming.Aimbot_FOVRadius = Value
		end
	})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Aimbot_ShowFOV, true}}):AddToggle("Aimbot_DynamicFOV", {
		Text = "Dynamic FOV Circle", Default = Aiming.Aimbot_DynamicFOV, Callback = function(Value)
			Aiming.Aimbot_DynamicFOV = Value
		end
	})

	AimbotDependencyBox:AddToggle("Aimbot_TargetTracer", {Text = "Target Tracer", Default = Aiming.Aimbot_TargetTracer, Callback = function(Value)
		Aiming.Aimbot_TargetTracer = Value
	end}):AddColorPicker("Aimbot_TargetTracerColor", {Default = Aiming.Aimbot_TargetTracerColor, Title = "Tracer Color", Transparency = Aiming.Aimbot_TargetTracerOpacity, Callback = function(Value)
		Aiming.Aimbot_TargetTracerColor = Value
		Aiming.Aimbot_TargetTracerOpacity = 1 - Options.Aimbot_TargetTracerColor.Transparency
		TargetTracer.Color = Value
		TargetTracer.Transparency = Aiming.Aimbot_TargetTracerOpacity
	end})

	AimbotDependencyBox:AddToggle("Aimbot_GrenadeRedirect", {Text = "Grenade Redirect", Default = Aiming.Aimbot_GrenadeRedirect, Callback = function(Value)
		Aiming.Aimbot_GrenadeRedirect = Value
	end})

	AimbotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Aimbot_GrenadeRedirect, true}}):AddToggle("Aimbot_FuseAssist", {Text = "Fuse Assist", Default = Aiming.Aimbot_FuseAssist, Callback = function(Value)
		Aiming.Aimbot_FuseAssist = Value
	end})

	Aiming_RageBot:AddToggle("RageBot_Enabled", {Text = "RageBot", Default = Aiming.RageBot_Enabled, Callback = function(Value)
		Aiming.RageBot_Enabled = Value
	end}):AddKeyPicker("RageBot_Keybind", {Default = Aiming.RageBot_Keybind, Mode = "Toggle", Text = "RageBot Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Aiming.RageBot_Keybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.RageBot_Enabled:SetValue(Value)
		end
	end})

	local RageBotDependencyBox = Aiming_RageBot:AddDependencyBox():SetupDependencies({{Toggles.RageBot_Enabled, true}})
	RageBotDependencyBox:AddDropdown("RageBot_Part", {Text = "Part", Default = Aiming.RageBot_Part, Values = {"Head", "Torso", "Best"}, Callback = function(Value)
		Aiming.RageBot_Part = Value
	end})

	RageBotDependencyBox:AddToggle("RageBot_WallPenetrationDetection", {Text = "Wall Penetration Detection", Default = Aiming.RageBot_WallPenetrationDetection, Callback = function(Value)
		Aiming.RageBot_WallPenetrationDetection = Value
	end})

	RageBotDependencyBox:AddToggle("RageBot_MultiTarget", {Text = "Multi Target", Default = Aiming.RageBot_MultiTarget, Callback = function(Value)
		Aiming.RageBot_MultiTarget = Value
	end})

	RageBotDependencyBox:AddToggle("RageBot_Prediction", {Text = "Movement Prediction", Default = Aiming.RageBot_Prediction, Callback = function(Value)
		Aiming.RageBot_Prediction = Value
	end})

	RageBotDependencyBox:AddToggle("RageBot_HitScanning", {Text = "Hit Scanning", Default = Aiming.RageBot_HitScanning, Callback = function(Value)
		Aiming.RageBot_HitScanning = Value
	end})

	RageBotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.RageBot_HitScanning, true}}):AddDropdown("RageBot_HitScanningMode", {Text = "Hit Scan Mode", Default = Aiming.RageBot_HitScanningMode, Values = {"Cardinal", "Sphere", "Corners"}, Callback = function(Value)
		Aiming.RageBot_HitScanningMode = Value
	end})

	RageBotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.RageBot_HitScanning, true}, {Options.RageBot_HitScanningMode, {"Cardinal", "Sphere", "Corners"}}}):AddSlider("RageBot_HitScanningRadius", {
		Text = "Hit Scan Radius", Default = Aiming.RageBot_HitScanningRadius, Min = 0.5, Max = 3, Rounding = 1, Callback = function(Value)
			Aiming.RageBot_HitScanningRadius = Value
		end
	})

	RageBotDependencyBox:AddToggle("RageBot_FireScanning", {Text = "Fire Scanning", Default = Aiming.RageBot_FireScanning, Callback = function(Value)
		Aiming.RageBot_FireScanning = Value
	end})

	RageBotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.RageBot_FireScanning, true}}):AddDropdown("RageBot_FireScanningMode", {Text = "Fire Scan Mode", Default = Aiming.RageBot_FireScanningMode, Values = {"Cardinal", "Sphere", "Corners"}, Callback = function(Value)
		Aiming.RageBot_FireScanningMode = Value
	end})

	RageBotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.RageBot_FireScanning, true}}):AddSlider("RageBot_FireScanningRadius", {
		Text = "Fire Scan Radius", Default = Aiming.RageBot_FireScanningRadius, Min = 0, Max = 12, Rounding = 1, Callback = function(Value)
			Aiming.RageBot_FireScanningRadius = Value
		end
	})

	RageBotDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.RageBot_FireScanning, true}, {Options.RageBot_FireScanningMode, "Sphere"}}):AddSlider("RageBot_FireScanningCount", {
		Text = "Fire Scan Count", Default = Aiming.RageBot_FireScanningCount, Min = 1, Max = 16, Rounding = 0, Callback = function(Value)
			Aiming.RageBot_FireScanningCount = Value
		end
	})
end

local function BreakAllWindows()
	local CameraPosition = Camera.CFrame.Position
	for _,Descendant in next, workspace:QueryDescendants("BasePart#Window") do
		if Descendant.Position ~= CameraPosition then
			Effects.breakwindow(Descendant, Descendant.Position, (Descendant.Position - CameraPosition).Unit)
		end
	end
end

local function BuildVisualsTab()
	local Visuals_ESPVisualsGroupbox = Tabs.Visuals:AddLeftGroupbox("ESP Visuals")
	local Visuals_CombatGroupbox = Tabs.Visuals:AddRightGroupbox("Combat")

	local World_Tabbox = Tabs.Visuals:AddRightTabbox("World")
	local World_Camera = World_Tabbox:AddTab("Camera")
	local World_Lighting = World_Tabbox:AddTab("Lighting")
	local World_ViewModel = World_Tabbox:AddTab("ViewModel")

	Visuals_CombatGroupbox:AddToggle("Combat_BulletTracers", {Text = "Bullet Tracers", Default = Visuals.Combat_BulletTracers, Callback = function(Value)
		Visuals.Combat_BulletTracers = Value
	end}):AddColorPicker("Combat_BulletTracerColor", {Default = Visuals.Combat_BulletTracerColor, Title = "Tracer Color", Callback = function(Value)
		Visuals.Combat_BulletTracerColor = Value
	end})

	local BulletTracersDependencyBox = Visuals_CombatGroupbox:AddDependencyBox():SetupDependencies({{Toggles.Combat_BulletTracers, true}})
	BulletTracersDependencyBox:AddToggle("Combat_BulletTracerWavy", {Text = "Wavy Tracer", Default = Visuals.Combat_BulletTracerWavy, Callback = function(Value)
		Visuals.Combat_BulletTracerWavy = Value
	end})
	BulletTracersDependencyBox:AddDropdown("Combat_BulletTracerFadeMode", {Text = "Fade Mode", Default = Visuals.Combat_BulletTracerFadeMode, Values = {"Width", "Transparency"}, Callback = function(Value)
		Visuals.Combat_BulletTracerFadeMode = Value
	end})
	BulletTracersDependencyBox:AddSlider("Combat_BulletTracerThickness", {Text = "Thickness", Default = Visuals.Combat_BulletTracerThickness, Min = 1, Max = 5, Rounding = 1, Callback = function(Value)
		Visuals.Combat_BulletTracerThickness = Value
	end})
	BulletTracersDependencyBox:AddSlider("Combat_BulletTracerDuration", {Text = "Duration", Default = Visuals.Combat_BulletTracerDuration, Min = 0.1, Max = 10, Rounding = 1, Callback = function(Value)
		Visuals.Combat_BulletTracerDuration = Value
	end})

	Visuals_CombatGroupbox:AddToggle("Combat_HitMarkerEnabled", {Text = "Hit Markers", Default = Visuals.Combat_HitMarkerEnabled, Callback = function(Value)
		Visuals.Combat_HitMarkerEnabled = Value
	end}):AddColorPicker("Combat_HitMarkerColor", {Default = Visuals.Combat_HitMarkerColor, Title = "Hit Markers Color", Callback = function(Value)
		Visuals.Combat_HitMarkerColor = Value
	end})

	local HitMarkerDependencyBox = Visuals_CombatGroupbox:AddDependencyBox():SetupDependencies({{Toggles.Combat_HitMarkerEnabled, true}})

	HitMarkerDependencyBox:AddDropdown("Combat_HitMarkerStyle", {Text = "Marker Style", Default = Visuals.Combat_HitMarkerStyle, Values = {"X", "Plus"}, Callback = function(Value)
		Visuals.Combat_HitMarkerStyle = Value
	end})

	HitMarkerDependencyBox:AddSlider("Combat_HitMarkerSize", {Text = "Marker Size", Default = Visuals.Combat_HitMarkerSize, Min = 4, Max = 30, Rounding = 0, Callback = function(Value)
		Visuals.Combat_HitMarkerSize = Value
	end})

	HitMarkerDependencyBox:AddSlider("Combat_HitMarkerGap", {Text = "Marker Gap", Default = Visuals.Combat_HitMarkerGap, Min = 0, Max = 15, Rounding = 0, Callback = function(Value)
		Visuals.Combat_HitMarkerGap = Value
	end})

	HitMarkerDependencyBox:AddSlider("Combat_HitMarkerDuration", {Text = "Marker Duration", Default = Visuals.Combat_HitMarkerDuration, Min = 0.1, Max = 5, Rounding = 1, Callback = function(Value)
		Visuals.Combat_HitMarkerDuration = Value
	end})

	HitMarkerDependencyBox:AddToggle("Combat_HitMarkerSpin", {Text = "Spinning Marker", Default = Visuals.Combat_HitMarkerSpin, Callback = function(Value)
		Visuals.Combat_HitMarkerSpin = Value
	end})

	HitMarkerDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Combat_HitMarkerSpin, true}}):AddSlider("Combat_HitMarkerSpinSpeed", {
		Text = "Spin Speed", Default = Visuals.Combat_HitMarkerSpinSpeed, Min = 1, Max = 10, Rounding = 0, Callback = function(Value)
			Visuals.Combat_HitMarkerSpinSpeed = Value
		end
	})

	Visuals_CombatGroupbox:AddToggle("Combat_GrenadeTrajectory", {Text = "Grenade Trajectory", Default = Visuals.Combat_GrenadeTrajectory, Callback = function(Value)
		Visuals.Combat_GrenadeTrajectory = Value
	end}):AddColorPicker("Combat_GrenadeTrajectoryColor", {Default = Visuals.Combat_GrenadeTrajectoryColor, Title = "Trajectory Color", Callback = function(Value)
		Visuals.Combat_GrenadeTrajectoryColor = Value
	end})

	local GrenadeTrajectory_DepedencyBox = Visuals_CombatGroupbox:AddDependencyBox():SetupDependencies({{Toggles.Combat_GrenadeTrajectory, true}})

	GrenadeTrajectory_DepedencyBox:AddToggle("Combat_GrenadeTrajectoryCustomImpact", {Text = "Custom Impact Color", Default = Visuals.Combat_GrenadeTrajectoryCustomImpact, Callback = function(Value)
		Visuals.Combat_GrenadeTrajectoryCustomImpact = Value
	end}):AddColorPicker("Combat_GrenadeTrajectoryImpactColor", {Default = Visuals.Combat_GrenadeTrajectoryImpactColor, Title = "Impact Color", Callback = function(Value)
		Visuals.Combat_GrenadeTrajectoryImpactColor = Value
	end})

	GrenadeTrajectory_DepedencyBox:AddSlider("Combat_GrenadeTrajectoryBounces", {Text = "Bounces", Default = Visuals.Combat_GrenadeTrajectoryBounces, Min = 0, Max = 3, Rounding = 0, Callback = function(Value)
		Visuals.Combat_GrenadeTrajectoryBounces = Value
	end})

	GrenadeTrajectory_DepedencyBox:AddSlider("Combat_GrenadeTrajectoryThickness", {Text = "Thickness", Default = Visuals.Combat_GrenadeTrajectoryThickness, Min = 1, Max = 6, Rounding = 1, Callback = function(Value)
		Visuals.Combat_GrenadeTrajectoryThickness = Value
	end})

	Visuals_CombatGroupbox:AddToggle("Combat_RadarHack", {Text = "Radar Hack", Default = Visuals.Combat_RadarHack, Callback = function(Value)
		Visuals.Combat_RadarHack = Value
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_MasterEnabled", {Text = "Master Switch", Default = Visuals.ESPVisuals_MasterEnabled, Callback = function(Value)
		Visuals.ESPVisuals_MasterEnabled = Value
	end}):AddKeyPicker("ESPVisuals_Keybind", {Default = Visuals.ESPVisuals_Keybind, Mode = "Toggle", Text = "ESP Master Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Visuals.ESPVisuals_Keybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.ESPVisuals_MasterEnabled:SetValue(Value)
		end
	end})

	Visuals_ESPVisualsGroupbox:AddSlider("ESPVisuals_MasterOpacity", {Text = "Master Opacity", Default = Visuals.ESPVisuals_MasterOpacity, Min = 0, Max = 100, Rounding = 0, Callback = function(Value)
		Visuals.ESPVisuals_MasterOpacity = Value
		for _,Group in next, ESPModule.Objects do
			for Index in next, {"Box", "Tag", "Dot", "Tracer", "Healthbar", "SkeletonHead", "SkeletonSpine", "SkeletonLeftShoulder", "SkeletonRightShoulder", "SkeletonLeftArm", "SkeletonRightArm", "SkeletonLeftHip", "SkeletonRightHip", "SkeletonLeftLeg", "SkeletonRightLeg"} do
				local DrawingObject = Group[Index]
				if DrawingObject then
					DrawingObject.Transparency = Value * 0.01
				end
			end
		end
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_Chams", {Text = "Highlight Chams", Default = Visuals.ESPVisuals_Chams, Callback = function(Value)
		Visuals.ESPVisuals_Chams = Value
	end}):AddColorPicker("ESPVisuals_ChamsColor", {Default = Visuals.ESPVisuals_ChamsColor, Title = "Chams Color", Callback = function(Value)
		Visuals.ESPVisuals_ChamsColor = Value
	end})

	local ChamsDependencyBox = Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_Chams, true}})

	ChamsDependencyBox:AddDropdown("ESPVisuals_ChamsRendering", {Text = "Rendering", Default = Visuals.ESPVisuals_ChamsRendering, Values = {"Fill", "Outline"}, Multi = true, Callback = function(Value)
		Visuals.ESPVisuals_ChamsRendering = Value
	end})

	ChamsDependencyBox:AddDropdown("ESPVisuals_ChamsStyle", {Text = "Style", Default = Visuals.ESPVisuals_ChamsStyle, Values = {"Solid", "Visible"}, Callback = function(Value)
		Visuals.ESPVisuals_ChamsStyle = Value
	end})

	ChamsDependencyBox:AddDependencyBox():SetupDependencies({{Options.ESPVisuals_ChamsStyle, "Visible"}}):AddLabel("Visible Color"):AddColorPicker("ESPVisuals_ChamsVisibleColor", {
		Default = Visuals.ESPVisuals_ChamsVisibleColor, Title = "Visible Color", Callback = function(Value)
			Visuals.ESPVisuals_ChamsVisibleColor = Value
		end
	})

	ChamsDependencyBox:AddToggle("ESPVisuals_ChamsOccluded", {Text = "Occluded", Default = Visuals.ESPVisuals_ChamsOccluded, Callback = function(Value)
		Visuals.ESPVisuals_ChamsOccluded = Value
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_Dots", {Text = "Head Dots", Default = Visuals.ESPVisuals_Dots, Callback = function(Value)
		Visuals.ESPVisuals_Dots = Value
	end}):AddColorPicker("ESPVisuals_DotColor", {Default = Visuals.ESPVisuals_DotColor, Title = "Dot Color", Callback = function(Value)
		Visuals.ESPVisuals_DotColor = Value
		ESPModule:UpdateProperty({"Dot"}, "Color", Value)
	end})

	Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_Dots, true}}):AddSlider("ESPVisuals_DotSize", {
		Text = "Size", Default = Visuals.ESPVisuals_DotSize, Min = 1, Max = 10, Rounding = 0, Callback = function(Value)
			Visuals.ESPVisuals_DotSize = Value
			ESPModule:UpdateProperty({"Dot"}, "Radius", Value)
		end
	})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_Skeletons", {Text = "Skeletons", Default = Visuals.ESPVisuals_Skeletons, Callback = function(Value)
		Visuals.ESPVisuals_Skeletons = Value
	end}):AddColorPicker("ESPVisuals_SkeletonsColor", {Default = Visuals.ESPVisuals_SkeletonsColor, Title = "Skeleton Color", Callback = function(Value)
		Visuals.ESPVisuals_SkeletonsColor = Value
		ESPModule:UpdateProperty({"SkeletonHead", "SkeletonSpine", "SkeletonLeftShoulder", "SkeletonRightShoulder", "SkeletonLeftArm", "SkeletonRightArm", "SkeletonLeftHip", "SkeletonRightHip", "SkeletonLeftLeg", "SkeletonRightLeg"}, "Color", Value)
	end})

	Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_Skeletons, true}}):AddSlider("ESPVisuals_SkeletonsThickness", {
		Text = "Thickness", Default = Visuals.ESPVisuals_SkeletonsThickness, Min = 1, Max = 5, Rounding = 1, Callback = function(Value)
			Visuals.ESPVisuals_SkeletonsThickness = Value
			ESPModule:UpdateProperty({"SkeletonHead", "SkeletonSpine", "SkeletonLeftShoulder", "SkeletonRightShoulder", "SkeletonLeftArm", "SkeletonRightArm", "SkeletonLeftHip", "SkeletonRightHip", "SkeletonLeftLeg", "SkeletonRightLeg"}, "Thickness", Value)
		end
	})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_HeadTags", {Text = "Head Tags", Default = Visuals.ESPVisuals_HeadTags, Callback = function(Value)
		Visuals.ESPVisuals_HeadTags = Value
	end}):AddColorPicker("ESPVisuals_TagColor", {Default = Visuals.ESPVisuals_TagColor, Title = "Tag Color", Callback = function(Value)
		Visuals.ESPVisuals_TagColor = Value
		ESPModule:UpdateProperty({"Tag"}, "Color", Value)
	end})

	local HeadTags_Depedencybox = Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_HeadTags, true}})

	HeadTags_Depedencybox:AddDropdown("ESPVisuals_HeadTagElements", {Text = "Elements", Default = Visuals.ESPVisuals_HeadTagElements, Values = {"Name", "Health", "Distance", "Visibility"}, Multi = true, Callback = function(Value)
		Visuals.ESPVisuals_HeadTagElements = Value
	end})

	HeadTags_Depedencybox:AddSlider("ESPVisuals_TagSize", {Text = "Size", Default = Visuals.ESPVisuals_TagSize, Min = 8, Max = 32, Rounding = 0, Callback = function(Value)
		Visuals.ESPVisuals_TagSize = Value
		ESPModule:UpdateProperty({"Tag"}, "Size", Value)
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_Boxes", {Text = "Boxes", Default = Visuals.ESPVisuals_Boxes, Callback = function(Value)
		Visuals.ESPVisuals_Boxes = Value
	end}):AddColorPicker("ESPVisuals_BoxColor", {Default = Visuals.ESPVisuals_BoxColor, Title = "Box Color", Callback = function(Value)
		Visuals.ESPVisuals_BoxColor = Value
		ESPModule:UpdateProperty({"Box"}, "Color", Value)
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_Healthbars", {Text = "Healthbars", Default = Visuals.ESPVisuals_Healthbars, Callback = function(Value)
		Visuals.ESPVisuals_Healthbars = Value
	end}):AddColorPicker("ESPVisuals_HealthbarColor", {Default = Visuals.ESPVisuals_HealthbarColor, Title = "Healthbar Color", Callback = function(Value)
		Visuals.ESPVisuals_HealthbarColor = Value
		ESPModule:UpdateProperty({"Healthbar"}, "Color", Value)
	end})

	Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_Healthbars, true}}):AddSlider("ESPVisuals_HealthbarWidth", {
		Text = "Width", Default = Visuals.ESPVisuals_HealthbarWidth, Min = 1, Max = 12, Rounding = 0, Callback = function(Value)
			Visuals.ESPVisuals_HealthbarWidth = Value
		end
	})

	Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_Boxes, true}}):AddSlider("ESPVisuals_BoxThickness", {
		Text = "Thickness", Default = Visuals.ESPVisuals_BoxThickness, Min = 1, Max = 5, Rounding = 1, Callback = function(Value)
			Visuals.ESPVisuals_BoxThickness = Value
			ESPModule:UpdateProperty({"Box"}, "Thickness", Value)
		end
	})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_Tracers", {Text = "Tracers", Default = Visuals.ESPVisuals_Tracers, Callback = function(Value)
		Visuals.ESPVisuals_Tracers = Value
	end}):AddColorPicker("ESPVisuals_TracerColor", {Default = Visuals.ESPVisuals_TracerColor, Title = "Tracer Color", Callback = function(Value)
		Visuals.ESPVisuals_TracerColor = Value
		ESPModule:UpdateProperty({"Tracer"}, "Color", Value)
	end})

	local TracersDependencyBox = Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_Tracers, true}})

	TracersDependencyBox:AddDropdown("ESPVisuals_TracerTarget", {Text = "Target", Default = Visuals.ESPVisuals_TracerTarget, Values = {"Head", "Torso"}, Callback = function(Value)
		Visuals.ESPVisuals_TracerTarget = Value
	end})

	TracersDependencyBox:AddDropdown("ESPVisuals_TracerOrigin", {Text = "Origin", Default = Visuals.ESPVisuals_TracerOrigin, Values = {"Bottom", "Center", "Top"}, Callback = function(Value)
		Visuals.ESPVisuals_TracerOrigin = Value
	end})

	TracersDependencyBox:AddSlider("ESPVisuals_TracerThickness", {Text = "Thickness", Default = Visuals.ESPVisuals_TracerThickness, Min = 1, Max = 5, Rounding = 1, Callback = function(Value)
		Visuals.ESPVisuals_TracerThickness = Value
		ESPModule:UpdateProperty({"Tracer"}, "Thickness", Value)
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_OffscreenArrows", {Text = "Offscreen Arrows", Default = Visuals.ESPVisuals_OffscreenArrows, Callback = function(Value)
		Visuals.ESPVisuals_OffscreenArrows = Value
	end}):AddColorPicker("ESPVisuals_OffscreenArrowColor", {Default = Visuals.ESPVisuals_OffscreenArrowColor, Title = "Arrow Color", Callback = function(Value)
		Visuals.ESPVisuals_OffscreenArrowColor = Value
		ESPModule:UpdateProperty({"Arrow"}, "Color", Value)
	end})

	local OffscreenArrowsDependencyBox = Visuals_ESPVisualsGroupbox:AddDependencyBox():SetupDependencies({{Toggles.ESPVisuals_OffscreenArrows, true}})

	OffscreenArrowsDependencyBox:AddSlider("ESPVisuals_OffscreenArrowSize", {Text = "Arrow Size", Default = Visuals.ESPVisuals_OffscreenArrowSize, Min = 6, Max = 20, Rounding = 0, Callback = function(Value)
		Visuals.ESPVisuals_OffscreenArrowSize = Value
	end})

	OffscreenArrowsDependencyBox:AddSlider("ESPVisuals_OffscreenArrowDistance", {Text = "Arrow Distance", Default = Visuals.ESPVisuals_OffscreenArrowDistance, Min = 100, Max = 450, Rounding = 0, Callback = function(Value)
		Visuals.ESPVisuals_OffscreenArrowDistance = Value
	end})

	Visuals_ESPVisualsGroupbox:AddToggle("ESPVisuals_GrenadeTags", {Text = "Grenade Tags", Default = Visuals.ESPVisuals_GrenadeTags, Callback = function(Value)
		Visuals.ESPVisuals_GrenadeTags = Value
		if not Value then
			for Index = 1, #ESPModule.Grenades do
				ESPModule.Grenades[Index].Tag:Remove()
			end
			table.clear(ESPModule.Grenades)
		end
	end}):AddColorPicker("ESPVisuals_GrenadeTagColor", {Default = Visuals.ESPVisuals_GrenadeTagColor, Title = "Grenade Tags Color", Callback = function(Value)
		Visuals.ESPVisuals_GrenadeTagColor = Value
		for Index = 1, #ESPModule.Grenades do
			ESPModule.Grenades[Index].Tag.Color = Value
		end
	end})

	World_Camera:AddToggle("Camera_NoBob", {Text = "No Bob", Default = Visuals.Camera_NoBob, Callback = function(Value)
		Visuals.Camera_NoBob = Value
	end})
	World_Camera:AddToggle("Camera_NoSuppression", {Text = "No Suppression", Default = Visuals.Camera_NoSuppression, Callback = function(Value)
		Visuals.Camera_NoSuppression = Value
	end})
	World_Camera:AddToggle("Camera_FOVModificationEnabled", {Text = "FOV Modification", Default = Visuals.Camera_FOVModificationEnabled, Callback = function(Value)
		Visuals.Camera_FOVModificationEnabled = Value
	end})
	World_Camera:AddDependencyBox():SetupDependencies({{Toggles.Camera_FOVModificationEnabled, true}}):AddToggle("Camera_ApplyToAim", {Text = "Apply to Aim", Default = Visuals.Camera_ApplyToAim, Callback = function(Value)
		Visuals.Camera_ApplyToAim = Value
	end})

	World_Camera:AddDependencyBox():SetupDependencies({{Toggles.Camera_FOVModificationEnabled, true}}):AddSlider("Camera_FOVValue", {
		Text = "FOV Value", Default = Visuals.Camera_FOVValue, Min = 30, Max = 120, Rounding = 0, Callback = function(Value)
			Visuals.Camera_FOVValue = Value
		end
	})

	World_Camera:AddToggle("Camera_ThirdPersonView", {Text = "Third Person View", Default = Visuals.Camera_ThirdPersonView, Callback = function(Value)
		UpdateTable(Visuals, "Camera_ThirdPersonView", Value)
	end}):AddKeyPicker("Camera_ThirdPersonViewKeybind", {
		Default = Visuals.Camera_ThirdPersonViewKeybind, Mode = "Toggle", Text = "Third Person View Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
			Visuals.Camera_ThirdPersonViewKeybind = Keybind
		end, Callback = function(Value)
			if type(Value) == "boolean" then
			Toggles.Camera_ThirdPersonView:SetValue(Value)
		end
		end
	})

	local ThirdPersonDependencyBox = World_Camera:AddDependencyBox():SetupDependencies({{Toggles.Camera_ThirdPersonView, true}})

	ThirdPersonDependencyBox:AddToggle("Camera_ThirdPersonCameraCollision", {Text = "Camera Collision", Default = Visuals.Camera_ThirdPersonCameraCollision, Callback = function(Value)
		Visuals.Camera_ThirdPersonCameraCollision = Value
	end})

	ThirdPersonDependencyBox:AddToggle("Camera_ThirdPersonHideViewModel", {Text = "Hide ViewModel", Default = Visuals.Camera_ThirdPersonHideViewModel, Callback = function(Value)
		Visuals.Camera_ThirdPersonHideViewModel = Value
	end})

	ThirdPersonDependencyBox:AddSlider("Camera_ThirdPersonOffsetX", {Text = "Offset X", Default = Visuals.Camera_ThirdPersonOffsetX, Min = -20, Max = 20, Rounding = 0, Callback = function(Value)
		Visuals.Camera_ThirdPersonOffsetX = Value
	end})

	ThirdPersonDependencyBox:AddSlider("Camera_ThirdPersonOffsetY", {Text = "Offset Y", Default = Visuals.Camera_ThirdPersonOffsetY, Min = -20, Max = 20, Rounding = 0, Callback = function(Value)
		Visuals.Camera_ThirdPersonOffsetY = Value
	end})

	ThirdPersonDependencyBox:AddSlider("Camera_ThirdPersonOffsetZ", {Text = "Offset Z", Default = Visuals.Camera_ThirdPersonOffsetZ, Min = -20, Max = 20, Rounding = 0, Callback = function(Value)
		Visuals.Camera_ThirdPersonOffsetZ = Value
	end})

	ThirdPersonDependencyBox:AddToggle("Camera_ThirdPersonShowCharacter", {Text = "Show Character", Default = Visuals.Camera_ThirdPersonShowCharacter, Callback = function(Value)
		Visuals.Camera_ThirdPersonShowCharacter = Value
	end})

	local ShowCharacterDependencyBox = World_Camera:AddDependencyBox():SetupDependencies({{Toggles.Camera_ThirdPersonView, true}, {Toggles.Camera_ThirdPersonShowCharacter, true}})
	ShowCharacterDependencyBox:AddToggle("Camera_ThirdPersonShowCharacterWhileAiming", {Text = "Show Character While Aiming", Default = Visuals.Camera_ThirdPersonShowCharacterWhileAiming, Callback = function(Value)
		Visuals.Camera_ThirdPersonShowCharacterWhileAiming = Value
	end})

	ShowCharacterDependencyBox:AddToggle("Camera_ThirdPersonApplyAntiAimToCharacter", {Text = "Apply Anti Aim To Character", Default = Visuals.Camera_ThirdPersonApplyAntiAimToCharacter, Callback = function(Value)
		Visuals.Camera_ThirdPersonApplyAntiAimToCharacter = Value
	end})

	World_ViewModel:AddToggle("Viewmodel_Chams", {Text = "Viewmodel Chams", Default = Visuals.Viewmodel_Chams, Callback = function(Value)
		Visuals.Viewmodel_Chams = Value
	end}):AddColorPicker("Viewmodel_ChamsColor", {Default = Visuals.Viewmodel_ChamsColor, Title = "Chams Color", Callback = function(Value)
		Visuals.Viewmodel_ChamsColor = Value
	end})

	local ViewmodelChamsDependencyBox = World_ViewModel:AddDependencyBox():SetupDependencies({{Toggles.Viewmodel_Chams, true}})

	ViewmodelChamsDependencyBox:AddDropdown("Viewmodel_ChamsTargets", {Text = "Targets", Default = {"Arms", "Weapon"}, Multi = true, Values = {"Arms", "Weapon"}, Callback = function(Value)
		Visuals.Viewmodel_ChamsTargets = Value
	end})

	ViewmodelChamsDependencyBox:AddDropdown("Viewmodel_ChamsType", {Text = "Type", Default = Visuals.Viewmodel_ChamsType, Values = {"ForceField", "Neon", "Glass", "Plastic"}, Callback = function(Value)
		Visuals.Viewmodel_ChamsType = Value
	end})

	local ViewmodelTranslucentDependencyBox = ViewmodelChamsDependencyBox:AddDependencyBox():SetupDependencies({{Options.Viewmodel_ChamsType, {"Neon", "Glass", "Plastic"}}})

	ViewmodelTranslucentDependencyBox:AddToggle("Viewmodel_ChamsTranslucent", {Text = "Translucent", Default = Visuals.Viewmodel_ChamsTranslucent, Callback = function(Value)
		Visuals.Viewmodel_ChamsTranslucent = Value
	end})

	World_ViewModel:AddToggle("Viewmodel_NoSleeves", {Text = "No Sleeves", Default = Visuals.Viewmodel_NoSleeves, Callback = function(Value)
		Visuals.Viewmodel_NoSleeves = Value
	end})

	World_ViewModel:AddToggle("Viewmodel_CustomOffset", {Text = "Custom Offset", Default = Visuals.Viewmodel_CustomOffset, Callback = function(Value)
		Visuals.Viewmodel_CustomOffset = Value
	end})

	local ViewmodelOffsetDependencyBox = World_ViewModel:AddDependencyBox():SetupDependencies({{Toggles.Viewmodel_CustomOffset, true}})

	ViewmodelOffsetDependencyBox:AddSlider("Viewmodel_OffsetX", {Text = "Offset X", Default = Visuals.Viewmodel_OffsetX, Min = -5, Max = 5, Rounding = 1, Callback = function(Value)
		Visuals.Viewmodel_OffsetX = Value
	end})

	ViewmodelOffsetDependencyBox:AddSlider("Viewmodel_OffsetY", {Text = "Offset Y", Default = Visuals.Viewmodel_OffsetY, Min = -5, Max = 5, Rounding = 1, Callback = function(Value)
		Visuals.Viewmodel_OffsetY = Value
	end})

	ViewmodelOffsetDependencyBox:AddSlider("Viewmodel_OffsetZ", {Text = "Offset Z", Default = Visuals.Viewmodel_OffsetZ, Min = -5, Max = 5, Rounding = 1, Callback = function(Value)
		Visuals.Viewmodel_OffsetZ = Value
	end})

	World_ViewModel:AddToggle("Viewmodel_CustomRotation", {Text = "Custom Rotation", Default = Visuals.Viewmodel_CustomRotation, Callback = function(Value)
		Visuals.Viewmodel_CustomRotation = Value
	end})

	local ViewmodelRotationDependencyBox = World_ViewModel:AddDependencyBox():SetupDependencies({{Toggles.Viewmodel_CustomRotation, true}})

	ViewmodelRotationDependencyBox:AddSlider("Viewmodel_RotationX", {Text = "Rotation X", Default = Visuals.Viewmodel_RotationX, Min = -180, Max = 180, Rounding = 0, Callback = function(Value)
		Visuals.Viewmodel_RotationX = Value
	end})

	ViewmodelRotationDependencyBox:AddSlider("Viewmodel_RotationY", {Text = "Rotation Y", Default = Visuals.Viewmodel_RotationY, Min = -180, Max = 180, Rounding = 0, Callback = function(Value)
		Visuals.Viewmodel_RotationY = Value
	end})

	ViewmodelRotationDependencyBox:AddSlider("Viewmodel_RotationZ", {Text = "Rotation Z", Default = Visuals.Viewmodel_RotationZ, Min = -180, Max = 180, Rounding = 0, Callback = function(Value)
		Visuals.Viewmodel_RotationZ = Value
	end})

	World_ViewModel:AddToggle("Viewmodel_CustomRoll", {Text = "Custom Roll", Default = Visuals.Viewmodel_CustomRoll, Callback = function(Value)
		Visuals.Viewmodel_CustomRoll = Value
	end})

	World_ViewModel:AddDependencyBox():SetupDependencies({{Toggles.Viewmodel_CustomRoll, true}}):AddSlider("Viewmodel_Roll", {
		Text = "Roll", Default = Visuals.Viewmodel_Roll, Min = -180, Max = 180, Rounding = 0, Callback = function(Value)
			Visuals.Viewmodel_Roll = Value
		end
	})

	World_Lighting:AddToggle("Lighting_ModifyLighting", {Text = "Lighting Modification", Default = Visuals.Lighting_ModifyLighting, Callback = function(Value)
		UpdateTable(Visuals, "Lighting_ModifyLighting", Value, function()
			if not Visuals.Lighting_ModifyLighting then
				for Connection in next, LightingCache.Connections do
					Connection:Disconnect()
				end
				table.clear(LightingCache.Connections)
				RefreshLighting(true)
				return
			end

			for Property in next, LightingCache.OriginalValues do
				LightingCache.OriginalValues[Property] = Lighting[Property]
			end

			for Connection in next, LightingCache.Connections do
				Connection:Disconnect()
			end
			table.clear(LightingCache.Connections)

			local Properties = {"Ambient", "OutdoorAmbient", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness", "LightingStyle"}
			for _,Property in ipairs(Properties) do
				LightingCache.Connections[Lighting:GetPropertyChangedSignal(Property):Connect(function()
					local Current = Lighting[Property]
					RefreshLighting(false)
					if Lighting[Property] ~= Current then
						LightingCache.OriginalValues[Property] = Current
						RefreshLighting(false)
					end
				end)] = true
			end

			RefreshLighting(false)
		end)
	end})

	local LightingDependencyBox = World_Lighting:AddDependencyBox():SetupDependencies({{Toggles.Lighting_ModifyLighting, true}})

	LightingDependencyBox:AddSlider("Lighting_ExposureCompensation", {Text = "Exposure Compensation", Default = Visuals.Lighting_ExposureCompensation, Min = -5, Max = 5, Rounding = 1, Callback = function(Value)
		UpdateTable(Visuals, "Lighting_ExposureCompensation", Value, function(Value2)
			if Visuals.Lighting_ModifyLighting then
				Lighting.ExposureCompensation = Value2
			end
		end)
	end})

	LightingDependencyBox:AddLabel("Ambient"):AddColorPicker("Lighting_Ambient", {Default = Visuals.Lighting_Ambient, Title = "Ambient Color", Callback = function(Value)
		UpdateTable(Visuals, "Lighting_Ambient", Value, function(Value2)
			if Visuals.Lighting_ModifyLighting then
				Lighting.Ambient = Value2
			end
		end)
	end})

	LightingDependencyBox:AddLabel("Outdoor Ambient"):AddColorPicker("Lighting_OutdoorAmbient", {Default = Visuals.Lighting_OutdoorAmbient, Title = "Outdoor Ambient", Callback = function(Value)
		UpdateTable(Visuals, "Lighting_OutdoorAmbient", Value, function(Value2)
			if Visuals.Lighting_ModifyLighting then
				Lighting.OutdoorAmbient = Value2
			end
		end)
	end})

	LightingDependencyBox:AddSlider("Lighting_EnvironmentDiffuseScale", {Text = "Diffuse Scale", Default = Visuals.Lighting_EnvironmentDiffuseScale, Min = 0, Max = 1, Rounding = 1, Callback = function(Value)
		UpdateTable(Visuals, "Lighting_EnvironmentDiffuseScale", Value, function(Value2)
			if Visuals.Lighting_ModifyLighting then
				Lighting.EnvironmentDiffuseScale = Value2
			end
		end)
	end})

	LightingDependencyBox:AddSlider("Lighting_EnvironmentSpecularScale", {Text = "Specular Scale", Default = Visuals.Lighting_EnvironmentSpecularScale, Min = 0, Max = 1, Rounding = 1, Callback = function(Value)
		UpdateTable(Visuals, "Lighting_EnvironmentSpecularScale", Value, function(Value2)
			if Visuals.Lighting_ModifyLighting then
				Lighting.EnvironmentSpecularScale = Value2
			end
		end)
	end})

	LightingDependencyBox:AddSlider("Lighting_ShadowSoftness", {Text = "Shadow Softness", Default = Visuals.Lighting_ShadowSoftness, Min = 0, Max = 1, Rounding = 1, Callback = function(Value)
		UpdateTable(Visuals, "Lighting_ShadowSoftness", Value, function(Value2)
			if Visuals.Lighting_ModifyLighting then
				Lighting.ShadowSoftness = Value2
			end
		end)
	end})

	World_Lighting:AddToggle("Lighting_Flashlight", {Text = "Flashlight", Default = Visuals.Lighting_Flashlight, Callback = function(Value)
		Visuals.Lighting_Flashlight = Value
	end})

	local FlashlightDependencyBox = World_Lighting:AddDependencyBox():SetupDependencies({{Toggles.Lighting_Flashlight, true}})

	FlashlightDependencyBox:AddLabel("Flashlight Color"):AddColorPicker("Lighting_FlashlightColor", {Default = Visuals.Lighting_FlashlightColor, Title = "Flashlight Color", Callback = function(Value)
		Visuals.Lighting_FlashlightColor = Value
	end})

	FlashlightDependencyBox:AddSlider("Lighting_FlashlightBrightness", {Text = "Brightness", Default = Visuals.Lighting_FlashlightBrightness, Min = 0, Max = 10, Rounding = 1, Callback = function(Value)
		Visuals.Lighting_FlashlightBrightness = Value
	end})

	FlashlightDependencyBox:AddSlider("Lighting_FlashlightRange", {Text = "Range", Default = Visuals.Lighting_FlashlightRange, Min = 0, Max = 60, Rounding = 0, Callback = function(Value)
		Visuals.Lighting_FlashlightRange = Value
	end})

	FlashlightDependencyBox:AddSlider("Lighting_FlashlightAngle", {Text = "Angle", Default = Visuals.Lighting_FlashlightAngle, Min = 0, Max = 180, Rounding = 0, Callback = function(Value)
		Visuals.Lighting_FlashlightAngle = Value
	end})
end

local function BuildMiscellaneousTab()
	local Miscellaneous_WeaponMods = Tabs.Miscellaneous:AddLeftGroupbox("Weapon Mods")

	Miscellaneous_WeaponMods:AddSlider("WeaponMods_RecoilAdjustment", {
		Text = "Recoil Adjustment", Default = Miscellaneous.WeaponMods_RecoilAdjustment, Min = 0, Max = 100, Rounding = 0, Callback = function(Value)
			Miscellaneous.WeaponMods_RecoilAdjustment = Value
		end
	})

	Miscellaneous_WeaponMods:AddSlider("WeaponMods_SpreadAdjustment", {
		Text = "Spread Adjustment", Default = Miscellaneous.WeaponMods_SpreadAdjustment, Min = 0, Max = 100, Rounding = 0, Callback = function(Value)
			Miscellaneous.WeaponMods_SpreadAdjustment = Value
		end
	})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_NoWeaponSway", {Text = "No Weapon Sway", Default = Miscellaneous.WeaponMods_NoWeaponSway, Callback = function(Value)
		Miscellaneous.WeaponMods_NoWeaponSway = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_NoScopeSway", {Text = "No Scope Sway", Default = Miscellaneous.WeaponMods_NoScopeSway, Callback = function(Value)
		Miscellaneous.WeaponMods_NoScopeSway = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_NoWalkSway", {Text = "No Walk Sway", Default = Miscellaneous.WeaponMods_NoWalkSway, Callback = function(Value)
		Miscellaneous.WeaponMods_NoWalkSway = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_AutomaticGun", {Text = "Automatic Gun", Default = Miscellaneous.WeaponMods_AutomaticGun, Callback = function(Value)
		Miscellaneous.WeaponMods_AutomaticGun = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_InstantReload", {Text = "Instant Reload", Default = Miscellaneous.WeaponMods_InstantReload, Callback = function(Value)
		Miscellaneous.WeaponMods_InstantReload = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_InstantEquip", {Text = "Instant Equip/Unequip", Default = Miscellaneous.WeaponMods_InstantEquip, Callback = function(Value)
		Miscellaneous.WeaponMods_InstantEquip = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_InstantAim", {Text = "Instant Aim", Default = Miscellaneous.WeaponMods_InstantAim, Callback = function(Value)
		Miscellaneous.WeaponMods_InstantAim = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("WeaponMods_UncookableGrenade", {Text = "Uncookable Grenade", Default = Miscellaneous.WeaponMods_UncookableGrenade, Callback = function(Value)
		Miscellaneous.WeaponMods_UncookableGrenade = Value
	end})

	Miscellaneous_WeaponMods:AddToggle("Combat_CustomGrenadeFuse", {Text = "Custom Grenade Fuse", Default = Visuals.Combat_CustomGrenadeFuse, Callback = function(Value)
		Visuals.Combat_CustomGrenadeFuse = Value
	end})

	local FuseDependencyBox = Miscellaneous_WeaponMods:AddDependencyBox():SetupDependencies({{Toggles.Combat_CustomGrenadeFuse, true}})
	FuseDependencyBox:AddToggle("Combat_FuseOnImpact", {Text = "On Impact", Default = Visuals.Combat_FuseOnImpact, Callback = function(Value)
		Visuals.Combat_FuseOnImpact = Value
	end})
	FuseDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.Combat_CustomGrenadeFuse, true}, {Toggles.Combat_FuseOnImpact, false}}):AddSlider("Combat_FuseAmount", {
		Text = "Fuse Amount", Default = Visuals.Combat_FuseAmount, Min = 0, Max = 5, Rounding = 2, Callback = function(Value)
			Visuals.Combat_FuseAmount = Value
		end
	})

	local HitLogs_GroupBox = Tabs.Miscellaneous:AddLeftGroupbox("Hit Logs")
	HitLogs_GroupBox:AddToggle("HitLogs_Enabled", {Text = "Hit Logs", Default = Miscellaneous.HitLogs_Enabled, Callback = function(Value)
		Miscellaneous.HitLogs_Enabled = Value
	end})

	local HitLogs_DependencyBox = HitLogs_GroupBox:AddDependencyBox():SetupDependencies({{Toggles.HitLogs_Enabled, true}})
	HitLogs_DependencyBox:AddToggle("HitLogs_ShowDamage", {Text = "Show Damage", Default = Miscellaneous.HitLogs_ShowDamage, Callback = function(Value)
		Miscellaneous.HitLogs_ShowDamage = Value
	end})
	HitLogs_DependencyBox:AddToggle("HitLogs_ShowDistance", {Text = "Show Distance", Default = Miscellaneous.HitLogs_ShowDistance, Callback = function(Value)
		Miscellaneous.HitLogs_ShowDistance = Value
	end})

	local function PlaySound(Value)
		if Value ~= "None"  then
			task.spawn(PlaySoundId, CustomSounds[Value], 1, 1)
		end
	end

	local SoundOverride_Groupbox = Tabs.Miscellaneous:AddLeftGroupbox("Sound Override")
	SoundOverride_Groupbox:AddDropdown("SoundOverride_ShootSound", {Text = "Shoot", Default = Miscellaneous.SoundOverride_ShootSound, Values = SoundOptions, Callback = function(Value)
		Miscellaneous.SoundOverride_ShootSound = Value
		PlaySound(Value)
	end})
	SoundOverride_Groupbox:AddDropdown("SoundOverride_HitSound", {Text = "Hit", Default = Miscellaneous.SoundOverride_HitSound, Values = SoundOptions, Callback = function(Value)
		Miscellaneous.SoundOverride_HitSound = Value
		PlaySound(Value)
	end})
	SoundOverride_Groupbox:AddDropdown("SoundOverride_KillSound", {Text = "Kill", Default = Miscellaneous.SoundOverride_KillSound, Values = SoundOptions, Callback = function(Value)
		Miscellaneous.SoundOverride_KillSound = Value
		PlaySound(Value)
	end})
	SoundOverride_Groupbox:AddDropdown("SoundOverride_GotHitSound", {Text = "Hurt", Default = Miscellaneous.SoundOverride_GotHitSound, Values = SoundOptions, Callback = function(Value)
		Miscellaneous.SoundOverride_GotHitSound = Value
		PlaySound(Value)
	end})

	local RagdollsEffects_Groupbox = Tabs.Miscellaneous:AddLeftGroupbox("Ragdoll Effects")
	RagdollsEffects_Groupbox:AddDropdown("RagdollEffects_Mode", {Text = "Ragdoll Mode", Default = Miscellaneous.RagdollEffects_Mode, Values = {"None", "Launch", "Fling", "Float"}, Callback = function(Value)
		Miscellaneous.RagdollEffects_Mode = Value
	end})
	RagdollsEffects_Groupbox:AddDependencyBox():SetupDependencies({{Options.RagdollEffects_Mode, "Launch"}}):AddSlider("RagdollEffects_LaunchForce", {Text = "Launch Force", Default = Miscellaneous.RagdollEffects_LaunchForce, Min = 50, Max = 500, Rounding = 0, Callback = function(Value)
		Miscellaneous.RagdollEffects_LaunchForce = Value
	end})
	RagdollsEffects_Groupbox:AddDependencyBox():SetupDependencies({{Options.RagdollEffects_Mode, "Fling"}}):AddSlider("RagdollEffects_FlingForce", {Text = "Fling Force", Default = Miscellaneous.RagdollEffects_FlingForce, Min = 100, Max = 500, Rounding = 0, Callback = function(Value)
		Miscellaneous.RagdollEffects_FlingForce = Value
	end})
	RagdollsEffects_Groupbox:AddDependencyBox():SetupDependencies({{Options.RagdollEffects_Mode, "Float"}}):AddSlider("RagdollEffects_FloatSpeed", {Text = "Float Speed", Default = Miscellaneous.RagdollEffects_FloatSpeed, Min = 1, Max = 100, Rounding = 0, Callback = function(Value)
		Miscellaneous.RagdollEffects_FloatSpeed = Value
	end})

	local Miscellaneous_KnifeAura = Tabs.Miscellaneous:AddRightGroupbox("Knife Aura")
	Miscellaneous_KnifeAura:AddToggle("KnifeAura_Enabled", {Text = "Enabled", Default = Miscellaneous.KnifeAura_Enabled, Callback = function(Value)
		Miscellaneous.KnifeAura_Enabled = Value
	end}):AddKeyPicker("KnifeAura_Keybind", {Default = Miscellaneous.KnifeAura_Keybind, Mode = "Toggle", Text = "Knife Aura Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Miscellaneous.KnifeAura_Keybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.KnifeAura_Enabled:SetValue(Value)
		end
	end})

	local KnifeAuraDependencyBox = Miscellaneous_KnifeAura:AddDependencyBox():SetupDependencies({{Toggles.KnifeAura_Enabled, true}})
	KnifeAuraDependencyBox:AddDropdown("KnifeAura_Part", {Text = "Part", Default = Miscellaneous.KnifeAura_Part, Values = {"Head", "Torso", "Random"}, Callback = function(Value)
		Miscellaneous.KnifeAura_Part = Value
	end})
	KnifeAuraDependencyBox:AddToggle("KnifeAura_Wallbang", {Text = "Wallbang", Default = Miscellaneous.KnifeAura_Wallbang, Callback = function(Value)
		Miscellaneous.KnifeAura_Wallbang = Value
	end})
	KnifeAuraDependencyBox:AddToggle("KnifeAura_MultiHit", {Text = "Multi Hit", Default = Miscellaneous.KnifeAura_MultiHit, Callback = function(Value)
		Miscellaneous.KnifeAura_MultiHit = Value
	end})
	KnifeAuraDependencyBox:AddSlider("KnifeAura_Range", {
		Text = "Range", Default = Miscellaneous.KnifeAura_Range, Min = 5, Max = 25, Rounding = 0, Callback = function(Value)
			Miscellaneous.KnifeAura_Range = Value
		end
	})
	KnifeAuraDependencyBox:AddSlider("KnifeAura_Delay", {
		Text = "Hit Delay", Default = Miscellaneous.KnifeAura_Delay, Min = 0.1, Max = 0.5, Rounding = 2, Callback = function(Value)
			Miscellaneous.KnifeAura_Delay = Value
		end
	})

	local Miscellaneous_Movement = Tabs.Miscellaneous:AddRightGroupbox("Movement")
	local Miscellaneous_AntiAim = Tabs.Miscellaneous:AddRightGroupbox("Anti Aim")
	Miscellaneous_Movement:AddToggle("Movement_NoFallDamage", {Text = "No Fall Damage", Default = Miscellaneous.Movement_NoFallDamage, Callback = function(Value)
		Miscellaneous.Movement_NoFallDamage = Value
	end})
	Miscellaneous_Movement:AddToggle("Movement_BunnyHop", {Text = "Bunny Hop [May Despawn]", Default = Miscellaneous.Movement_BunnyHop, Callback = function(Value)
		Miscellaneous.Movement_BunnyHop = Value
	end}):AddKeyPicker("Movement_BunnyHopKeybind", {Default = Miscellaneous.Movement_BunnyHopKeybind, Mode = "Toggle", Text = "Bunny Hop Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Miscellaneous.Movement_BunnyHopKeybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.Movement_BunnyHop:SetValue(Value)
		end
	end})
	Miscellaneous_Movement:AddToggle("Movement_NoSlideCooldown", {Text = "No Slide Cooldown", Default = Miscellaneous.Movement_NoSlideCooldown, Callback = function(Value)
		Miscellaneous.Movement_NoSlideCooldown = Value
	end})
	Miscellaneous_Movement:AddToggle("Movement_Speed", {Text = "Speed", Default = Miscellaneous.Movement_Speed, Callback = function(Value)
		Miscellaneous.Movement_Speed = Value
	end}):AddKeyPicker("Movement_SpeedKeybind", {Default = Miscellaneous.Movement_SpeedKeybind, Mode = "Toggle", Text = "Speed Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Miscellaneous.Movement_SpeedKeybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.Movement_Speed:SetValue(Value)
		end
	end})
	local SpeedHackDependencyBox = Miscellaneous_Movement:AddDependencyBox():SetupDependencies({{Toggles.Movement_Speed, true}})
	SpeedHackDependencyBox:AddSlider("Movement_SpeedAmount", {Text = "Amount", Default = Miscellaneous.Movement_SpeedAmount, Min = 0, Max = 250, Rounding = 0, Callback = function(Value)
		Miscellaneous.Movement_SpeedAmount = Value
	end})
	Miscellaneous_Movement:AddToggle("Movement_Fly", {Text = "Fly [May Despawn]", Default = Miscellaneous.Movement_Fly, Callback = function(Value)
		Miscellaneous.Movement_Fly = Value
	end}):AddKeyPicker("Movement_FlyKeybind", {Default = Miscellaneous.Movement_FlyKeybind, Mode = "Toggle", Text = "Fly Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Miscellaneous.Movement_FlyKeybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.Movement_Fly:SetValue(Value)
		end
	end})
	local FlyDependencyBox = Miscellaneous_Movement:AddDependencyBox():SetupDependencies({{Toggles.Movement_Fly, true}})
	FlyDependencyBox:AddSlider("Movement_FlySpeed", {Text = "Speed", Default = Miscellaneous.Movement_FlySpeed, Min = 0, Max = 50, Rounding = 0, Callback = function(Value)
		Miscellaneous.Movement_FlySpeed = Value
	end})
	Miscellaneous_AntiAim:AddToggle("AntiAim_Enabled", {Text = "Enabled", Default = Miscellaneous.AntiAim_Enabled, Callback = function(Value)
		Miscellaneous.AntiAim_Enabled = Value
	end}):AddKeyPicker("AntiAim_Keybind", {Default = Miscellaneous.AntiAim_Keybind, Mode = "Toggle", Text = "Anti Aim Keybind", SyncToggleState = true, ChangedCallback = function(Keybind)
		Miscellaneous.AntiAim_Keybind = Keybind
	end, Callback = function(Value)
		if type(Value) == "boolean" then
			Toggles.AntiAim_Enabled:SetValue(Value)
		end
	end})

	local AntiAimDependencyBox = Miscellaneous_AntiAim:AddDependencyBox():SetupDependencies({{Toggles.AntiAim_Enabled, true}})
	AntiAimDependencyBox:AddToggle("AntiAim_Yaw", {Text = "Yaw", Default = Miscellaneous.AntiAim_Yaw, Callback = function(Value)
		Miscellaneous.AntiAim_Yaw = Value
	end})

	local YawDependencyBox = AntiAimDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.AntiAim_Yaw, true}})
	YawDependencyBox:AddDropdown("AntiAim_YawMode", {Text = "Yaw Mode", Default = Miscellaneous.AntiAim_YawMode, Values = {"Custom - Relative", "Custom - Absolute", "Backwards", "Rotate", "Random", "Cycle"}, Callback = function(Value)
		Miscellaneous.AntiAim_YawMode = Value
	end})
	YawDependencyBox:AddDependencyBox():SetupDependencies({{Options.AntiAim_YawMode, {"Custom - Relative", "Custom - Absolute"}}}):AddSlider("AntiAim_YawAmount", {
		Text = "Yaw Amount", Default = Miscellaneous.AntiAim_YawAmount, Min = 0, Max = 360, Rounding = 0, Callback = function(Value)
			Miscellaneous.AntiAim_YawAmount = Value
		end
	})
	YawDependencyBox:AddDependencyBox():SetupDependencies({{Options.AntiAim_YawMode, {"Rotate", "Cycle"}}}):AddSlider("AntiAim_YawSpeed", {
		Text = "Yaw Speed", Default = Miscellaneous.AntiAim_YawSpeed, Min = 0, Max = 50, Rounding = 0, Callback = function(Value)
			Miscellaneous.AntiAim_YawSpeed = Value
		end
	})
	AntiAimDependencyBox:AddToggle("AntiAim_Pitch", {Text = "Pitch", Default = Miscellaneous.AntiAim_Pitch, Callback = function(Value)
		Miscellaneous.AntiAim_Pitch = Value
	end})

	local PitchDependencyBox = AntiAimDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.AntiAim_Pitch, true}})
	PitchDependencyBox:AddDropdown("AntiAim_PitchMode", {Text = "Pitch Mode", Default = Miscellaneous.AntiAim_PitchMode, Values = {"Custom - Relative", "Custom - Absolute", "Rotate", "Random"}, Callback = function(Value)
		Miscellaneous.AntiAim_PitchMode = Value
	end})
	PitchDependencyBox:AddDependencyBox():SetupDependencies({{Options.AntiAim_PitchMode, {"Custom - Relative", "Custom - Absolute"}}}):AddSlider("AntiAim_PitchAmount", {
		Text = "Pitch Amount", Default = Miscellaneous.AntiAim_PitchAmount, Min = 0, Max = 180, Rounding = 0, Callback = function(Value)
			Miscellaneous.AntiAim_PitchAmount = Value
		end
	})
	PitchDependencyBox:AddDependencyBox():SetupDependencies({{Options.AntiAim_PitchMode, "Rotate"}}):AddSlider("AntiAim_PitchSpeed", {
		Text = "Pitch Speed", Default = Miscellaneous.AntiAim_PitchSpeed, Min = 0, Max = 50, Rounding = 0, Callback = function(Value)
			Miscellaneous.AntiAim_PitchSpeed = Value
		end
	})
	AntiAimDependencyBox:AddToggle("AntiAim_Jitter", {Text = "Jitter", Default = Miscellaneous.AntiAim_Jitter, Callback = function(Value)
		Miscellaneous.AntiAim_Jitter = Value
	end})
	AntiAimDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.AntiAim_Jitter, true}}):AddSlider("AntiAim_JitterAmount", {
		Text = "Jitter Amount", Default = Miscellaneous.AntiAim_JitterAmount, Min = 0, Max = 360, Rounding = 0, Callback = function(Value)
			Miscellaneous.AntiAim_JitterAmount = Value
		end
	})
	AntiAimDependencyBox:AddToggle("AntiAim_SpinBot", {Text = "Spin Bot", Default = Miscellaneous.AntiAim_SpinBot, Callback = function(Value)
		Miscellaneous.AntiAim_SpinBot = Value
	end})

	local SpinBotDependencyBox = AntiAimDependencyBox:AddDependencyBox():SetupDependencies({{Toggles.AntiAim_SpinBot, true}})
	SpinBotDependencyBox:AddDropdown("AntiAim_SpinDirection", {Text = "Spin Direction", Default = Miscellaneous.AntiAim_SpinDirection, Values = {"Left", "Right"}, Callback = function(Value)
		Miscellaneous.AntiAim_SpinDirection = Value
	end})
	SpinBotDependencyBox:AddSlider("AntiAim_SpinSpeed", {Text = "Spin Speed", Default = Miscellaneous.AntiAim_SpinSpeed, Min = 1, Max = 1000, Rounding = 0, Callback = function(Value)
		Miscellaneous.AntiAim_SpinSpeed = Value
	end})

	local Miscellaneous_ClientSessionUnlocks = Tabs.Miscellaneous:AddRightGroupbox("Client Session Unlocks")
	Miscellaneous_ClientSessionUnlocks:AddButton({Text = "Unlock Attachments", Func = function()
		Miscellaneous.ClientSessionUnlocks_AttachmentsUnlocked = true
	end})
	Miscellaneous_ClientSessionUnlocks:AddButton({Text = "Unlock Knives", Func = function()
		Miscellaneous.ClientSessionUnlocks_KnivesUnlocked = true
	end})
	Miscellaneous_ClientSessionUnlocks:AddButton({Text = "Unlock Camos", Func = function()
		if Miscellaneous.ClientSessionUnlocks_CamosUnlocked then
			return Library:Notify("All camos have already been unlocked.", 3)
		end

		for _,Table in next, (getgc or get_gc)(true) do
			if type(Table) ~= "table"  or not rawget(Table, "Mentha Spicata") or not rawget(Table, "Dove blue") then
				continue
			end

			local GetCasePacketData = PlayerDataUtils.getCasePacketData
			for Name, Data in next, Table do
				local Case = Data.Case
				if Case then
					GetCasePacketData(PlayerDataClientInterface.getPlayerData(), Case, true).Skins[Name] = {ALL = true}
				end
			end

			Miscellaneous.ClientSessionUnlocks_CamosUnlocked = true
			Library:Notify("Successfully unlocked all camos.", 5)
			break
		end
	end})
	Miscellaneous_ClientSessionUnlocks:AddLabel("Information [MUST READ | HOVER]", false, "As of 9/19/2026, these Unlocks are undetected, use at your own risk.\n1. These Unlocks only last for the current session and are only visible to you, not others.\n2. Dropping Unlocked weapons makes it lose any Unlocked Add-Ons meaning you'll need to respawn to have the Add-Ons again.\n3. Dropping an Unlocked Knife in a match will make it dissapear.")

	local Miscellaneous_Extras = Tabs.Miscellaneous:AddRightGroupbox("Extras")
	Miscellaneous_Extras:AddButton({Text = "Break All Windows", Func = BreakAllWindows})
	Miscellaneous_Extras:AddToggle("Extras_LoopBreakAllWindows", {Text = "Loop Break All Windows", Default = Miscellaneous.Extras_LoopBreakAllWindows, Callback = function(Value)
		Miscellaneous.Extras_LoopBreakAllWindows = Value
	end})
	Miscellaneous_Extras:AddToggle("Extras_HopOnVotekick", {Text = "Hop On Votekick", Default = Miscellaneous.Extras_HopOnVotekick, Callback = function(Value)
		Miscellaneous.Extras_HopOnVotekick = Value
	end})

	task.spawn(function()
		while true do
			if Miscellaneous.Extras_LoopBreakAllWindows then
				BreakAllWindows()
			end
			task.wait(5)
		end
	end)
end

local LoadAutoLoad
local function BuildSettingsTab()
	local Settings_UserInterface = Tabs.Settings:AddLeftGroupbox("User Interface")
	LoadAutoLoad = Settings_UserInterface:CreateConfigurationManager("NikoletoScripts/PhantomWare", ".ns", {Aiming, Visuals, Miscellaneous, Settings})
	Settings_UserInterface:AddLabel("Menu Toggle Keybind"):AddKeyPicker("Inactive4", {Default = "RightShift", Mode = "Toggle", Text = "Menu Toggle Keybind", Callback = function(Value)
		Library:Toggle()
	end})

	local Settings_Advanced = Tabs.Settings:AddRightGroupbox("Advanced")
	Settings_Advanced:AddToggle("Advanced_MultiPointEnabled", {Text = "Multi-Point Raycasting", Default = Settings.Advanced_MultiPointEnabled, Callback = function(Value)
		Settings.Advanced_MultiPointEnabled = Value
	end})

	local MultiPointDependencyBox = Settings_Advanced:AddDependencyBox():SetupDependencies({{Toggles.Advanced_MultiPointEnabled, true}})
	MultiPointDependencyBox:AddSlider("Advanced_MultiPointScale", {Text = "Scale", Default = Settings.Advanced_MultiPointScale, Min = 2, Max = 10, Rounding = 0, Callback = function(Value)
		Settings.Advanced_MultiPointScale = Value
	end})
	MultiPointDependencyBox:AddSlider("Advanced_MultiPointLayers", {Text = "Layers", Default = Settings.Advanced_MultiPointLayers, Min = 1, Max = 5, Rounding = 0, Callback = function(Value)
		Settings.Advanced_MultiPointLayers = Value
	end})

	Settings_Advanced:AddToggle("Debug_PassthroughACPackets", {
		Text = "Passthrough AC Packets", Default = Settings.Debug_PassthroughACPackets, Callback = function(Value)
			Settings.Debug_PassthroughACPackets = Value
		end
	})

	Settings_Advanced:AddButton({Text = "Server Hop", Func = function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
	end})

	Tabs.Settings:AddRightGroupbox("Debug Info"):AddLabel("Module Method: " .. Module.Method)
end

BuildAimingTab()
BuildMiscellaneousTab()
BuildVisualsTab()
BuildSettingsTab()

Module.Players.PlayerRemoving:Connect(function(Player)
	ESPModule:Clear(Player)
	MovementCache[Player] = nil
end)

local FakeReplicationObject = nil
task.spawn(function()
	FakeReplicationObject = Module.__get("ReplicationObject").new(setmetatable({}, {
		__index = function(_,Index)
			if Index == "GetPropertyChangedSignal" then
				return function(_,Property)
					return LocalPlayer:GetPropertyChangedSignal(Property)
				end
			end
			return LocalPlayer[Index]
		end, __newindex = function(_,Index, Value)
			LocalPlayer[Index] = Value
		end
	}))
end)

local KnifeAuraModule = {NextHit = 0}
function KnifeAuraModule:Update()
	if Miscellaneous.KnifeAura_Enabled and IsSpawned then
		local Now = os.clock()
		if Now >= self.NextHit then
			local Origin, SelectedPart = GetLocalPosition(), Miscellaneous.KnifeAura_Part
			local PartName = SelectedPart == "Random" and (math.random(2) == 1 and "Head" or "Torso") or SelectedPart
			local Best, BestPart, BestDistance = nil, nil, Miscellaneous.KnifeAura_Range
			local MultiTargets = Miscellaneous.KnifeAura_MultiHit and {}

			OperateOnAllEntries(function(Player, Entry)
				if not Entry._alive or not Entry._isEnemy or not Entry._velspring.t then
					return
				end

				local Character = GetCharacter(Entry)
				local Part = Character and Character[PartName]
				if not Part then
					return
				end

				local Distance = (Part.Position - Origin).Magnitude
				if Distance >= BestDistance then
					return
				end

				if MultiTargets then
					if Miscellaneous.KnifeAura_Wallbang or not TransparentRaycast(Origin, Part.Position - Origin, AimingRaycastParams) then
						table.insert(MultiTargets, {Player, Part})
					end
				elseif Distance < BestDistance then
					Best, BestPart, BestDistance = Player, Part, Distance
				end
			end)

			if MultiTargets then
				if #MultiTargets > 0 then
					self.NextHit = Now + Miscellaneous.KnifeAura_Delay
					NetworkClientSend(NetworkClient, "stab")
					for _,Hit in next, MultiTargets do
						NetworkClientSend(NetworkClient, "knifehit", Hit[1], PartName, Hit[2].Position, NetworkClient.getTime())
					end
				end
			elseif Best and (Miscellaneous.KnifeAura_Wallbang or not TransparentRaycast(Origin, BestPart.Position - Origin, AimingRaycastParams)) then
				self.NextHit = Now + Miscellaneous.KnifeAura_Delay
				NetworkClientSend(NetworkClient, "stab")
				NetworkClientSend(NetworkClient, "knifehit", Best, PartName, BestPart.Position, NetworkClient.getTime())
			end
		end
	end
end

function ESPModule:Update(LocalHeadPosition)
	local GlobalOpacity = Visuals.ESPVisuals_MasterOpacity * 0.01
	OperateOnAllEntries(function(Player, Entry)
		if not Entry._alive or not Entry._isEnemy or not Entry._velspring.t then
			return self:Clear(Player)
		end

		local Character = GetCharacter(Entry)
		if not Character then
			return self:Clear(Player)
		end

		local Head = Character.Head
		local Torso = Character.Torso
		local LeftArm = Character["Left Arm"]
		local RightArm = Character["Right Arm"]
		local LeftLeg = Character["Left Leg"]
		local RightLeg = Character["Right Leg"]
		local HighlightGroup = self.Highlights[Player]
		if not HighlightGroup then
			HighlightGroup = {}
			self.Highlights[Player] = HighlightGroup
		end

		if Visuals.ESPVisuals_Chams then
			local ChamsColor
			if Visuals.ESPVisuals_ChamsStyle == "Visible" and (CanSee(Head) or CanSee(Torso) or CanSee(LeftArm) or CanSee(RightArm) or CanSee(LeftLeg) or CanSee(RightLeg)) then
				ChamsColor = Visuals.ESPVisuals_ChamsVisibleColor
			else
				ChamsColor = Visuals.ESPVisuals_ChamsColor
			end

			local ChamsRendering = Visuals.ESPVisuals_ChamsRendering
			local RenderFill, RenderOutline = ChamsRendering.Fill, ChamsRendering.Outline
			if RenderFill or RenderOutline then
				local Highlight = HighlightGroup.Full
				if not Highlight then
					Highlight = ns__cloneref(Instance.new("Highlight"))
					Highlight.Parent = CoreGui
					HighlightGroup.Full = Highlight
				end

				Highlight.DepthMode = Visuals.ESPVisuals_ChamsOccluded and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
				Highlight.Adornee = Head.Parent
				local Opacity = 1 - GlobalOpacity
				Highlight.Enabled = true
				Highlight.FillColor = ChamsColor
				Highlight.OutlineColor = DarkerColorCache[ChamsColor]
				Highlight.FillTransparency = RenderFill and Opacity or 1
				Highlight.OutlineTransparency = RenderOutline and Opacity or 1
			else
				local Full = HighlightGroup.Full
				if Full then
					HighlightGroup.Full = nil
					Full:Destroy()
				end
			end
		else
			local Full = HighlightGroup.Full
			if Full then
				HighlightGroup.Full = nil
				Full:Destroy()
			end
		end

		local DrawingGroup = self.Objects[Player]
		if not DrawingGroup then
			DrawingGroup = {
				Box = CreateDrawing("Square", {Filled = false, Color = Visuals.ESPVisuals_BoxColor, Thickness = Visuals.ESPVisuals_BoxThickness}),
				HealthbarOutline = CreateDrawing("Square", {Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1}),
				HealthbarBackground = CreateDrawing("Square", {Filled = true, Color = Color3.fromRGB(8, 8, 8)}),
				Healthbar = CreateDrawing("Square", {Filled = true, Color = Visuals.ESPVisuals_HealthbarColor}),
				Tag = CreateDrawing("Text", {Size = Visuals.ESPVisuals_TagSize, Outline = true, Center = true, Color = Visuals.ESPVisuals_TagColor}),
				Dot = CreateDrawing("Circle", {Filled = true, Radius = Visuals.ESPVisuals_DotSize, Color = Visuals.ESPVisuals_DotColor}),
				Tracer = CreateDrawing("Line", {Color = Visuals.ESPVisuals_TracerColor, Thickness = Visuals.ESPVisuals_TracerThickness}),
				Arrow = CreateDrawing("Triangle", {Filled = false, Color = Visuals.ESPVisuals_OffscreenArrowColor, Thickness = 2}),
				SkeletonHead = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonSpine = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonLeftShoulder = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonRightShoulder = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonLeftArm = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonRightArm = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonLeftHip = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonRightHip = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonLeftLeg = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
				SkeletonRightLeg = CreateDrawing("Line", {Color = Visuals.ESPVisuals_SkeletonsColor, Thickness = Visuals.ESPVisuals_SkeletonsThickness}),
			}
			self.Objects[Player] = DrawingGroup
			for _,DrawingObject in next, DrawingGroup do
				DrawingObject.Transparency = GlobalOpacity
			end
		end

		local Box, Tag, Dot, Tracer, Arrow = DrawingGroup.Box, DrawingGroup.Tag, DrawingGroup.Dot, DrawingGroup.Tracer, DrawingGroup.Arrow
		local HealthbarOutline, HealthbarBackground, Healthbar = DrawingGroup.HealthbarOutline, DrawingGroup.HealthbarBackground, DrawingGroup.Healthbar
		local SkeletonHead, SkeletonSpine, SkeletonLeftShoulder, SkeletonRightShoulder, SkeletonLeftArm, SkeletonRightArm, SkeletonLeftHip, SkeletonRightHip, SkeletonLeftLeg, SkeletonRightLeg = DrawingGroup.SkeletonHead, DrawingGroup.SkeletonSpine, DrawingGroup.SkeletonLeftShoulder, DrawingGroup.SkeletonRightShoulder, DrawingGroup.SkeletonLeftArm, DrawingGroup.SkeletonRightArm, DrawingGroup.SkeletonLeftHip, DrawingGroup.SkeletonRightHip, DrawingGroup.SkeletonLeftLeg, DrawingGroup.SkeletonRightLeg

		local HeadPosition = Head.Position
		local HeadScreen, HeadOnScreen = WorldToViewportPoint(HeadPosition)

		if not HeadOnScreen then
			SetProperty(Box, "Visible", false)
			SetProperty(Tag, "Visible", false)
			SetProperty(Dot, "Visible", false)
			SetProperty(Tracer, "Visible", false)
			SetProperty(HealthbarOutline, "Visible", false)
			SetProperty(HealthbarBackground, "Visible", false)
			SetProperty(Healthbar, "Visible", false)
			SetProperty(SkeletonHead, "Visible", false)
			SetProperty(SkeletonSpine, "Visible", false)
			SetProperty(SkeletonLeftShoulder, "Visible", false)
			SetProperty(SkeletonRightShoulder, "Visible", false)
			SetProperty(SkeletonLeftArm, "Visible", false)
			SetProperty(SkeletonRightArm, "Visible", false)
			SetProperty(SkeletonLeftHip, "Visible", false)
			SetProperty(SkeletonRightHip, "Visible", false)
			SetProperty(SkeletonLeftLeg, "Visible", false)
			SetProperty(SkeletonRightLeg, "Visible", false)
			if Visuals.ESPVisuals_OffscreenArrows then
				local Relative = Camera.CFrame:PointToObjectSpace(HeadPosition)
				local Bearing = math.atan2(Relative.X, -Relative.Z)
				local ScreenDirection = Vector2.new(math.sin(Bearing), -math.cos(Bearing))
				local Center = ScreenCenter + ScreenDirection * math.min(Visuals.ESPVisuals_OffscreenArrowDistance, math.min(ScreenXCenter, ScreenYCenter) - 30)
				local Size = Visuals.ESPVisuals_OffscreenArrowSize
				local Tip = Center + ScreenDirection * Size

				local Base = Center - ScreenDirection * Size * 0.5
				local Perpendicular = Vector2.new(-ScreenDirection.Y, ScreenDirection.X) * Size * 0.6
				SetProperty(Arrow, "PointA", Tip)
				SetProperty(Arrow, "PointB", Base + Perpendicular)
				SetProperty(Arrow, "PointC", Base - Perpendicular)
				SetProperty(Arrow, "Visible", true)
			else
				SetProperty(Arrow, "Visible", false)
			end
			return
		end

		local HeadScreenX = HeadScreen.X
		local TorsoPosition = Torso.Position
		local TopScreen, TopOnScreen = Camera:WorldToViewportPoint(HeadPosition + Vector3.new(0, Head.Size.Y * 0.5 + 1.2, 0))
		local BottomScreen, BottomOnScreen = Camera:WorldToViewportPoint(TorsoPosition - Vector3.new(0, Torso.Size.Y * 0.5 + 3.0, 0))
		local BottomScreenY = BottomScreen.Y

		if TopOnScreen and BottomOnScreen then
			local TopScreenY = TopScreen.Y
			local BoxHeight = BottomScreenY - TopScreenY
			local BoxWidth = BoxHeight * 0.65
			local Health = Entry:getHealth()

			if Visuals.ESPVisuals_Boxes then
				SetProperty(Box, "Visible", true)
				SetProperty(Box, "Size", Vector2.new(BoxWidth, BoxHeight))
				SetProperty(Box, "Position", Vector2.new(HeadScreenX - BoxWidth * 0.5, TopScreenY))
			else
				SetProperty(Box, "Visible", false)
			end

			if Visuals.ESPVisuals_HeadTags then
				SetProperty(Tag, "Visible", true)

				local Elements = Visuals.ESPVisuals_HeadTagElements
				local Text = ""
				if Elements.Name then
					Text = Player.Name
				end

				if Elements.Health then
					Text ..= (Text ~= "" and (" [") or "[") .. tostring(math.floor(Health)) .. "]"
				end

				if Elements.Distance then
					local Distance = math.floor((LocalHeadPosition - TorsoPosition).Magnitude)
					Text ..= (Text ~= "" and (" [%dm]"):format(Distance) or ("[%dm]"):format(Distance))
				end

				if Elements.Visibility then
					local Visibility = (CanSee(Head) or CanSee(Torso) or CanSee(LeftArm) or CanSee(RightArm) or CanSee(LeftLeg) or CanSee(RightLeg)) and "[Visible]" or "[Hidden]"
					Text ..= (Text ~= "" and (" " .. Visibility) or Visibility)
				end

				SetProperty(Tag, "Text", Text)
				SetProperty(Tag, "Position", Vector2.new(HeadScreenX, TopScreenY - Tag.Size - 3))
			else
				SetProperty(Tag, "Visible", false)
			end

			if Visuals.ESPVisuals_Healthbars then
				local BarWidth = math.clamp(Visuals.ESPVisuals_HealthbarWidth, 3, 8)
				local BarHeight = math.max(24, BoxHeight * 0.9)
				local BarX = HeadScreenX + BoxWidth * 0.5 + 5
				local BarY = TopScreenY + (BoxHeight - BarHeight) * 0.5
				local FillHeight = math.max(1, math.floor((BarHeight - 2) * math.clamp(Health * 0.01, 0, 1)))

				SetProperty(HealthbarOutline, "Visible", true)
				SetProperty(HealthbarOutline, "Size", Vector2.new(BarWidth, BarHeight))
				SetProperty(HealthbarOutline, "Position", Vector2.new(BarX, BarY))

				SetProperty(HealthbarBackground, "Visible", true)
				SetProperty(HealthbarBackground, "Size", Vector2.new(BarWidth - 2, BarHeight - 2))
				SetProperty(HealthbarBackground, "Position", Vector2.new(BarX + 1, BarY + 1))

				SetProperty(Healthbar, "Visible", true)
				SetProperty(Healthbar, "Size", Vector2.new(BarWidth - 2, FillHeight))
				SetProperty(Healthbar, "Position", Vector2.new(BarX + 1, BarY + 1 + ((BarHeight - 2) - FillHeight)))
			else
				SetProperty(HealthbarOutline, "Visible", false)
				SetProperty(HealthbarBackground, "Visible", false)
				SetProperty(Healthbar, "Visible", false)
			end
		else
			SetProperty(Box, "Visible", false)
			SetProperty(Tag, "Visible", false)
			SetProperty(HealthbarOutline, "Visible", false)
			SetProperty(HealthbarBackground, "Visible", false)
			SetProperty(Healthbar, "Visible", false)
		end

		if Visuals.ESPVisuals_Dots then
			SetProperty(Dot, "Visible", true)
			SetProperty(Dot, "Position", HeadScreen)
		else
			SetProperty(Dot, "Visible", false)
		end

		if Visuals.ESPVisuals_Skeletons then
			local TorsoCFrame = Torso.CFrame
			local NeckJoint, HeadSize, HeadCFrame = TorsoCFrame * Vector3.new(0, 1.5, 0), Head.Size, Head.CFrame
			DrawBone(SkeletonHead, NeckJoint, HeadCFrame.Position + HeadCFrame.UpVector * math.max(math.abs(HeadSize.X), math.abs(HeadSize.Y), math.abs(HeadSize.Z)) * 0.5)

			local LowerTorso = TorsoCFrame.Position
			DrawBone(SkeletonSpine, NeckJoint, LowerTorso)

			local LeftShoulder, RightShoulder = TorsoCFrame * Vector3.new(-0.5, 0.5, 0), TorsoCFrame * Vector3.new(0.5, 0.5, 0)
			DrawBone(SkeletonLeftShoulder, NeckJoint, LeftShoulder)
			DrawBone(SkeletonRightShoulder, NeckJoint, RightShoulder)
			DrawBone(SkeletonLeftArm, LeftShoulder, LeftArm.CFrame.Position + (LeftArm.CFrame.Position - LeftShoulder).Unit * 1.5)
			DrawBone(SkeletonRightArm, RightShoulder, RightArm.CFrame.Position + (RightArm.CFrame.Position - RightShoulder).Unit * 1.5)

			local LeftHip = TorsoCFrame * Vector3.new(-0.5, -0.5, 0)
			local RightHip = TorsoCFrame * Vector3.new(0.5, -0.5, 0)
			DrawBone(SkeletonLeftHip, LowerTorso, LeftHip)
			DrawBone(SkeletonRightHip, LowerTorso, RightHip)

			local ThirdPersonObject = Entry._thirdPersonObject
			DrawBone(SkeletonLeftLeg, LeftHip, ThirdPersonObject._leftFoot.pos)
			DrawBone(SkeletonRightLeg, RightHip, ThirdPersonObject._rightFoot.pos)
		else
			SetProperty(SkeletonHead, "Visible", false)
			SetProperty(SkeletonSpine, "Visible", false)
			SetProperty(SkeletonLeftShoulder, "Visible", false)
			SetProperty(SkeletonRightShoulder, "Visible", false)
			SetProperty(SkeletonLeftArm, "Visible", false)
			SetProperty(SkeletonRightArm, "Visible", false)
			SetProperty(SkeletonLeftHip, "Visible", false)
			SetProperty(SkeletonRightHip, "Visible", false)
			SetProperty(SkeletonLeftLeg, "Visible", false)
			SetProperty(SkeletonRightLeg, "Visible", false)
		end

		if Visuals.ESPVisuals_Tracers then
			local Origin = Visuals.ESPVisuals_TracerOrigin
			if Origin == "Top" then
				SetProperty(Tracer, "From", ScreenTop)
			elseif Origin == "Center" then
				SetProperty(Tracer, "From", ScreenCenter)
			else
				SetProperty(Tracer, "From", ScreenBottom)
			end
			SetProperty(Tracer, "To", Visuals.ESPVisuals_TracerTarget == "Torso" and Vector2.new(HeadScreenX, (HeadScreen.Y + BottomScreenY) * 0.5) or HeadScreen)
			SetProperty(Tracer, "Visible", true)
		else
			SetProperty(Tracer, "Visible", false)
		end
		SetProperty(Arrow, "Visible", false)
	end)
end

local function CubicNodePosition(Node1, Node2, Time)
	local StartTime, EndTime = Node1.t, Node2.t
	if EndTime <= StartTime then
		return Node2.p
	end

	local TimeSpan = EndTime - StartTime
	local InvTimeSpan = 1 / TimeSpan
	local ForwardWeight, BackwardWeight = (Time - StartTime) * InvTimeSpan, (EndTime - Time) * InvTimeSpan
	return BackwardWeight * BackwardWeight * (BackwardWeight + 3 * ForwardWeight) * Node1.p + TimeSpan * BackwardWeight * BackwardWeight * ForwardWeight * Node1.v - TimeSpan * BackwardWeight * ForwardWeight * ForwardWeight * Node2.v + ForwardWeight * ForwardWeight * (ForwardWeight + 3 * BackwardWeight) * Node2.p
end

local HitMarkerModule = {Active = {}}

function HitMarkerModule:Spawn(Position)
	local DrawingObjects = {}
	for _ = 1, 4 do
		DrawingObjects[#DrawingObjects + 1] = CreateDrawing("Line", {Thickness = 1.5})
	end

	table.insert(self.Active, {
		Position = Position,
		Time = os.clock(),
		Duration = Visuals.Combat_HitMarkerDuration,
		Style = Visuals.Combat_HitMarkerStyle,
		Color = Visuals.Combat_HitMarkerColor,
		DrawingObjects = DrawingObjects,
	})
end

function HitMarkerModule:Update(Now)
	for Index = #self.Active, 1, -1 do
		local Marker = self.Active[Index]
		local DrawingObjects = Marker.DrawingObjects
		local Elapsed = Now - Marker.Time

		if Elapsed >= Marker.Duration then
			for _,DrawingObject in ipairs(DrawingObjects) do
				DrawingObject:Remove()
			end
			table.remove(self.Active, Index)
			continue
		end

		local Screen, OnScreen = WorldToViewportPoint(Marker.Position)
		if not OnScreen then
			for _,DrawingObject in ipairs(DrawingObjects) do
				SetProperty(DrawingObject, "Visible", false)
			end
			continue
		end

		local X, Y = Screen.X, Screen.Y
		local Spin = Visuals.Combat_HitMarkerSpin
		local Size = Visuals.Combat_HitMarkerSize
		local Gap = Visuals.Combat_HitMarkerGap
		local Angle = Spin and Elapsed * Visuals.Combat_HitMarkerSpinSpeed or 0
		local MarkerColor = Marker.Color
		if Marker.Style == "X" then
			HandleLine(DrawingObjects[1], Vector2.new(X - Size, Y - Size), Vector2.new(X - Gap, Y - Gap), Screen, Angle, MarkerColor, Spin)
			HandleLine(DrawingObjects[2], Vector2.new(X + Size, Y - Size), Vector2.new(X + Gap, Y - Gap), Screen, Angle, MarkerColor, Spin)
			HandleLine(DrawingObjects[3], Vector2.new(X - Size, Y + Size), Vector2.new(X - Gap, Y + Gap), Screen, Angle, MarkerColor, Spin)
			HandleLine(DrawingObjects[4], Vector2.new(X + Size, Y + Size), Vector2.new(X + Gap, Y + Gap), Screen, Angle, MarkerColor, Spin)
		else
			HandleLine(DrawingObjects[1], Vector2.new(X - Size, Y), Vector2.new(X - Gap, Y), Screen, Angle, MarkerColor, Spin)
			HandleLine(DrawingObjects[2], Vector2.new(X + Size, Y), Vector2.new(X + Gap, Y), Screen, Angle, MarkerColor, Spin)
			HandleLine(DrawingObjects[3], Vector2.new(X, Y - Size), Vector2.new(X, Y - Gap), Screen, Angle, MarkerColor, Spin)
			HandleLine(DrawingObjects[4], Vector2.new(X, Y + Size), Vector2.new(X, Y + Gap), Screen, Angle, MarkerColor, Spin)
		end
	end
end

local ns__mousemoverel = mousemoverel or (function()
	Library:Notify("Required function for Mouse Aimbot is not supported, Mouse Aimbot will not function.", 6.75)
	return function(...)
		return (...)
	end
end)()

local function UpdateAimbot(LocalHeadPosition)
	if Aiming.Aimbot_Enabled then
		local ShowFOV = Aiming.Aimbot_ShowFOV
		if ShowFOV then
			local DrawRadius = Aiming.Aimbot_FOVRadius
			if Aiming.Aimbot_DynamicFOV then
				local AngleDeg = DrawRadius / 10
				local ViewportSize = Camera.ViewportSize
				local HalfFOV = math.rad(Camera.FieldOfView / 2)
				local FocalLength = (ViewportSize.Y / 2) / math.tan(HalfFOV)
				DrawRadius = math.tan(math.rad(AngleDeg)) * FocalLength
			end
			SetProperty(FOVCircle, "Radius", DrawRadius)
			SetProperty(FOVCircle, "Position", GetFOVOrigin())
			SetProperty(FOVCircle, "Visible", true)
		else
			SetProperty(FOVCircle, "Visible", false)
		end

		local IsLocking = false
		local IsAimkeyActive = Aiming.Aimbot_Type == "Silent" or (not AimkeyBoundCode and not AimkeyIsMB2) or IsAimkeyDown
		if IsSpawned and IsAimkeyActive then
			local TargetPart, Target, IsTargetVisible, TargetScreen, ClosestScore = nil, nil, false, nil, math.huge
			local RawFOVRadius = Aiming.Aimbot_FOVRadius
			local FOVRadius
			if ShowFOV then
				if Aiming.Aimbot_DynamicFOV then
					local AngleDeg = RawFOVRadius / 10
					local ViewportSize = Camera.ViewportSize
					local HalfFOV = math.rad(Camera.FieldOfView / 2)
					local FocalLength = (ViewportSize.Y / 2) / math.tan(HalfFOV)
					FOVRadius = math.tan(math.rad(AngleDeg)) * FocalLength
				else
					FOVRadius = RawFOVRadius
				end
			else
				FOVRadius = math.huge
			end
			local IsWallCheckOff = not Aiming.Aimbot_WallCheck
			local AimbotPart, FOVOrigin = Aiming.Aimbot_Part, ShowFOV and GetFOVOrigin() or ScreenCenter
			local CenterX, CenterY = FOVOrigin.X, FOVOrigin.Y

			local function CheckPlayer(Player, Character)
				local Torso = Character and Character.Torso
				if not Torso or not Torso.Parent then
					return
				end

				local CameraCFrame, TorsoPosition = Camera.CFrame, Torso.Position
				local CameraPosition, LookVector = CameraCFrame.Position, CameraCFrame.LookVector
				local DeltaX, DeltaY, DeltaZ = TorsoPosition.X - CameraPosition.X, TorsoPosition.Y - CameraPosition.Y, TorsoPosition.Z - CameraPosition.Z
				local DeltaMagnitude = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ)
				if DeltaMagnitude < 0.001 or (LookVector.X * DeltaX + LookVector.Y * DeltaY + LookVector.Z * DeltaZ) / DeltaMagnitude < 0 then
					return
				end

				local Part, Screen, IsVisible = GetTargetPart(Character, AimbotPart, IsWallCheckOff)
				if not Part or not Screen then
					return
				end

				DeltaX, DeltaY = Screen.X - CenterX, Screen.Y - CenterY
				local Distance = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY)
				if Distance > FOVRadius and Player ~= AimbotTarget then
					return
				end

				local PartPosition = Part.Position
				DeltaX, DeltaY, DeltaZ = PartPosition.X - LocalHeadPosition.X, PartPosition.Y - LocalHeadPosition.Y, PartPosition.Z - LocalHeadPosition.Z
				local Score = Distance + math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ) * 0.15
				if Player == AimbotTarget and Aiming.Aimbot_TargetStickiness > 0 then
					Score = Score - Aiming.Aimbot_TargetStickiness
				end
				if Score < ClosestScore then
					ClosestScore = Score
					Target = Player
					TargetPart = Part
					IsTargetVisible = IsVisible
					TargetScreen = Screen
				end
			end

			local AimbotTargetEntry = AimbotTarget and GetPlayerEntry(AimbotTarget)
			if AimbotTargetEntry and AimbotTargetEntry._alive and Aiming.Aimbot_Type ~= "Silent" then
				local Character = GetCharacter(AimbotTargetEntry)
				if Character then
					CheckPlayer(AimbotTarget, Character)
				end
			end

			OperateOnAllEntries(function(Player, Entry)
				if Player == AimbotTarget then return end
				if not Entry._alive or not Entry._isEnemy or not Entry._velspring.t then
					return
				end

				local Character = GetCharacter(Entry)
				if Character then
					CheckPlayer(Player, Character)
				end
			end)

			AimbotTarget = Target
			AimbotTargetPart = TargetPart
			IsAimbotTargetVisible = IsTargetVisible

			local AimPosition = AimbotTargetPart and AimbotTargetPart.Position
			if TargetPart and Aiming.Aimbot_Prediction and AimbotTarget then
				local PredCache = MovementCache[AimbotTarget]
				if PredCache and #PredCache >= 2 then
					local Newest, Previous = PredCache[1], PredCache[2]
					if Newest and Previous and (Newest.Time - Previous.Time) > 0.001 then
						local Vel = (Newest.Position - Previous.Position) / (Newest.Time - Previous.Time)
						AimPosition = AimbotTargetPart.Position + Vel * (2 / 60)
					end
				end
			end

			if TargetPart then
				if Aiming.Aimbot_Type == "Mouse" and not Library.Toggled then
					local Smoothness = Aiming.Aimbot_Smoothness
					local PredScreen = AimPosition ~= AimbotTargetPart.Position and select(1, WorldToViewportPoint(AimPosition)) or TargetScreen
					local DeltaX, DeltaY = PredScreen.X - ScreenCenterX, PredScreen.Y - ScreenCenterY
					if Aiming.Aimbot_SmoothingMode == "Ease-Out" then
						local NormFactor = 1 - (1 - 1 / Smoothness) ^ 3
						DeltaX, DeltaY = DeltaX * NormFactor, DeltaY * NormFactor
					else
						DeltaX, DeltaY = DeltaX / Smoothness, DeltaY / Smoothness
					end
					ns__mousemoverel(DeltaX, DeltaY)
				elseif Aiming.Aimbot_Type == "Camera" then
					local TargetLookVector = (AimPosition - Camera.CFrame.Position).Unit
					local Smoothness = Aiming.Aimbot_Smoothness
					if Smoothness > 1 then
						local Alpha = 1 / Smoothness
						if Aiming.Aimbot_SmoothingMode == "Ease-Out" then
							Alpha = 1 - (1 - Alpha) ^ 3
						end
						TargetLookVector = (Camera.CFrame.LookVector:Lerp(TargetLookVector, Alpha)).Unit
					end

					local ActiveCamera = GetActiveCamera()
					local setLookVector = ActiveCamera.setLookVector
					if setLookVector then
						setLookVector(ActiveCamera, TargetLookVector)
					end
				end
				IsLocking = true
			end
		else
			AimbotTarget = nil
			AimbotTargetPart = nil
			IsAimbotTargetVisible = false
		end

		IsAimbotLocking = IsLocking
	else
		AimbotTarget = nil
		AimbotTargetPart = nil
		IsAimbotLocking = false
		SetProperty(FOVCircle, "Visible", false)
		return SetProperty(TargetTracer, "Visible", false)
	end

	if Aiming.Aimbot_TargetTracer and IsAimbotLocking and AimbotTargetPart then
		local Barrel = GetActiveWeapon()
		Barrel = Barrel and Barrel._barrelPart
		if Barrel then
			local Screen, OnScreen = WorldToViewportPoint(Barrel.Position)
			if OnScreen then
				SetProperty(TargetTracer, "From", Screen)
			else
				SetProperty(TargetTracer, "Visible", false)
			end
		else
			SetProperty(TargetTracer, "From", ScreenCenter)
		end
		local Screen, OnScreen = WorldToViewportPoint(AimbotTargetPart.Position)
		SetProperty(TargetTracer, "To", OnScreen and Screen or ScreenCenter)
		SetProperty(TargetTracer, "Visible", true)
	else
		SetProperty(TargetTracer, "Visible", false)
	end
end

function ESPModule:UpdateGrenades(Now)
	local Grenades = ESPModule.Grenades
	for Index = #Grenades, 1, -1 do
		local Entry = Grenades[Index]
		local Age = Now - Entry.Start
		if Age > Entry.Fuse then
			Entry.Tag:Remove()
			table.remove(Grenades, Index)
		else
			local Nodes, Count = Entry.Nodes, #Entry.Nodes
			local Estimated
			if Age <= Nodes[1].t then
				Estimated = Nodes[1].p
			elseif Age >= Nodes[Count].t then
				Estimated = Nodes[Count].p
			else
				local Segment = 1
				while Segment < Count and Nodes[Segment + 1].t <= Age do
					Segment += 1
				end
				Estimated = CubicNodePosition(Nodes[Segment], Nodes[Segment + 1], Age)
			end
			local Screen, OnScreen = WorldToViewportPoint(Estimated)
			if OnScreen then
				SetProperty(Entry.Tag, "Position", Screen)
				SetProperty(Entry.Tag, "Text", string.format("GRENADE [%.1f]", math.max(0, Entry.Fuse - Age)))
				SetProperty(Entry.Tag, "Visible", true)
			else
				SetProperty(Entry.Tag, "Visible", false)
			end
		end
	end
end

function GrenadeModule:UpdateTrajectory()
	if Visuals.Combat_GrenadeTrajectory and IsSpawned then
		local ActiveWeapon = GetActiveWeapon()
		if ActiveWeapon and ActiveWeapon:getWeaponType() == "Grenade" then
			local WeaponData = ActiveWeapon._weaponData
			if WeaponData then
				local LocalPosition = GetLocalPosition()
				local Velocity = (Camera.CFrame * CFrame.Angles(math.rad(WeaponData.throwangle or 0), 0, 0)).LookVector * (
					WeaponData.throwspeed or 100
				) + (GetLocalCharacter():getRealRootPart().AssemblyLinearVelocity or Vector3.zero)

				local CameraPosition = Camera.CFrame.Position
				local TargetPosition = ActiveWeapon._mainPart
				TargetPosition = TargetPosition and TargetPosition.Position or LocalPosition

				local StartHit = workspace:Raycast(CameraPosition, TargetPosition - CameraPosition, GrenadeRaycastParams)
				local Position = StartHit and (StartHit.Position + StartHit.Normal * 0.01) or TargetPosition

				local Points, Bounces, Impact, Gravity = {Position}, 0, nil, Vector3.new(0, -80, 0)
				local SegmentStart, SegmentVelocity, SegmentTime, LastPosition, RaycastOffset, SegmentAcceleration, LastBounce = Position, Velocity, 0, Position, Vector3.zero, Gravity, false
				local MaxBounces, Elasticity, Friction = Visuals.Combat_GrenadeTrajectoryBounces, ActiveWeapon._bounceElasticity or 0.2, ActiveWeapon._frictionConstant or 0.08
				for _ = 1, 240 do
					SegmentTime += RaycastStep
					local NextPosition = SegmentStart + SegmentVelocity * SegmentTime + 0.5 * SegmentAcceleration * SegmentTime * SegmentTime
					local Hit = workspace:Raycast(LastPosition, NextPosition - LastPosition - 0.05 * RaycastOffset, GrenadeRaycastParams)
					if Hit and Hit.Instance.Name ~= "Window" and Hit.Instance.Name ~= "Col" then
						local Normal, HitPosition = Hit.Normal, Hit.Position
						if Bounces >= MaxBounces then
							Impact = HitPosition
							table.insert(Points, Impact)
							break
						end
						local HitDelta = HitPosition - LastPosition
						local Contact = LastPosition + math.max(0, 1 - 0.001 / HitDelta.Magnitude) * HitDelta + 0.05 * Normal
						table.insert(Points, Contact)
						local ImpactVelocity = SegmentVelocity + Gravity * SegmentTime
						local NormalVelocity = Normal * ImpactVelocity:Dot(Normal)
						local TangentialVelocity = ImpactVelocity - NormalVelocity
						SegmentVelocity = math.max(0, 1 - Friction * (10 * math.max(0, -Normal:Dot(SegmentAcceleration)) * RaycastStep + math.max(0, -(1 + Elasticity) * Normal:Dot(ImpactVelocity))) / TangentialVelocity.Magnitude) * TangentialVelocity - Elasticity * NormalVelocity
						if SegmentVelocity.Magnitude < 1 then
							Impact = Contact
							break
						end
						SegmentStart, SegmentTime, LastPosition, SegmentAcceleration, LastBounce, RaycastOffset = Contact, 0, Contact, LastBounce and Vector3.zero or Gravity, true, 0.2 * Normal
						Bounces += 1
					else
						table.insert(Points, NextPosition)
						LastPosition, LastBounce = NextPosition, false
					end
				end

				local TrajectoryColor = Visuals.Combat_GrenadeTrajectoryColor
				local ImpactColor = Visuals.Combat_GrenadeTrajectoryCustomImpact and Visuals.Combat_GrenadeTrajectoryImpactColor or TrajectoryColor
				local Thickness = Visuals.Combat_GrenadeTrajectoryThickness
				local PointCount = #Points
				local SegmentsNeeded = math.max(0, PointCount - 1)
				while #GrenadeModule.Segments < SegmentsNeeded do
					local Attachment0 = ns__cloneref(Instance.new("Attachment"))
					local Attachment1 = ns__cloneref(Instance.new("Attachment"))
					local Beam = ns__cloneref(Instance.new("Beam"))
					Beam.FaceCamera = true
					Beam.LightEmission = 1
					Beam.Texture = ""
					Beam.Segments = 10
					Attachment0.Parent = Terrain
					Attachment1.Parent = Terrain
					Beam.Attachment0 = Attachment0
					Beam.Attachment1 = Attachment1
					Beam.Parent = Terrain
					table.insert(GrenadeModule.Segments, {Beam = Beam, Attachment0 = Attachment0, Attachment1 = Attachment1})
				end

				for Index = 1, #GrenadeModule.Segments do
					local Segment = GrenadeModule.Segments[Index]
					local Beam = Segment.Beam
					if Index <= SegmentsNeeded then
						Segment.Attachment0.Position = Points[Index]
						Segment.Attachment1.Position = Points[Index + 1]
						Beam.Color = ColorSequence.new(Index == SegmentsNeeded and ImpactColor or TrajectoryColor)
						Beam.Width0 = Thickness * 0.025
						Beam.Width1 = Thickness * 0.025
						Beam.Transparency = NumberSequence.new(0)
					else
						Beam.Transparency = NumberSequence.new(1)
					end
				end

				GrenadeModule.Marker.Color3 = ImpactColor
				GrenadeModule.Marker.CFrame = CFrame.new(Impact or Points[PointCount])
				GrenadeModule.Marker.Visible = true
				return
			end
		end
	end

	for _,Segment in ipairs(GrenadeModule.Segments) do
		Segment.Beam.Transparency = NumberSequence.new(1)
	end

	GrenadeModule.Marker.Visible = false
end

local AutoFireModule = {IsFiring = false, Start = 0}

function AutoFireModule:SetFiring(State)
	self.IsFiring = State
	task.spawn(VirtualInputManager.SendMouseButtonEvent, VirtualInputManager, 0, 0, 0, State, game, 1)
end

function AutoFireModule:CanPenetrate(Weapon)
	if not (Aiming.Aimbot_AutoWall and AimbotTargetPart) then
		return false
	end

	local WeaponData = Weapon._weaponData
	local PenetrationDepth, BulletSpeed = WeaponData.penetrationdepth, WeaponData.bulletspeed
	if not (PenetrationDepth and BulletSpeed) then
		return false
	end

	local Origin = GetLocalPosition()
	local Velocity = GetBulletVelocity(Origin, AimbotTargetPart.Position, BulletSpeed)
	return Velocity and BulletCheck(Origin, AimbotTargetPart.Position, Velocity, BulletAcceleration, PenetrationDepth) or false
end

function AutoFireModule:Update(Now)
	local ActiveWeapon = GetActiveWeapon()
	if not (ActiveWeapon and ActiveWeapon:getWeaponType() == "Firearm" and Aiming.Aimbot_Type == "Silent" and IsAimbotLocking and (
		(Aiming.Aimbot_AutoWall and self:CanPenetrate(ActiveWeapon)) or (not Aiming.Aimbot_AutoWall and IsAimbotTargetVisible)
	)) then
		if self.IsFiring then
			self:SetFiring(false)
		end
		self.Start = 0
		return
	end

	if self.Start == 0 then
		self.Start = Now
	end

	if (Now - self.Start) * 1000 >= Aiming.Aimbot_AutoDelay then
		self:SetFiring(not self.IsFiring)
	end
end

local ViewModelModule = {HiddenModels = {}}

function ViewModelModule:Update()
	local ShouldHide = Visuals.Camera_ThirdPersonView and Visuals.Camera_ThirdPersonHideViewModel
	local NoSleeves, ChamsEnabled = Visuals.Viewmodel_NoSleeves, Visuals.Viewmodel_Chams

	for Model, Parts in next, ModelBaseParts do
		if ShouldHide and Model.Parent == Camera and not self.HiddenModels[Model] then
			self.HiddenModels[Model] = true
			Model.Destroying:Once(function()
				self.HiddenModels[Model] = nil
			end)
			Model.Parent = nil
		end

		if Model.Parent ~= Camera then
			ModelBaseParts[Model] = nil
		else
			local Arm, Targets, ValidTarget = Model:FindFirstChild("Arm"), Visuals.Viewmodel_ChamsTargets, false
			if Arm then
				if Targets.Arms then
					ValidTarget = true
				end
			elseif Targets.Weapon then
				ValidTarget = true
			end

			local Highlight = ModelHighlights[Model]
			if ValidTarget and ChamsEnabled then
				Highlight.Enabled = false
				for _,Part in ipairs(Parts) do
					if not ViewmodelCache[Part] then
						ViewmodelCache[Part] = {Material = Part.Material.Name, Transparency = Part.Transparency, Color = Part.Color}
					end
					local Material = Visuals.Viewmodel_ChamsType
					Part.Material = Enum.Material[Material]
					Part.Color = Visuals.Viewmodel_ChamsColor
					Part.Transparency = (Material ~= "ForceField" and Visuals.Viewmodel_ChamsTranslucent) and 0.5 or 0
				end
			else
				Highlight.Enabled = false
				for _,Part in ipairs(Parts) do
					local Cache = ViewmodelCache[Part]
					if Cache then
						Part.Material = Enum.Material[Cache.Material]
						Part.Transparency = Cache.Transparency
						Part.Color = Cache.Color
						ViewmodelCache[Part] = nil
					end
				end
			end
		end
	end

	if not ShouldHide then
		for Model in next, self.HiddenModels do
			self.HiddenModels[Model] = nil
			Model.Parent = Camera
		end
	end

	for Sleeve, OriginalParent in next, SleevesCache do
		if not OriginalParent or not OriginalParent.Parent then
			SleevesCache[Sleeve] = nil
			continue
		end

		if NoSleeves then
			if Sleeve.Parent ~= nil then
				Sleeve.Parent = nil
			end
		elseif Sleeve.Parent ~= OriginalParent then
			Sleeve.Parent = OriginalParent
		end
	end
end

function ViewModelModule:ApplyOffset(Weapon)
	if not Weapon._mainWeld or not (Visuals.Viewmodel_CustomOffset or Visuals.Viewmodel_CustomRotation or Visuals.Viewmodel_CustomRoll) then
		return
	end

	local AimBlend = 1
	if Weapon.getActiveAimStats then
		AimBlend = 0
		for _,Sight in Weapon:getActiveAimStats() do
			AimBlend += Sight.sightaimspring.p
		end
		AimBlend = math.clamp(1 - AimBlend, 0, 1)
	end

	if AimBlend <= 0 then
		return
	end

	local Custom = CFrame.identity
	if Visuals.Viewmodel_CustomOffset then
		Custom *= CFrame.new(Visuals.Viewmodel_OffsetX, Visuals.Viewmodel_OffsetY, Visuals.Viewmodel_OffsetZ)
	end

	if Visuals.Viewmodel_CustomRotation then
		Custom *= CFrame.Angles(math.rad(Visuals.Viewmodel_RotationX), math.rad(Visuals.Viewmodel_RotationY), math.rad(Visuals.Viewmodel_RotationZ))
	end

	local Applied = CFrame.identity:Lerp(Custom, AimBlend)
	Weapon._mainWeld.C0 *= Applied

	local ArmLeft, ArmRight = Weapon._characterObject:getArmWelds()
	if ArmLeft then
		ArmLeft.C0 *= Applied
	end

	if ArmRight then
		ArmRight.C0 *= Applied
	end

	if Visuals.Viewmodel_CustomRoll then
		local CameraCFrame = Camera.CFrame
		local RootCFrame = Weapon._characterObject:getRootPart().CFrame
		local InRootSpace = RootCFrame:Inverse() * CameraCFrame * CFrame.Angles(0, 0, math.rad(
			Visuals.Viewmodel_Roll
		) * AimBlend) * CameraCFrame:Inverse() * RootCFrame

		Weapon._mainWeld.C0 = InRootSpace * Weapon._mainWeld.C0
		if ArmLeft then
			ArmLeft.C0 = InRootSpace * ArmLeft.C0
		end

		if ArmRight then
			ArmRight.C0 = InRootSpace * ArmRight.C0
		end
	end
end

local ThirdPersonModule = {IsSpawned = false, Object = nil, LastPosition = nil, DeltaTimeAcceleration = 0}

function ThirdPersonModule:Destroy()
	if self.Object then
		FakeReplicationObject:despawn()
		self.Object:Destroy()
		self.Object = nil
		self.LastPosition = nil
	end
end

function ThirdPersonModule:Update(DeltaTime)
	if not (Visuals.Camera_ThirdPersonView and Visuals.Camera_ThirdPersonShowCharacter) then
		self:Destroy()
		return
	end

	local LocalCharacter = GetLocalCharacter()
	local RootPart = LocalCharacter and LocalCharacter:getRealRootPart()
	if not RootPart then
		self:Destroy()
		return
	end

	self.DeltaTimeAcceleration += DeltaTime
	local Position = RootPart.Position
	self.LastPosition = self.LastPosition or Position
	local Velocity = (Position - self.LastPosition) / self.DeltaTimeAcceleration
	self.DeltaTimeAcceleration = 0

	if self.IsSpawned or not self.Object then
		local PlayerData = PlayerDataClientInterface.getPlayerData()
		local ClassData = PlayerData and PlayerData.settings and PlayerData.settings.classdata
		if ClassData then
			FakeReplicationObject._player = LocalPlayer
			FakeReplicationObject:spawn(nil, ClassData[ClassData.curclass])
			self.Object = FakeReplicationObject._thirdPersonObject
			FakeReplicationObject:setActiveIndex(1)
			local WeaponObjects = FakeReplicationObject:getWeaponObjects()
			for Index = 1, 3 do
				if WeaponObjects[Index] then
					self.Object:buildWeapon(Index)
				end
			end
			self.IsSpawned = false
		end
	end

	if not self.Object then
		self.LastPosition = Position
		return
	end

	local Angles = GetActiveCamera():getAngles()
	if Miscellaneous.AntiAim_Enabled and Visuals.Camera_ThirdPersonApplyAntiAimToCharacter then
		Angles = GetAntiAimAngles(Angles)
	end

	FakeReplicationObject._posspring.t = Position
	FakeReplicationObject._posspring.p = Position
	FakeReplicationObject._lookangles.t = Angles
	FakeReplicationObject._lookangles.p = Angles

	local ClockTime, TickTime = os.clock(), tick()
	FakeReplicationObject._smoothReplication:receive(ClockTime, TickTime, {
		t = TickTime, position = Position, velocity = Velocity,
		angles = Angles, barrelAngles = Vector3.zero, breakcount = 0
	}, true)

	FakeReplicationObject._updaterecieved = true
	FakeReplicationObject._receivedPosition = Position
	FakeReplicationObject._receivedFrameTime = NetworkClient.getTime()
	FakeReplicationObject._lastPacketTime = ClockTime
	FakeReplicationObject._lastBarrelAngles = Vector3.zero
	FakeReplicationObject:step(3, true)

	local Weapon = GetActiveWeapon()
	local IsAiming = Weapon and Weapon._aiming or false
	if not Visuals.Camera_ThirdPersonShowCharacterWhileAiming and IsAiming then
		self.Object:setCharacterRender(false)
	else
		self.Object:setCharacterRender(true)
		self.Object.canRenderWeapon = true
		if self.Object._characterModelHash then
			for _,Part in next, self.Object._characterModelHash do
				Part.LocalTransparencyModifier = 0
				Part.Transparency = 0
			end
		end
	end

	self.LastPosition = Position
end

function RageBotModule:Update()
	local Now = os.clock()
	local Weapon = Aiming.RageBot_Enabled and not RoundSystemClient.roundLock and IsSpawned and GetActiveWeapon()
	if Weapon and Weapon:getWeaponType() == "Firearm" and Weapon._magCount and Weapon._spareCount and (Weapon._magCount > 0 or Weapon._spareCount > 0) then
		if Now < self.NextShot then
			return
		end

		local WeaponData = Weapon._weaponData
		local PenetrationDepth = WeaponData.penetrationdepth
		if not PenetrationDepth then
			return
		end

		local BulletSpeed = WeaponData.bulletspeed
		if not BulletSpeed then
			return
		end

		local FireRateTable = WeaponData.firerate
		local ShotInterval = 60 / (WeaponData.variablefirerate and FireRateTable[Weapon._firemodeIndex] or FireRateTable)
		local Origin, SortedEntries, SortedDistances, SortedHealth = GetLocalPosition(), {}, {}, {}
		local PenetrationDetection = Aiming.RageBot_WallPenetrationDetection
		OperateOnAllEntries(function(Player, Entry)
			if not Entry._isEnemy or not Entry._alive or not Entry._velspring.t then
				return
			end

			local Character = GetCharacter(Entry)
			if not Character then
				return
			end

			if not PenetrationDetection and Character.Head then
				local HeadPosition = Character.Head.Position
				if not TransparentRaycast(Origin, HeadPosition - Origin, AimingRaycastParams) then
					local Torso = Character.Torso
					if not Torso or not TransparentRaycast(Origin, Torso.Position - Origin, AimingRaycastParams) then
						return
					end
				end
			end

			local Index = #SortedEntries + 1
			SortedEntries[Index] = Entry

			local HeadPosition = Character.Head.Position
			local DeltaX, DeltaY, DeltaZ = HeadPosition.X - Origin.X, HeadPosition.Y - Origin.Y, HeadPosition.Z - Origin.Z
			SortedDistances[Index] = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ)
			SortedHealth[Index] = Entry:getHealth()
		end)

		local EntryCount = #SortedEntries
		if EntryCount == 0 then
			return
		end

		local IndexTable = table.create(EntryCount)
		for Index = 1, EntryCount do
			IndexTable[Index] = Index
		end

		table.sort(IndexTable, function(IndexA, IndexB)
			local HealthA, HealthB = SortedHealth[IndexA], SortedHealth[IndexB]
			if HealthA == HealthB then
				return SortedDistances[IndexA] < SortedDistances[IndexB]
			end
			return HealthA < HealthB
		end)

		local SortedTargets = table.create(EntryCount)
		for Index = 1, EntryCount do
			SortedTargets[Index] = SortedEntries[IndexTable[Index]]
		end
		SortedEntries = SortedTargets

		local FireOrigins = self:GetFireOrigins(Origin)
		local ShouldCreateBulletTracer = Visuals.Combat_BulletTracers
		local Targets = table.create(6)
		local IsPart = table.create(6)
		local ScanCache = {}

		for EntryIndex = 1, #SortedEntries do
			local Entry = SortedEntries[EntryIndex]
			local Character = Entry._thirdPersonObject._characterModelHash
			local TargetCount = self:GetTargets(Entry, Targets, IsPart)

			if Aiming.RageBot_Prediction then
				local PredCache = MovementCache[Entry._player]
				if PredCache and #PredCache >= 2 then
					local Newest, Previous = PredCache[1], PredCache[2]
					if Newest and Previous and (Newest.Time - Previous.Time) > 0.001 then
						local Vel = (Newest.Position - Previous.Position) / (Newest.Time - Previous.Time)
						local Offset = Vel * (2 / 60)
						for i = 1, TargetCount do
							if IsPart[i] then
								Targets[i] = Targets[i].Position + Offset
								IsPart[i] = false
							else
								Targets[i] = Targets[i] + Offset
							end
						end
					end
				end
			end

			local NewOrigin, NewTarget, Velocity, HitPart = self:SolveEntry(Targets, TargetCount, IsPart, FireOrigins, BulletSpeed, PenetrationDetection, PenetrationDepth, ScanCache)
			local HitPartName = self:GetHitPartName(Character, HitPart)
			if NewOrigin then
				if os.clock() < self.NextShot then
					break
				end

				local MagCount = Weapon._magCount
				if MagCount < 1 then
					local ReloadCount = WeaponData.magsize
					if ReloadCount > 0 and Weapon._spareCount > 0 then
						NetworkClientSend(NetworkClient, "reload")
					end

					if ReloadCount < Weapon._spareCount then
						Weapon._magCount += ReloadCount
						Weapon._spareCount -= ReloadCount
					else
						Weapon._magCount += Weapon._spareCount
						Weapon._spareCount = 0
					end
				end

				if Weapon._magCount < 1 then
					break
				end

				local IsSinglePellet = false
				local PelletCount =  WeaponData.pelletcount
				if not PelletCount then
					PelletCount = 1
					IsSinglePellet = true
				end

				local Direction, Bullets = Velocity.Unit, table.create(PelletCount)

				if IsSinglePellet then
					Bullets[1] = {Direction, TicketAddition}
					TicketAddition += 1
				else
					for Index = 1, PelletCount do
						Bullets[Index] = {Direction, TicketAddition}
						TicketAddition += 1
					end
				end

				local UniqueId = Weapon.uniqueId
				local CurrentTime = NetworkClient.getTime()
				NetworkClientSend(NetworkClient, "newbullets", UniqueId, {
					camerapos = Origin,
					firepos = NewOrigin,
					velocity = Velocity,
					bullets = Bullets,
				}, CurrentTime)

				local Player = Entry._player
				if IsSinglePellet then
					NetworkClientSend(NetworkClient, "bullethit", UniqueId, Player, NewTarget, HitPartName or "Head", Bullets[1][2], CurrentTime)
				else
					for Index = 1, PelletCount do
						NetworkClientSend(NetworkClient, "bullethit", UniqueId, Player, NewTarget, HitPartName or "Head", Bullets[Index][2], CurrentTime)
					end
				end

				local Barrel = Weapon._barrelPart
				MuzzleFlash(Barrel, WeaponData.hideflash, 0.9)

				local WeaponType = WeaponData.type
				if WeaponType == "SNIPER" then
					PlayGameSound("metalshell", 0.1)
				elseif WeaponType == "SHOTGUN" then
					PlayGameSound("shotWeaponshell", 0.2)
				elseif WeaponType == "REVOLVER" and not WeaponData.caselessammo then
					PlayGameSound("metalshell", 0.15, 0.8)
				end

				if not Weapon._aiming then
					FireImpulse(WeaponData.crossexpansion)
				end

				if WeaponData.sniperbass then
					PlayGameSound("1PsniperBass", 0.75)
					PlayGameSound("1PsniperEcho", 1)
				end

				local ShootSound = Miscellaneous.SoundOverride_ShootSound
				if ShootSound == "None" then
					PlaySoundId(WeaponData.firesoundid, 2, WeaponData.firevolume, WeaponData.firepitch, Barrel, nil, 0, 0.05)
				else
					PlaySoundId(CustomSounds[ShootSound], 2, WeaponData.firevolume, WeaponData.firepitch, Barrel, nil, 0, 0.05)
				end

				if ShouldCreateBulletTracer then
					CreateBulletTracer(NewOrigin, Direction * 1500)
				end

				Weapon._magCount -= 1
				self.NextShot = os.clock() + ShotInterval

				if not Aiming.RageBot_MultiTarget then
					break
				end
			end
		end
	end
end

for Index, Table in ipairs({FirearmObject, GrenadeObject, MeleeObject}) do
	ns__hookfunction(Table, "step", function(Original, self, ...)
		Original(self, ...)
		ViewModelModule:ApplyOffset(self)
	end)

	ns__hookfunction(Table, "getAnimLength", function(Original, self, Name, ...)
		if type(Name) == "string" and string.find(string.lower(Name), "equip") and Miscellaneous.WeaponMods_InstantEquip then
			return 0
		end
		return Original(self, Name, ...)
	end)

	if Index > 1 then
		ns__hookfunction(Table, "walkSway", function(Original, self, ...)
			if Miscellaneous.WeaponMods_NoWalkSway then
				return CFrame.identity
			end
			return Original(self, ...)
		end)
	end
end

local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
if RemoteEvent then
	RemoteEvent.OnClientEvent:Connect(function(Packet, ...)
		if Packet == "startvotekick" then
			if (...) == LocalPlayer.Name and Miscellaneous.Extras_HopOnVotekick then
				game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
			end
		end

		if Packet == "newgrenade" and Visuals.ESPVisuals_GrenadeTags then
			local Nodes, Fuse = select(3, ...), select(5, ...)
			if Nodes[1] then
				table.insert(ESPModule.Grenades, {
					Nodes = Nodes,
					Fuse = Fuse,
					Start = os.clock(),
					Tag = CreateDrawing("Text", {Visible = false, Size = Visuals.ESPVisuals_TagSize, Outline = true, Center = true, Color = Visuals.ESPVisuals_GrenadeTagColor}),
				})
			end
			return
		end

		if Packet == "bulletHitConfirm" or Packet == "meleeHitConfirm" or Packet == "grenadeHitConfirm" then
			if (...) == LocalPlayer then
				return
			end

			local Position = select(3, ...)
			if Miscellaneous.HitLogs_Enabled then
				local Text, Damage = {"Hit " .. (...) .Name}, math.floor(select(4, ...))
				table.insert(Text, "in the " .. select(2, ...))
				if Miscellaneous.HitLogs_ShowDamage then
					table.insert(Text, "for " .. tostring(math.floor(Damage)) .. " health")
				end

				if Miscellaneous.HitLogs_ShowDistance then
					table.insert(Text, "from " .. math.floor((GetLocalPosition() - Position).Magnitude) .. "m away")
				end

				if Damage > 99 then
					table.insert(Text, "[INSTANT KILL]")
				end

				Library:Notify(table.concat(Text, " "), 3)
			end

			if Visuals.Combat_HitMarkerEnabled then
				HitMarkerModule:Spawn(Position)
			end
		elseif Packet == "died" then
			local Attacker = Aiming.Aimbot_DeathNotification and (...).victim == AimbotTarget and (...).attacker
			if Attacker then
				Library:Notify(Attacker == LocalPlayer and ("You eliminated " .. (...).victim.Name) or ("Target was eliminated by " .. Attacker.Name), 3)
			end
		end
	end)
end

RunService.PreRender:Connect(function()
	CanSeeFrameCounter += 1
	local PreviousFrame = CanSeeFrameCounter - 1
	for Part, Entry in next, CanSeeCache do
		if Entry[2] ~= PreviousFrame then
			table.insert(CanSeeCachePool, Entry)
			CanSeeCache[Part] = nil
		end
	end

	if Visuals.Lighting_Flashlight and IsSpawned then
		FlashlightPart.CFrame = Camera.CFrame
		SpotLight.Enabled = true
		SpotLight.Color = Visuals.Lighting_FlashlightColor
		SpotLight.Brightness = Visuals.Lighting_FlashlightBrightness
		SpotLight.Range = Visuals.Lighting_FlashlightRange
		SpotLight.Angle = Visuals.Lighting_FlashlightAngle
	else
		SpotLight.Enabled = false
	end
	ViewModelModule:Update()

	local Now, LocalHeadPosition = os.clock(), GetLocalPosition()
	HitMarkerModule:Update(Now)
	BulletAcceleration, BulletLifeTime = PublicSettings.bulletAcceleration, PublicSettings.bulletLifeTime
	UpdateAimbot(LocalHeadPosition)

	if Visuals.ESPVisuals_MasterEnabled then
		ESPModule:Update(LocalHeadPosition)
	else
		for Player in next, ESPModule.Objects do
			ESPModule:Clear(Player)
		end
	end

	if Visuals.ESPVisuals_GrenadeTags then
		ESPModule:UpdateGrenades(Now)
	end

	if Aiming.Aimbot_AutoFire then
		AutoFireModule:Update(Now)
	end
end)

RunService.Heartbeat:Connect(function(DeltaTime)
	BulletTracerModule:Update()
	GrenadeModule:UpdateTrajectory()

	local RadarHack = Visuals.ESPVisuals_MasterEnabled and Visuals.Combat_RadarHack
	OperateOnAllEntries(function(Player, Entry)
		if not Entry._isEnemy or not Entry._alive or not Entry._velspring.t then
			if MovementCache[Player] then
				MovementCache[Player] = nil
			end
			return
		end

		local Character = GetCharacter(Entry)
		if not Character then
			if MovementCache[Player] then
				MovementCache[Player] = nil
			end
			return
		end

		local Status = RadarHack and GetPlayerStatusEntry(Player)
		if Status then
			Status.isSpotted = true
		end

		local Cache = MovementCache[Player]
		if not Cache then
			Cache = {}
			MovementCache[Player] = Cache
		end

		for Index = math.min(#Cache, 14), 1, -1 do
			Cache[Index + 1] = Cache[Index]
		end

		Cache[1] = {Position = Character.Torso.Position, Time = os.clock()}
	end)

	if LocalHumanoid and Miscellaneous.Movement_BunnyHop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		LocalHumanoid.Jump = true
	end

	if Miscellaneous.Movement_NoSlideCooldown then
		local LocalCharacter = GetLocalCharacter()
		if LocalCharacter then
			LocalCharacter.dived = false
		end
	end

	RageBotModule:Update()
	ThirdPersonModule:Update(DeltaTime)
	KnifeAuraModule:Update()
end)

local repupdate_LastTime, repupdate_ReverseTime
NetworkClient.send = function(self, Packet, ...)
	if Packet == "flaguser" or Packet == "debug" or Packet == "logmessage" then
		if not Settings.Debug_PassthroughACPackets then
			return
		end
	elseif Packet == "repupdate" then
		local Position, Angles, BarrelAngles, Time = ...
		if Miscellaneous.Movement_Speed or Miscellaneous.Movement_Fly or Miscellaneous.Movement_BunnyHop then
			if not repupdate_ReverseTime then
				repupdate_LastTime = Time
			end

			if (Time - repupdate_LastTime) > RaycastStep then
				repupdate_ReverseTime = false
				repupdate_LastTime = Time
			end

			repupdate_ReverseTime = not repupdate_ReverseTime
			Time = repupdate_LastTime
		end

		if Angles and Miscellaneous.AntiAim_Enabled then
			Angles = GetAntiAimAngles(Angles)
		end

		return NetworkClientSend(self, Packet, Position, Angles, BarrelAngles, Time)
	elseif Packet == "despawn" then
		ThirdPersonModule.IsSpawned, IsSpawned = false, false
		return NetworkClientSend(self, Packet, ...)
	elseif Packet == "spawn" then
		GlobalTicketCounter, TicketAddition, IsSpawned, ThirdPersonModule.IsSpawned = 0, 0, true, true
		return NetworkClientSend(self, Packet, ...)
	end

	if ThirdPersonModule.Object then
		if Packet == "equip" then
			local Slot = (...)
			if FakeReplicationObject then
				FakeReplicationObject:setActiveIndex(Slot)
			end

			if Slot ~= 3 then
				ThirdPersonModule.Object:equip(Slot)
			else
				ThirdPersonModule.Object:equipMelee()
			end

			return NetworkClientSend(self, Packet, ...)
		elseif Packet == "stab" then
			ThirdPersonModule.Object:stab()
			return NetworkClientSend(self, Packet, ...)
		elseif Packet == "aim" then
			ThirdPersonModule.Object:setAim(...)
			return NetworkClientSend(self, Packet, ...)
		elseif Packet == "sprint" then
			ThirdPersonModule.Object:setSprint(...)
			return NetworkClientSend(self, Packet, ...)
		elseif Packet == "stance" then
			ThirdPersonModule.Object:setStance(...)
			return NetworkClientSend(self, Packet, ...)
		end
	end

	if Packet == "newbullets" then
		local UniqueId, BulletData, Time = ...
		local Bullets = BulletData.bullets
		GlobalTicketCounter += #Bullets

		for Index = 1, #Bullets do
			Bullets[Index][2] += TicketAddition
		end

		if Aiming.Aimbot_Enabled and Aiming.Aimbot_Type == "Silent" then
			local Now = os.clock()
			if LastSilent.Target and (Now - LastSilent.Frame < 0.1) then
				local Direction = LastSilent.Velocity.Unit
				for Index = 1, #Bullets do
					Bullets[Index][1] = Direction
				end
				LastSilent.Target = nil
				LastSilent.Velocity = nil
			else
				local Weapon = GetActiveWeapon()
				local ProjectileSpeed = BulletData.velocity and (
					Weapon and Weapon._weaponData.bulletspeed or BulletData.velocity.Magnitude
				) or 0
				local Direction, Target, Entry, ShotTime = SilentAimbotModule:Solve(BulletData.firepos, PublicSettings.bulletAcceleration, ProjectileSpeed)
				if Direction and Target and Entry then
					for Index = 1, #Bullets do
						Bullets[Index][1] = Direction
					end
					LastSilent.Player = Entry._player
					LastSilent.Time = ShotTime
				end
			end
		end

		if ThirdPersonModule.Object then
			ThirdPersonModule.Object:kickWeapon(false, nil, 0, 0)
		end

		return NetworkClientSend(self, Packet, UniqueId, BulletData, Time)
	elseif Packet == "bullethit" then
		local UniqueId, Player, Position, PartName, Ticket, Time = ...
		Ticket += TicketAddition

		if TicketCache[Ticket] then
			return
		end

		TicketCache[Ticket] = true
		return NetworkClientSend(self, Packet, UniqueId, Player, Position, PartName, Ticket, Time)
	elseif Packet == "newgrenade" then
		local Position, Velocity, Time, Fuse = ...

		if Visuals.Combat_CustomGrenadeFuse then
			Fuse = Visuals.Combat_FuseAmount
		end

		if Aiming.Aimbot_GrenadeRedirect and IsSpawned and AimbotTargetPart then
			local _Velocity, _Fuse = GrenadeModule:GetVelocity(AimbotTargetPart.Position, Position)
			if _Velocity then
				Velocity = _Velocity
				if _Fuse then
					Fuse = _Fuse
				end
			end
		end

		if Miscellaneous.WeaponMods_UncookableGrenade and Fuse <= 0 then
			Fuse = GetActiveWeapon():getWeaponStat("fusetime") or 5
		end

		if Visuals.Combat_CustomGrenadeFuse and Visuals.Combat_FuseOnImpact and Velocity.Magnitude > 0.01 then
			local ImpactFuse = GrenadeModule:ImpactFuse(Position, Velocity)
			if ImpactFuse then
				Fuse = ImpactFuse
			end
		end

		return NetworkClientSend(self, Packet, Position, Velocity, Time, Fuse)
	elseif (Packet == "falldamage" and Miscellaneous.Movement_NoFallDamage) or (Packet == "changeCamo" and Miscellaneous.ClientSessionUnlocks_CamosUnlocked) or (Packet == "changedweapon" and (...) == "Knife" and Miscellaneous.ClientSessionUnlocks_KnivesUnlocked) or (Packet == "changeAttachment" and Miscellaneous.ClientSessionUnlocks_AttachmentsUnlocked) then
		return
	end

	return NetworkClientSend(self, Packet, ...)
end

LoadAutoLoad()
Library:Toggle()

pcall(function()
	local Request = not isfile("NikoletoScripts/PhantomWare/Cache/Invite.nscache") and (httprequest or http_request or request)
	if Request then
		if pcall(Request, {
			Url = "http://127.0.0.1:6463/rpc?v=1",  Method = "POST", Headers = {["Content-Type"] = "application/json", Origin = "https://discord.com"},
			Body = HttpService:JSONEncode({cmd = "INVITE_BROWSER", nonce = HttpService:GenerateGUID(false), args = {code = "DwRT2nH93D"}})
		}) then
			writefile("NikoletoScripts/PhantomWare/Cache/Invite.nscache", "DwRT2nH93D")
		end
	end
end)
