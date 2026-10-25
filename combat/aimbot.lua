-- combat/aimbot.lua
-- MissWare Aimbot Module (Logic Only)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local Drawing = Drawing or nil

local Settings = _G.MissWare.Settings.Aimbot
if not Settings then return warn("Aimbot settings not found!") end

local AB = { fovCircle = nil, conn = nil, lastFire = 0, target = nil, targetPlr = nil }

local function isPlayerAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char or not char.Parent then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local function isTeammate(plr)
    if not plr or not Player then return false end
    if plr.Team and Player.Team and plr.Team == Player.Team then return true end
    return false
end

local function isVisible(targetPart)
    if not targetPart or not Camera then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit
    local distance = (origin - targetPart.Position).Magnitude
    local ray = Ray.new(origin, direction * distance)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {Player.Character, targetPart})
    return not hit or hit == targetPart or hit:IsDescendantOf(targetPart.Parent)
end

local function getTargetPart(char)
    if not char then return nil end
    local aimPart = Settings.AimPart or "Head"
    if aimPart == "Head" then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestEnemy()
    if not Settings.Enabled or not Camera then return nil end
    local cp = Camera.CFrame.Position
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local best, bestScore, bestPlayer = nil, math.huge, nil

    local maxFov = Settings.SilentAim and math.huge
        or (math.tan(math.rad(Settings.FOV / 2)) / math.tan(math.rad(Camera.FieldOfView / 2))) * cx
    local checkTeam = (Settings.AimMode == "CounterBlox")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == Player then continue end
        if not isPlayerAlive(plr) then continue end
        if checkTeam and isTeammate(plr) then continue end

        local char = plr.Character
        if not char then continue end

        local part = getTargetPart(char)
        if not part or not isVisible(part) then continue end

        local pos = part.Position
        local dist = (pos - cp).Magnitude
        if dist > Settings.MaxDistance then continue end

        local screenPos = Camera:WorldToViewportPoint(pos)
        if not screenPos then continue end

        local dx, dy = screenPos.X - cx, screenPos.Y - cy
        local fovDist = math.sqrt(dx * dx + dy * dy)

        if fovDist <= maxFov and fovDist < bestScore then
            bestScore, best, bestPlayer = fovDist, part, plr
        end
    end
    if best then AB.targetPlr = bestPlayer end
    return best
end

local function applyAutoStop()
    if not Settings.AutoStop or not Settings.Enabled or not AB.target then return end
    local char = Player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end
    if hum.FloorMaterial ~= Enum.Material.Air then
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
        pcall(function() hum:MoveTo(root.Position) end)
    end
end

_G.MissWare.CreateFovCircle = function()
    if not Drawing or not Camera then return end
    if AB.fovCircle then pcall(function() AB.fovCircle:Remove() end); AB.fovCircle = nil end
    pcall(function()
        AB.fovCircle = Drawing.new("Circle")
        AB.fovCircle.Visible = false
        AB.fovCircle.Radius = 100
        AB.fovCircle.Thickness = 2
        AB.fovCircle.Color = Color3.fromRGB(255,255,255)
        AB.fovCircle.Filled = false
        AB.fovCircle.NumSides = 60
        AB.fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end)
end

_G.MissWare.UpdateFovCircle = function()
    if not Drawing or not AB.fovCircle or not Camera then return end
    pcall(function()
        local vs = Camera.ViewportSize
        local cx, cy = vs.X/2, vs.Y/2
        AB.fovCircle.Position = Vector2.new(cx, cy)
        if Settings.SilentAim then AB.fovCircle.Visible = false; return end
        local aimRad = math.rad(Settings.FOV)/2
        local camRad = math.rad(Camera.FieldOfView)/2
        local r = (math.tan(aimRad)/math.tan(camRad)) * cx
        AB.fovCircle.Radius = math.clamp(r, 5, cx-10)
        AB.fovCircle.Visible = Settings.Enabled
    end)
end

local function mainLoop()
    if not Settings.Enabled then
        if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
        return
    end
    if not Camera then return end
    _G.MissWare.UpdateFovCircle()

    local target = getClosestEnemy()
    if target then AB.target = target else AB.target = nil; AB.targetPlr = nil end
    applyAutoStop()

    if AB.target then
        pcall(function()
            local targetPos = AB.target.Position
            local camPos = Camera.CFrame.Position
            if Settings.SilentAim then
                Camera.CFrame = CFrame.lookAt(camPos, targetPos)
            else
                local targetCF = CFrame.lookAt(camPos, targetPos)
                local smooth = Settings.Smoothness or 0.5
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, smooth + 0.2)
            end
        end)
    end

    if not Settings.AutoFire or not AB.target or not AB.targetPlr then return end
    local plr = AB.targetPlr
    if plr == Player or not isPlayerAlive(plr) then AB.target = nil; AB.targetPlr = nil; return end
    if Settings.AimMode == "CounterBlox" and isTeammate(plr) then AB.target = nil; AB.targetPlr = nil; return end
    if not isVisible(AB.target) then return end

    local screenPos = Camera:WorldToViewportPoint(AB.target.Position)
    if not screenPos then return end
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    if math.abs(screenPos.X - cx) > 30 or math.abs(screenPos.Y - cy) > 30 then return end
    if tick() - AB.lastFire < Settings.AutoFireDelay then return end

    if mouse1press then pcall(mouse1press) end
    task.wait(0.01)
    if mouse1release then pcall(mouse1release) end
    AB.lastFire = tick()
end

_G.MissWare.StartAimbot = function()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
    _G.MissWare.CreateFovCircle()
    AB.conn = RunService.RenderStepped:Connect(mainLoop)
end

_G.MissWare.StopAimbot = function()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
end
