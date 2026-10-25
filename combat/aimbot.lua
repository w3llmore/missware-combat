--[[
    MissWare Combat — Aimbot (v2)
    Нативно использует UI API + configKey
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

-- ========== SETTINGS ==========
local AimbotSettings = {
    Enabled    = false,
    AimPart    = "Head",
    AimMode    = "Classic",
    FOV        = 45,
    Smoothness = 0.3,
    SilentAim  = false,
    AutoFire   = false,
    AutoStop   = false,
    MaxDistance = 400,
    AutoFireDelay = 0.05,
}

-- ========== LOGIC ==========
local fovCircle, aimbotConnection, lastFireTime = nil, nil, 0
local currentTarget, currentTargetPlayer = nil, nil

local function isPlayerAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char or not char.Parent then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
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
    if AimbotSettings.AimPart == "Head" then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    return root or char:FindFirstChild("Head")
end

local function getClosestEnemy()
    if not AimbotSettings.Enabled or not Camera then return nil end
    local cp = Camera.CFrame.Position
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local best, bestScore, bestPlayer = nil, math.huge, nil
    local maxFov = AimbotSettings.SilentAim and math.huge
        or (math.tan(math.rad(AimbotSettings.FOV / 2)) / math.tan(math.rad(Camera.FieldOfView / 2))) * cx
    local checkTeam = (AimbotSettings.AimMode == "CounterBlox")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and isPlayerAlive(plr) and not (checkTeam and isTeammate(plr)) then
            local char = plr.Character
            if char then
                local part = getTargetPart(char)
                if part and isVisible(part) then
                    local pos = part.Position
                    local dist = (pos - cp).Magnitude
                    if dist <= AimbotSettings.MaxDistance then
                        local screenPos = Camera:WorldToViewportPoint(pos)
                        if screenPos then
                            local dx, dy = screenPos.X - cx, screenPos.Y - cy
                            local fovDist = math.sqrt(dx * dx + dy * dy)
                            if fovDist <= maxFov and fovDist < bestScore then
                                bestScore, best, bestPlayer = fovDist, part, plr
                            end
                        end
                    end
                end
            end
        end
    end
    if best then currentTargetPlayer = bestPlayer end
    return best
end

local function applyAutoStop()
    if not AimbotSettings.AutoStop or not AimbotSettings.Enabled or not currentTarget then return end
    local char = Player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if root then
        root.Velocity = Vector3.new(0, root.Velocity.Y, 0)
        if humanoid then
            if humanoid:GetState() == Enum.HumanoidStateType.Running then
                humanoid:MoveTo(root.Position)
            end
        end
    end
end

local function createFovCircle()
    if not Drawing or not Camera then return end
    if fovCircle then pcall(function() fovCircle:Remove() end); fovCircle = nil end
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Visible, fovCircle.Radius, fovCircle.Thickness = false, 100, 1
        fovCircle.Color, fovCircle.Filled, fovCircle.NumSides = CFG.Accent, false, 60
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)
end

local function updateFovCircle()
    if not Drawing or not fovCircle or not Camera then return end
    pcall(function()
        local vs = Camera.ViewportSize
        local cx = vs.X / 2
        fovCircle.Position = Vector2.new(cx, vs.Y / 2)
        if AimbotSettings.SilentAim then fovCircle.Visible = false return end
        local aimRad = math.rad(AimbotSettings.FOV) / 2
        local camRad = math.rad(Camera.FieldOfView) / 2
        fovCircle.Radius = math.clamp((math.tan(aimRad) / math.tan(camRad)) * cx, 5, cx - 10)
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
    currentTarget = target
    if not target then currentTargetPlayer = nil end
    applyAutoStop()
    if target then
        pcall(function()
            local targetPos = target.Position
            local camPos = Camera.CFrame.Position
            if AimbotSettings.SilentAim then
                Camera.CFrame = CFrame.lookAt(camPos, targetPos)
            else
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(camPos, targetPos), (AimbotSettings.Smoothness or 0.5) + 0.2)
            end
        end)
    end
    if not AimbotSettings.AutoFire or not target or not currentTargetPlayer then return end
    if currentTargetPlayer == Player or not isPlayerAlive(currentTargetPlayer) then
        currentTarget, currentTargetPlayer = nil, nil
        return
    end
    if AimbotSettings.AimMode == "CounterBlox" and isTeammate(currentTargetPlayer) then
        currentTarget, currentTargetPlayer = nil, nil
        return
    end
    if not isVisible(target) then return end
    local screenPos = Camera:WorldToViewportPoint(target.Position)
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
    currentTarget, currentTargetPlayer, lastFireTime = nil, nil, 0
    createFovCircle()
    aimbotConnection = RunService.RenderStepped:Connect(mainLoop)
end

local function stopAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    if fovCircle then pcall(function() fovCircle.Visible = false end) end
    currentTarget, currentTargetPlayer, lastFireTime = nil, nil, 0
end

-- ============ ОТРИСОВКА UI КАРТОЧКИ ============
_G.MissWare.CreateAimbotUI = function(parentFrame)
    local new = _G.MissWare.UI.New
    local corner = _G.MissWare.UI.Corner
    local stroke = _G.MissWare.UI.Stroke
    local gradient = _G.MissWare.UI.Gradient
    local checkbox = _G.MissWare.UI.Checkbox
    local slider = _G.MissWare.UI.Slider
    local dropdown = _G.MissWare.UI.Dropdown
    local CFG = _G.MissWare.UI.CFG

    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 320),
        BackgroundColor3 = CFG.PanelLight,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ZIndex = 3,
    }, parentFrame)
    corner(card, 10)
    local cardStroke = stroke(card, CFG.Accent, 1, 0.4)
    if _G.MissWare.GlobalColorElements then
    table.insert(_G.MissWare.GlobalColorElements, { obj = cardStroke, prop = "Color", base = "Accent" })
end
    
    local title = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        Text = "AIMBOT",
        TextColor3 = CFG.AccentSoft,
        Font = CFG.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, card)
    table.insert(_G.MissWare.GlobalColorElements, { obj = title, prop = "TextColor3", base = "AccentSoft" })
    
    local line = new("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.new(0, 10, 0, 36),
        BackgroundColor3 = CFG.Accent,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, card)
    gradient(line, CFG.Accent, Color3.fromRGB(0,0,0), 0)
    
    local columns = new("Frame", {
        Size = UDim2.new(1, -20, 1, -50),
        Position = UDim2.fromOffset(10, 45),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, card)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, columns)
    
    local left = new("Frame", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 4 }, columns)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, left)
    
    local right = new("Frame", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 4 }, columns)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, right)
    
    checkbox(left, "Enable Aimbot", false, 1, function(state)
        _G.MissWare.Settings.Aimbot.Enabled = state
        if state then _G.MissWare.StartAimbot() else _G.MissWare.StopAimbot() end
    end, "Combat_Aimbot")
    
    checkbox(left, "Silent Aim", false, 2, function(state)
        _G.MissWare.Settings.Aimbot.SilentAim = state
        _G.MissWare.UpdateFovCircle()
    end, "Combat_SilentAim")
    
    checkbox(left, "Auto Fire", false, 3, function(state)
        _G.MissWare.Settings.Aimbot.AutoFire = state
    end, "Combat_AutoFire")
    
    slider(right, "FOV", 1, 360, 10, 1, function(val)
        _G.MissWare.Settings.Aimbot.FOV = val
        _G.MissWare.UpdateFovCircle()
    end, "Combat_FOV")
    
    slider(right, "Smoothness", 1, 100, 30, 2, function(val)
        _G.MissWare.Settings.Aimbot.Smoothness = val / 100
    end, "Combat_Smooth")
    
    dropdown(left, "Aim Part", {"Head", "HumanoidRootPart", "Torso"}, "Head", 4, function(val)
        _G.MissWare.Settings.Aimbot.AimPart = val
    end, "Combat_AimPart")
    
    dropdown(right, "Aim Mode", {"Classic", "CounterBlox"}, "Classic", 3, function(val)
        _G.MissWare.Settings.Aimbot.AimMode = val
    end, "Combat_AimMode")
end

_G.MissWare.AimbotSettings = AimbotSettings
_G.MissWare.startAimbot = startAimbot
_G.MissWare.stopAimbot = stopAimbot
_G.MissWare.updateFovCircle = updateFovCircle
print("[MissWare] Aimbot loaded")
