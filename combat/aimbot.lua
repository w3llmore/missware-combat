--[[
    MissWare Combat — Aimbot (v4 - FULL)
    Логика из сырого кода + UI в стиле MissWare + все фиксы
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Drawing = Drawing or nil

local UI = _G.MissWare and _G.MissWare.UI
if not UI then warn("[MissWare Aimbot] UI API not found") return end
local new, corner, stroke, gradient = UI.New, UI.Corner, UI.Stroke, UI.Gradient
local CFG = UI.CFG

local GlobalColorElements = _G.MissWare.GlobalColorElements
local GlobalThemeElements = _G.MissWare.GlobalThemeElements
if not GlobalColorElements or not GlobalThemeElements then
    warn("[MissWare Aimbot] Global theme tables not found. Добавь _G.MissWare.GlobalThemeElements = GlobalThemeElements в GUI.")
end

-- ========== AIMBOT SETTINGS ==========
local AimbotSettings = {
    Enabled       = false,
    AimPart       = "Head",
    AimMode       = "Classic",
    FOV           = 10,
    Smoothness    = 0.3,
    SilentAim     = false,
    AutoFire      = false,
    AutoStop      = false,
    MaxDistance   = 400,
    AutoFireDelay = 0.05,
    BindKey       = nil,
}

-- ========== AIMBOT LOGIC ==========
local fovCircle = nil
local aimbotConnection = nil
local autoFireConnection = nil
local lastFireTime = 0
local currentTarget = nil
local currentTargetPlayer = nil

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
    if plr.Team and Player.Team and plr.Team == Player.Team then
        return true
    end
    return false
end

local function isVisible(targetPart)
    if not targetPart or not Camera then return true end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Player.Character, targetPart}
    local result = Workspace:Raycast(origin, direction, params)
    return not result
        or result.Instance == targetPart
        or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getTargetPart(char)
    if not char then return nil end
    local aimPart = AimbotSettings.AimPart or "Head"
    if aimPart == "Head" then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
    elseif aimPart == "Torso" or aimPart == "Body" then
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if torso and torso:IsA("BasePart") then return torso end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestEnemy()
    if not AimbotSettings.Enabled then return nil end
    if not Camera then return nil end

    local cp = Camera.CFrame.Position
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local best, bestScore, bestPlayer = nil, math.huge, nil
    local maxFov = AimbotSettings.SilentAim and math.huge
        or (math.tan(math.rad(AimbotSettings.FOV / 2)) / math.tan(math.rad(Camera.FieldOfView / 2))) * cx
    local checkTeam = (AimbotSettings.AimMode == "CounterBlox")

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
        if dist > AimbotSettings.MaxDistance then continue end

        local screenPos = Camera:WorldToViewportPoint(pos)
        if not screenPos then continue end

        local dx, dy = screenPos.X - cx, screenPos.Y - cy
        local fovDist = math.sqrt(dx * dx + dy * dy)

        if fovDist <= maxFov and fovDist < bestScore then
            bestScore, best, bestPlayer = fovDist, part, plr
        end
    end

    if best then currentTargetPlayer = bestPlayer end
    return best
end

local function applyAutoStop()
    if not AimbotSettings.AutoStop then return end
    if not AimbotSettings.Enabled then return end
    if not currentTarget then return end

    local char = Player.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local humanoid = char:FindFirstChild("Humanoid")
    root.Velocity = Vector3.new(0, root.Velocity.Y, 0)

    if humanoid then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Running
            or state == Enum.HumanoidStateType.Sprinting
            or state == Enum.HumanoidStateType.Walking then
            humanoid:MoveTo(root.Position)
        end
    end
end

function createFovCircle()
    if not Drawing or not Camera then return end
    if fovCircle then pcall(function() fovCircle:Remove() end); fovCircle = nil end
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Visible = false
        fovCircle.Radius = 100
        fovCircle.Thickness = 2
        fovCircle.Color = CFG.Accent
        fovCircle.Filled = false
        fovCircle.NumSides = 60
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)
end

function updateFovCircle()
    if not Drawing or not fovCircle or not Camera then return end
    pcall(function()
        local vs = Camera.ViewportSize
        local cx, cy = vs.X / 2, vs.Y / 2
        fovCircle.Position = Vector2.new(cx, cy)

        if AimbotSettings.SilentAim then
            fovCircle.Visible = false
            return
        end

        local aimRad = math.rad(AimbotSettings.FOV) / 2
        local camRad = math.rad(Camera.FieldOfView) / 2
        local r = (math.tan(aimRad) / math.tan(camRad)) * cx
        fovCircle.Radius = math.clamp(r, 5, cx - 10)
        fovCircle.Visible = AimbotSettings.Enabled
        fovCircle.Color = CFG.Accent
    end)
end

local function mainLoop()
    if not AimbotSettings.Enabled then
        if fovCircle then pcall(function() fovCircle.Visible = false end) end
        return
    end
    if not Camera then return end

    updateFovCircle()

    local target = getClosestEnemy()
    if target then
        currentTarget = target
    else
        currentTarget = nil
        currentTargetPlayer = nil
    end

    applyAutoStop()

    if currentTarget and AimbotSettings.Enabled then
        pcall(function()
            local targetPos = currentTarget.Position
            local camPos = Camera.CFrame.Position
            if AimbotSettings.SilentAim then
                Camera.CFrame = CFrame.lookAt(camPos, targetPos)
            else
                local targetCF = CFrame.lookAt(camPos, targetPos)
                local smooth = AimbotSettings.Smoothness or 0.5
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, smooth + 0.2)
            end
        end)
    end

    -- AUTOFIRE
    if not AimbotSettings.AutoFire or not currentTarget or not currentTargetPlayer then return end

    local plr = currentTargetPlayer
    if plr == Player or not isPlayerAlive(plr) then
        currentTarget, currentTargetPlayer = nil, nil
        return
    end

    if AimbotSettings.AimMode == "CounterBlox" and isTeammate(plr) then
        currentTarget, currentTargetPlayer = nil, nil
        return
    end

    if not isVisible(currentTarget) then return end

    local screenPos = Camera:WorldToViewportPoint(currentTarget.Position)
    if not screenPos then return end

    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    if math.abs(screenPos.X - cx) > 30 or math.abs(screenPos.Y - cy) > 30 then return end

    if tick() - lastFireTime < AimbotSettings.AutoFireDelay then return end

    if mouse1press then pcall(mouse1press) end
    task.wait(0.01)
    if mouse1release then pcall(mouse1release) end
    lastFireTime = tick()
end

local function startAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    if autoFireConnection then autoFireConnection:Disconnect(); autoFireConnection = nil end
    currentTarget, currentTargetPlayer, lastFireTime = nil, nil, 0
    createFovCircle()
    aimbotConnection = RunService.RenderStepped:Connect(mainLoop)
    autoFireConnection = nil
end

local function stopAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    if autoFireConnection then autoFireConnection:Disconnect(); autoFireConnection = nil end
    if fovCircle then pcall(function() fovCircle.Visible = false end) end
    currentTarget, currentTargetPlayer, lastFireTime = nil, nil, 0
end

-- ========== UI CARD ==========
function _G.MissWare.CreateAimbotUI(parent)
    -- 1. Заголовок
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        ZIndex = 3,
    }, parent)
    local title = new("TextLabel", {
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundTransparency = 1,
        Text = "AIMBOT",
        TextColor3 = CFG.AccentSoft,
        Font = UI.FontBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, holder)
    if GlobalColorElements then
        table.insert(GlobalColorElements, { obj = title, prop = "TextColor3", base = "AccentSoft" })
    end

    -- 2. Toggle (Enabled)
    local toggleHolder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = CFG.PanelLight,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 3,
    }, parent)
    corner(toggleHolder, 8)
    stroke(toggleHolder, CFG.TextDim, 1, 0.8)
    if GlobalThemeElements then
        table.insert(GlobalThemeElements, { obj = toggleHolder, prop = "BackgroundColor3", base = "PanelLight" })
    end

    local toggleLabel = new("TextLabel", {
        Size = UDim2.new(0.5, -14, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = "Enabled",
        TextColor3 = CFG.Text,
        Font = UI.FontMed,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, toggleHolder)
    if GlobalThemeElements then
        table.insert(GlobalThemeElements, { obj = toggleLabel, prop = "TextColor3", base = "Text" })
    end

    local toggleBtn = new("TextButton", {
        Size = UDim2.fromOffset(48, 24),
        Position = UDim2.new(0.5, 0, 0.5, -12),
        BackgroundColor3 = CFG.Bg,
        BackgroundTransparency = 0.3,
        Text = "OFF",
        TextColor3 = CFG.Text,
        Font = UI.FontBold,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 4,
    }, toggleHolder)
    corner(toggleBtn, 6)
    stroke(toggleBtn, CFG.Accent, 1, 0.5)
    if GlobalThemeElements then
        table.insert(GlobalThemeElements, { obj = toggleBtn, prop = "BackgroundColor3", base = "Bg" })
    end
    if GlobalColorElements then
        table.insert(GlobalColorElements, { obj = toggleBtn, prop = "TextColor3", base = "Accent" })
    end

    local function updateToggleVisual()
        toggleBtn.Text = AimbotSettings.Enabled and "ON" or "OFF"
        toggleBtn.TextColor3 = AimbotSettings.Enabled and CFG.Accent or CFG.Text
        toggleBtn.BackgroundTransparency = AimbotSettings.Enabled and 0.1 or 0.3
    end
    updateToggleVisual()

    local function setEnabled(v)
        AimbotSettings.Enabled = v
        updateToggleVisual()
        UI.SetConfig("Aimbot_Enabled", v)
        if v then startAimbot() else stopAimbot() end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        setEnabled(not AimbotSettings.Enabled)
    end)

    UI.SetConfig("Aimbot_Enabled", AimbotSettings.Enabled)
    UI.ConfigElements["Aimbot_Enabled"] = {
        Set = function(v) setEnabled(v) end,
        Get = function() return AimbotSettings.Enabled end,
    }

    -- 3. Остальные компоненты (порядок как в твоём сыром коде)
    UI.Dropdown(parent, "Aim Mode", {"Classic", "CounterBlox"}, AimbotSettings.AimMode, 3, function(v)
        AimbotSettings.AimMode = v
    end, "Aimbot_AimMode")

    UI.Dropdown(parent, "Aim Part", {"Head", "Body", "Torso"}, AimbotSettings.AimPart, 4, function(v)
        AimbotSettings.AimPart = v
    end, "Aimbot_AimPart")

    UI.Slider(parent, "FOV", 10, 360, AimbotSettings.FOV, 5, function(v)
        AimbotSettings.FOV = v; updateFovCircle()
    end, "Aimbot_FOV")

    UI.Slider(parent, "Smooth", 0.1, 1.0, AimbotSettings.Smoothness, 6, function(v)
        AimbotSettings.Smoothness = v
    end, "Aimbot_Smooth")

    UI.Slider(parent, "Distance", 50, 1000, AimbotSettings.MaxDistance, 7, function(v)
        AimbotSettings.MaxDistance = v
    end, "Aimbot_Dist")

    UI.Slider(parent, "Fire Delay", 0.01, 0.5, AimbotSettings.AutoFireDelay, 8, function(v)
        AimbotSettings.AutoFireDelay = v
    end, "Aimbot_FireDelay")

    UI.Checkbox(parent, "Silent Aim", AimbotSettings.SilentAim, 9, function(v)
        AimbotSettings.SilentAim = v; updateFovCircle()
    end, "Aimbot_SilentAim")

    UI.Checkbox(parent, "Auto Fire", AimbotSettings.AutoFire, 10, function(v)
        AimbotSettings.AutoFire = v
    end, "Aimbot_AutoFire")

    -- 🔥 ВОТ ОН — AUTO STOP, которого не хватало
    UI.Checkbox(parent, "Auto Stop", AimbotSettings.AutoStop, 11, function(v)
        AimbotSettings.AutoStop = v
    end, "Aimbot_AutoStop")
end

_G.MissWare.AimbotSettings = AimbotSettings
_G.MissWare.startAimbot = startAimbot
_G.MissWare.stopAimbot = stopAimbot
_G.MissWare.updateFovCircle = updateFovCircle
print("[MissWare] Aimbot loaded")
