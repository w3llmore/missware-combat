--[[
    MissWare Combat — Aimbot
    Загружается через loadstring из main UI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Drawing = Drawing or nil

-- Доступ к API GUI
local UI = _G.MissWare and _G.MissWare.UI
if not UI then
    warn("[MissWare Aimbot] UI API не найден")
    return
end

-- ========== SETTINGS ==========
local AimbotSettings = {
    Enabled = false,
    AimPart = "Head",
    AimMode = "Classic",
    FOV = 45,
    Smoothness = 0.3,
    SilentAim = false,
    AutoFire = false,
    AutoStop = false,
    MaxDistance = 400,
    AutoFireDelay = 0.05,
    BindKey = nil,
}

-- ========== LOGIC ==========
local fovCircle = nil
local aimbotConnection = nil
local lastFireTime = 0
local currentTarget = nil
local currentTargetPlayer = nil
local AimbotToggle = nil

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
    local aimPart = AimbotSettings.AimPart or "Head"
    if aimPart == "Head" then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
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
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.Running then
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
        fovCircle.Visible = false
        fovCircle.Radius = 100
        fovCircle.Thickness = 1
        fovCircle.Color = UI.CFG.Accent
        fovCircle.Filled = false
        fovCircle.NumSides = 60
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)
end

local function updateFovCircle()
    if not Drawing or not fovCircle or not Camera then return end
    pcall(function()
        local vs = Camera.ViewportSize
        local cx = vs.X / 2
        fovCircle.Position = Vector2.new(cx, vs.Y / 2)
        if AimbotSettings.SilentAim then
            fovCircle.Visible = false
            return
        end
        local aimRad = math.rad(AimbotSettings.FOV) / 2
        local camRad = math.rad(Camera.FieldOfView) / 2
        local r = (math.tan(aimRad) / math.tan(camRad)) * cx
        fovCircle.Radius = math.clamp(r, 5, cx - 10)
        fovCircle.Visible = AimbotSettings.Enabled
        fovCircle.Color = UI.CFG.Accent
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
                local targetCF = CFrame.lookAt(camPos, targetPos)
                local smooth = AimbotSettings.Smoothness or 0.5
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, smooth + 0.2)
            end
        end)
    end

    if not AimbotSettings.AutoFire or not target or not currentTargetPlayer then return end
    local plr = currentTargetPlayer
    if plr == Player or not isPlayerAlive(plr) then
        currentTarget, currentTargetPlayer = nil, nil
        return
    end
    if AimbotSettings.AimMode == "CounterBlox" and isTeammate(plr) then
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

-- ========== UI CARD ==========
function _G.MissWare.CreateAimbotUI(parent)
    local new, corner, stroke, checkbox, slider = UI.New, UI.Corner, UI.Stroke, UI.Checkbox, UI.Slider
    local CFG = UI.CFG

    -- Контейнер карточки (использует panel стиль)
    local card = new("Frame", {
        Size = UDim2.new(1, -16, 0, 360), -- Примерная высота, можно сделать авто
        BackgroundColor3 = CFG.PanelLight,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, parent)
    corner(card, 12)
    stroke(card, CFG.Accent, 1.5, 0.6)

    -- Заголовок с тумблером
    local title = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        Text = "AIMBOT",
        TextColor3 = CFG.Text,
        Font = UI.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, card)

    local btn = new("TextButton", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -54, 0, 12),
        BackgroundColor3 = CFG.Bg,
        Text = "OFF",
        TextColor3 = CFG.Text,
        Font = UI.FontBold,
        TextSize = 12,
        ZIndex = 4,
    }, card)
    corner(btn, 6)
    stroke(btn, CFG.Accent, 1, 0.5)

    btn.MouseButton1Click:Connect(function()
        AimbotSettings.Enabled = not AimbotSettings.Enabled
        btn.Text = AimbotSettings.Enabled and "ON" or "OFF"
        btn.TextColor3 = AimbotSettings.Enabled and CFG.Accent or CFG.Text
        if AimbotSettings.Enabled then startAimbot() else stopAimbot() end
    end)

    -- Контент (сетка компонентов)
    local content = new("Frame", {
        Size = UDim2.new(1, -20, 1, -50),
        Position = UDim2.fromOffset(10, 40),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, card)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)

    -- Компоненты (с интегрированным ConfigKey)
    local function dropdown(parent, text, options, default, order, callback, configKey)
        -- (упрощенная реализация dropdown, так как в base UI его нет, 
        -- нужно добавить в основной UI)
        return UI.Dropdown and UI.Dropdown(parent, text, options, default, order, callback, configKey) or nil
    end

    -- Пример вызова (твоя UI-библиотека должна поддерживать configKey):
    UI.Slider(content, "FOV", 10, 360, AimbotSettings.FOV, 1, function(val)
        AimbotSettings.FOV = val
        updateFovCircle()
    end, "Aimbot_FOV")

    UI.Slider(content, "Smooth", 0.1, 1.0, AimbotSettings.Smoothness, 2, function(val)
        AimbotSettings.Smoothness = val
    end, "Aimbot_Smooth")

    UI.Slider(content, "Distance", 50, 1000, AimbotSettings.MaxDistance, 3, function(val)
        AimbotSettings.MaxDistance = val
    end, "Aimbot_Dist")

    UI.Checkbox(content, "Silent Aim", AimbotSettings.SilentAim, 4, function(val)
        AimbotSettings.SilentAim = val
        updateFovCircle()
    end, "Aimbot_Silent")

    UI.Checkbox(content, "Auto Fire", AimbotSettings.AutoFire, 5, function(val)
        AimbotSettings.AutoFire = val
    end, "Aimbot_AutoFire")

    UI.Checkbox(content, "Auto Stop", AimbotSettings.AutoStop, 6, function(val)
        AimbotSettings.AutoStop = val
    end, "Aimbot_AutoStop")
    
    -- Обновляем размер карточки под содержимое
    content.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        card.Size = UDim2.new(1, -16, 0, 50 + content.UIListLayout.AbsoluteContentSize.Y)
    end)
end
