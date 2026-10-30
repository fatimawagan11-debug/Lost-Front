--[[
	Constipated Hub | The Lost Front
	Orion · Aimbot · Silent Aim · Triggerbot · ESP (team green / enemy red) · Wall check
]]

repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local ok, OrionLib = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()
end)
if not ok or not OrionLib then
	warn("[Constipated] Orion failed")
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.__ConstipatedLF = (GENV.__ConstipatedLF or 0) + 1
local GEN = GENV.__ConstipatedLF
local function alive()
	return GENV.__ConstipatedLF == GEN
end

-- ===================== FLAGS =====================
local F = {
	Aimbot = false,
	AimAlways = true,
	AimFOV = 180,
	AimSmooth = 0.18,
	AimPart = "Head",
	TeamCheck = true,
	WallCheck = true,
	Prediction = true,
	PredictAmount = 0.14,

	SilentAim = false,
	SilentHitChance = 100,

	Triggerbot = false,
	TriggerDelay = 0.06,
	TriggerFOV = 45,

	ESP = true,
	EspName = true,
	EspDist = true,
	EspHP = true,
	EspChams = true,
	EspShowTeam = true, -- teammates shown in GREEN
	EspWallFade = true, -- dim ESP when behind wall

	NoFog = true,
	Fullbright = false,
	NoTrees = false,

	WalkSpeed = false,
	WalkSpeedVal = 24,
	InfJump = false,
	Noclip = false,
	Fly = false,
	FlySpeed = 50,
}

-- ===================== REMOTES =====================
local net = ReplicatedStorage:FindFirstChild("network")
local function netRemote(name)
	return net and net:FindFirstChild(name)
end

local Remotes = {
	bullet = netRemote("bullet") or netRemote("bullet2") or netRemote("buIIet") or netRemote("buIIet2"),
	projectile = netRemote("projectile"),
	look = netRemote("characterLookvector"),
	heal = netRemote("heal"),
	throw = netRemote("throw"),
	collect = net and net:FindFirstChild("pickup") and net.pickup:FindFirstChild("collect"),
}

-- ===================== HELPERS =====================
local function char()
	return LP.Character
end
local function hum()
	local c = char()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function hrp()
	local c = char()
	return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local function isAlive(plr)
	local c = plr.Character
	if not c then return false end
	local h = c:FindFirstChildOfClass("Humanoid")
	local r = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
	return h and r and h.Health > 0 and h:GetState() ~= Enum.HumanoidStateType.Dead
end

-- robust team check
local function getTeamId(plr)
	if plr.Team then
		return plr.Team.Name
	end
	if plr.TeamColor then
		return tostring(plr.TeamColor)
	end
	local c = plr.Character
	if c then
		for _, name in ipairs({ "Team", "Faction", "Side", "Army", "Force" }) do
			local v = c:FindFirstChild(name)
			if v then
				if v:IsA("StringValue") or v:IsA("IntValue") or v:IsA("NumberValue") then
					return tostring(v.Value)
				end
				if v:IsA("ObjectValue") and v.Value then
					return v.Value.Name
				end
				return v.Name
			end
		end
		-- attribute
		local attr = c:GetAttribute("Team") or c:GetAttribute("Faction") or c:GetAttribute("Side")
		if attr ~= nil then return tostring(attr) end
	end
	return nil
end

local function isTeammate(plr)
	if plr == LP then return true end
	local a, b = getTeamId(LP), getTeamId(plr)
	if a and b and a == b then return true end
	if LP.Team and plr.Team and LP.Team == plr.Team then return true end
	return false
end

local function getPart(plr)
	local c = plr.Character
	if not c then return nil end
	if F.AimPart == "Head" then
		return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
	elseif F.AimPart == "UpperTorso" then
		return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
	end
	return c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
end

local function isVisible(part)
	if not part then return false end
	local origin = Camera.CFrame.Position
	local target = part.Position
	local dir = target - origin
	local dist = dir.Magnitude
	if dist < 1 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { char(), Camera }
	-- exclude all character models so we only care about world geometry
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(exclude, p.Character) end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, dir.Unit * dist, params)
	-- visible if nothing hit OR hit is very close to target (edge tolerance)
	if not hit then return true end
	return (hit.Position - target).Magnitude < 4
end

local function screenCenter()
	local vs = Camera.ViewportSize
	return Vector2.new(vs.X / 2, vs.Y / 2)
end

local function getTarget(maxFOV, forCombat)
	local center = screenCenter()
	local best, bestDist = nil, maxFOV
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LP then continue end
		if not isAlive(plr) then continue end
		if forCombat and F.TeamCheck and isTeammate(plr) then continue end
		local part = getPart(plr)
		if not part then continue end
		if forCombat and F.WallCheck and not isVisible(part) then continue end
		local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or pos.Z < 0 then continue end
		local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = { part = part, plr = plr, dist = dist }
		end
	end
	return best
end

-- ===================== AIMBOT =====================
local function aimStep()
	if not F.Aimbot then return end
	if not F.AimAlways then
		if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			return
		end
	end
	local t = getTarget(F.AimFOV, true)
	if not t then return end
	local aimPos = t.part.Position
	if F.Prediction then
		local root = t.plr.Character and (t.plr.Character:FindFirstChild("HumanoidRootPart") or t.plr.Character.PrimaryPart)
		if root then
			aimPos = aimPos + root.AssemblyLinearVelocity * F.PredictAmount
		end
	end
	local cf = CFrame.lookAt(Camera.CFrame.Position, aimPos)
	if F.AimSmooth > 0 then
		Camera.CFrame = Camera.CFrame:Lerp(cf, math.clamp(1 - F.AimSmooth, 0.08, 1))
	else
		Camera.CFrame = cf
	end
end

-- ===================== SILENT AIM (hook bullet remotes) =====================
local silentTarget = nil
local function updateSilentTarget()
	if not F.SilentAim then
		silentTarget = nil
		return
	end
	local t = getTarget(F.AimFOV, true)
	silentTarget = t and t.part or nil
end

local function tryHook(remote)
	if not remote then return end
	local mt = getrawmetatable and getrawmetatable(game)
	if not mt then return end
	-- simple namecall hook if available
	if typeof(hookmetamethod) == "function" then
		local old
		old = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod and getnamecallmethod() or ""
			local args = { ... }
			if self == remote and (method == "FireServer" or method == "fireServer") then
				if F.SilentAim and silentTarget and math.random(1, 100) <= F.SilentHitChance then
					-- rewrite any Vector3 arg toward head
					for i, a in ipairs(args) do
						if typeof(a) == "Vector3" then
							args[i] = silentTarget.Position
						elseif typeof(a) == "CFrame" then
							args[i] = CFrame.new(a.Position, silentTarget.Position)
						end
					end
					return old(self, table.unpack(args))
				end
			end
			return old(self, ...)
		end)
	end
end

task.spawn(function()
	task.wait(1)
	tryHook(Remotes.bullet)
	tryHook(Remotes.projectile)
	-- also try alternate names
	if net then
		for _, n in ipairs({ "bullet", "bullet2", "buIIet", "buIIet2", "projectile" }) do
			local r = net:FindFirstChild(n)
			if r then tryHook(r) end
		end
	end
end)

-- ===================== TRIGGERBOT =====================
local lastTrigger = 0
local function triggerStep()
	if not F.Triggerbot then return end
	if (os.clock() - lastTrigger) < F.TriggerDelay then return end
	local t = getTarget(F.TriggerFOV, true)
	if not t then return end
	lastTrigger = os.clock()
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.025)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
	pcall(function()
		local tool = char() and char():FindFirstChildOfClass("Tool")
		if tool then tool:Activate() end
	end)
end

-- ===================== ESP =====================
local espFolder = Instance.new("Folder")
espFolder.Name = "CSW_LF_ESP"
espFolder.Parent = Workspace
local espMap = {}

local COL_ENEMY = Color3.fromRGB(255, 55, 55)
local COL_TEAM = Color3.fromRGB(40, 220, 90)
local COL_WALL = Color3.fromRGB(160, 160, 160)

local function clearESP(plr)
	local t = espMap[plr]
	if not t then return end
	pcall(function()
		if t.bb then t.bb:Destroy() end
		if t.hl then t.hl:Destroy() end
	end)
	espMap[plr] = nil
end

local function ensureESP(plr)
	if espMap[plr] and espMap[plr].bb and espMap[plr].bb.Parent then
		return espMap[plr]
	end
	clearESP(plr)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 130, 0, 52)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Parent = espFolder
	local nameL = Instance.new("TextLabel")
	nameL.BackgroundTransparency = 1
	nameL.Size = UDim2.new(1, 0, 0, 16)
	nameL.Font = Enum.Font.GothamBold
	nameL.TextSize = 13
	nameL.TextStrokeTransparency = 0.3
	nameL.Text = plr.DisplayName or plr.Name
	nameL.Parent = bb
	local hpL = Instance.new("TextLabel")
	hpL.BackgroundTransparency = 1
	hpL.Size = UDim2.new(1, 0, 0, 14)
	hpL.Position = UDim2.new(0, 0, 0, 16)
	hpL.Font = Enum.Font.Gotham
	hpL.TextSize = 12
	hpL.TextStrokeTransparency = 0.45
	hpL.Text = ""
	hpL.Parent = bb
	local distL = Instance.new("TextLabel")
	distL.BackgroundTransparency = 1
	distL.Size = UDim2.new(1, 0, 0, 14)
	distL.Position = UDim2.new(0, 0, 0, 30)
	distL.Font = Enum.Font.Gotham
	distL.TextSize = 11
	distL.TextStrokeTransparency = 0.5
	distL.Text = ""
	distL.Parent = bb
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = false
	hl.Parent = espFolder
	espMap[plr] = { bb = bb, name = nameL, hp = hpL, dist = distL, hl = hl }
	return espMap[plr]
end

Players.PlayerRemoving:Connect(clearESP)

-- ===================== WORLD =====================
local fogBackup = {
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ClockTime = Lighting.ClockTime,
}

local function applyNoFog(on)
	if on then
		Lighting.FogEnd = 1e6
		Lighting.FogStart = 1e6
	else
		Lighting.FogEnd = fogBackup.FogEnd
		Lighting.FogStart = fogBackup.FogStart
	end
end

local function applyFullbright(on)
	if on then
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.ClockTime = 14
	else
		Lighting.Brightness = fogBackup.Brightness
		Lighting.Ambient = fogBackup.Ambient
		Lighting.OutdoorAmbient = fogBackup.OutdoorAmbient
		Lighting.ClockTime = fogBackup.ClockTime
	end
end

local hiddenTrees = {}
local function applyNoTrees(on)
	if on then
		for _, obj in ipairs(Workspace:GetDescendants()) do
			local n = string.lower(obj.Name)
			if (n:find("tree") or n:find("leaf") or n:find("bush") or n:find("grass") or n:find("foliage")) then
				if obj:IsA("BasePart") then
					hiddenTrees[obj] = obj.Transparency
					obj.Transparency = 1
					obj.CanCollide = false
				elseif obj:IsA("Model") then
					for _, p in ipairs(obj:GetDescendants()) do
						if p:IsA("BasePart") then
							hiddenTrees[p] = p.Transparency
							p.Transparency = 1
							p.CanCollide = false
						end
					end
				end
			end
		end
	else
		for p, t in pairs(hiddenTrees) do
			if p and p.Parent then p.Transparency = t end
		end
		hiddenTrees = {}
	end
end

-- ===================== MOVEMENT =====================
local flyBV, flyBG
local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
end
local function startFly()
	stopFly()
	local root = hrp()
	if not root then return end
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	flyBG.P = 1e4
	flyBG.Parent = root
end

local noclipConn
local function setNoclip(on)
	if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	if not on then return end
	noclipConn = RunService.Stepped:Connect(function()
		if not F.Noclip or not alive() then return end
		local c = char()
		if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Space and F.InfJump then
		local h = hum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

local fovCircle
pcall(function()
	fovCircle = Drawing.new("Circle")
	fovCircle.Thickness = 1.5
	fovCircle.NumSides = 64
	fovCircle.Filled = false
	fovCircle.Color = Color3.fromRGB(255, 90, 90)
	fovCircle.Transparency = 0.65
	fovCircle.Visible = false
end)

-- ===================== LOOPS =====================
RunService.RenderStepped:Connect(function()
	if not alive() then return end
	updateSilentTarget()
	aimStep()
	triggerStep()

	if fovCircle then
		local show = F.Aimbot or F.SilentAim
		fovCircle.Visible = show
		if show then
			fovCircle.Position = screenCenter()
			fovCircle.Radius = F.AimFOV
		end
	end

	if F.WalkSpeed then
		local h = hum()
		if h then h.WalkSpeed = F.WalkSpeedVal end
	end

	if F.Fly then
		local root = hrp()
		if root then
			if not flyBV then startFly() end
			local cam = Camera.CFrame
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
			if move.Magnitude > 0 then move = move.Unit * F.FlySpeed end
			flyBV.Velocity = move
			flyBG.CFrame = cam
		end
	else
		stopFly()
	end
end)

RunService.Heartbeat:Connect(function()
	if not alive() then return end
	if not F.ESP then
		for p in pairs(espMap) do clearESP(p) end
		return
	end
	local me = hrp()
	local seen = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LP then continue end
		if not isAlive(plr) then clearESP(plr) continue end
		local teammate = isTeammate(plr)
		if teammate and not F.EspShowTeam then
			clearESP(plr)
			continue
		end
		local rh = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character.PrimaryPart
		local hd = plr.Character:FindFirstChild("Head")
		local h = plr.Character:FindFirstChildOfClass("Humanoid")
		if not rh then clearESP(plr) continue end

		local visible = isVisible(hd or rh)
		-- if wall check on ESP and fully hidden, still show but faded when EspWallFade
		seen[plr] = true
		local t = ensureESP(plr)
		t.bb.Adornee = hd or rh

		local col = teammate and COL_TEAM or COL_ENEMY
		if F.EspWallFade and not visible then
			col = COL_WALL
		end

		t.name.TextColor3 = col
		t.name.Text = (teammate and "[TEAM] " or "") .. (plr.DisplayName or plr.Name)
		t.name.Visible = F.EspName

		if F.EspHP and h then
			local pct = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
			t.hp.Text = math.floor(h.Health) .. " HP"
			t.hp.TextColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 40)
			t.hp.Visible = true
		else
			t.hp.Visible = false
		end

		if F.EspDist and me then
			local d = (rh.Position - me.Position).Magnitude
			t.dist.Text = math.floor(d) .. "m" .. (visible and "" or " (wall)")
			t.dist.Visible = true
		else
			t.dist.Visible = false
		end

		if F.EspChams then
			t.hl.Adornee = plr.Character
			t.hl.FillColor = col
			t.hl.OutlineColor = Color3.new(1, 1, 1)
			t.hl.Enabled = true
		else
			t.hl.Enabled = false
		end
	end
	for p in pairs(espMap) do
		if not seen[p] then clearESP(p) end
	end
end)

applyNoFog(F.NoFog)

-- ===================== UI =====================
local Window = OrionLib:MakeWindow({
	Name = "Constipated Hub | The Lost Front",
	HidePremium = true,
	SaveConfig = false,
	IntroEnabled = false,
})

local TabAim = Window:MakeTab({ Name = "Combat", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabESP = Window:MakeTab({ Name = "ESP", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabWorld = Window:MakeTab({ Name = "World", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabMisc = Window:MakeTab({ Name = "Misc", Icon = "rbxassetid://4483345998", PremiumOnly = false })

TabAim:AddToggle({ Name = "Aimbot (center FOV)", Default = false, Callback = function(v) F.Aimbot = v end })
TabAim:AddToggle({ Name = "Silent Aim (bullet hook)", Default = false, Callback = function(v) F.SilentAim = v end })
TabAim:AddToggle({ Name = "Always On (mobile)", Default = true, Callback = function(v) F.AimAlways = v end })
TabAim:AddSlider({ Name = "Aim FOV", Min = 40, Max = 400, Default = 180, Increment = 5, Callback = function(v) F.AimFOV = v end })
TabAim:AddSlider({ Name = "Smoothness (0=snap)", Min = 0, Max = 0.9, Default = 0.18, Increment = 0.02, Callback = function(v) F.AimSmooth = v end })
TabAim:AddDropdown({
	Name = "Aim Part",
	Default = "Head",
	Options = { "Head", "HumanoidRootPart", "UpperTorso" },
	Callback = function(v) F.AimPart = v end,
})
TabAim:AddToggle({ Name = "Team Check", Default = true, Callback = function(v) F.TeamCheck = v end })
TabAim:AddToggle({ Name = "Wall Check", Default = true, Callback = function(v) F.WallCheck = v end })
TabAim:AddToggle({ Name = "Prediction", Default = true, Callback = function(v) F.Prediction = v end })
TabAim:AddToggle({ Name = "Triggerbot", Default = false, Callback = function(v) F.Triggerbot = v end })
TabAim:AddSlider({ Name = "Trigger FOV", Min = 10, Max = 120, Default = 45, Increment = 2, Callback = function(v) F.TriggerFOV = v end })
TabAim:AddSlider({ Name = "Trigger Delay", Min = 0, Max = 0.4, Default = 0.06, Increment = 0.01, Callback = function(v) F.TriggerDelay = v end })

TabESP:AddToggle({
	Name = "ESP",
	Default = true,
	Callback = function(v)
		F.ESP = v
		if not v then for p in pairs(espMap) do clearESP(p) end end
	end,
})
TabESP:AddToggle({ Name = "Names", Default = true, Callback = function(v) F.EspName = v end })
TabESP:AddToggle({ Name = "Health", Default = true, Callback = function(v) F.EspHP = v end })
TabESP:AddToggle({ Name = "Distance", Default = true, Callback = function(v) F.EspDist = v end })
TabESP:AddToggle({ Name = "Chams", Default = true, Callback = function(v) F.EspChams = v end })
TabESP:AddToggle({
	Name = "Show Teammates (GREEN)",
	Default = true,
	Callback = function(v) F.EspShowTeam = v end,
})
TabESP:AddToggle({
	Name = "Wall Fade (gray if behind wall)",
	Default = true,
	Callback = function(v) F.EspWallFade = v end,
})
TabESP:AddLabel("Enemy = RED  |  Team = GREEN  |  Wall = GRAY")

TabWorld:AddToggle({ Name = "No Fog", Default = true, Callback = function(v) F.NoFog = v applyNoFog(v) end })
TabWorld:AddToggle({ Name = "Fullbright", Default = false, Callback = function(v) F.Fullbright = v applyFullbright(v) end })
TabWorld:AddToggle({ Name = "Hide Trees/Grass", Default = false, Callback = function(v) F.NoTrees = v applyNoTrees(v) end })

TabMisc:AddToggle({ Name = "WalkSpeed", Default = false, Callback = function(v) F.WalkSpeed = v end })
TabMisc:AddSlider({ Name = "Speed Value", Min = 16, Max = 40, Default = 24, Increment = 1, Callback = function(v) F.WalkSpeedVal = v end })
TabMisc:AddToggle({ Name = "Infinite Jump", Default = false, Callback = function(v) F.InfJump = v end })
TabMisc:AddToggle({ Name = "Noclip", Default = false, Callback = function(v) F.Noclip = v setNoclip(v) end })
TabMisc:AddToggle({ Name = "Fly", Default = false, Callback = function(v) F.Fly = v if not v then stopFly() end end })
TabMisc:AddSlider({ Name = "Fly Speed", Min = 20, Max = 120, Default = 50, Increment = 5, Callback = function(v) F.FlySpeed = v end })
TabMisc:AddButton({
	Name = "Unload",
	Callback = function()
		GENV.__ConstipatedLF = GEN + 1
		F.Aimbot = false
		F.SilentAim = false
		F.Triggerbot = false
		F.ESP = false
		F.Fly = false
		F.Noclip = false
		stopFly()
		setNoclip(false)
		applyNoFog(false)
		applyFullbright(false)
		applyNoTrees(false)
		if fovCircle then pcall(function() fovCircle:Remove() end) end
		for p in pairs(espMap) do clearESP(p) end
		pcall(function() espFolder:Destroy() end)
		OrionLib:Destroy()
	end,
})

OrionLib:MakeNotification({
	Name = "Constipated Hub",
	Content = "Lost Front — Team GREEN / Enemy RED / Wall check ON",
	Time = 4,
})
OrionLib:Init()
