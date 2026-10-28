--[[
    MissWare Combat — Aimbot (v6 - FULL CARD + 2 COLUMNS)
    Карточка = половина ширины GUI, настройки в 2 столбика, скролл работает
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
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
    currentTarget, currentTargetPlayer, lastFireTime = nil, nil, 0
    createFovCircle()
    aimbotConnection = RunService.RenderStepped:Connect(mainLoop)
end

local function stopAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    if fovCircle then pcall(function() fovCircle.Visible = false end) end
    currentTarget, currentTargetPlayer, lastFireTime = nil, nil, 0
end

-- ========== HELPER: форматирование бинда ==========
local function formatBind(k)
    if not k then return "Bind" end
    if typeof(k) == "EnumItem" then
        if k.EnumType == Enum.KeyCode then return k.Name end
        if k == Enum.UserInputType.MouseButton1 then return "M1" end
        if k == Enum.UserInputType.MouseButton2 then return "M2" end
        return k.Name
    end
    return tostring(k)
end

-- ========== AIMBOT CARD ==========
local function createAimbotCard(parent)
    -- Карточка = половина ширины родителя, фикс. высота под 2 столбика
    local card = new("Frame", {
        Size = UDim2.new(0.5, -8, 0, 430),
        BackgroundColor3 = CFG.PanelLight,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ZIndex = 3,
    }, parent)
    corner(card, 10)
    stroke(card, CFG.Accent, 1, 0.6)
    if GlobalThemeElements then
        table.insert(GlobalThemeElements, { obj = card, prop = "BackgroundColor3", base = "PanelLight" })
    end

    -- ===== HEADER =====
    local header = new("Frame", {
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.fromOffset(8, 4),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, card)

    local titleLabel = new("TextLabel", {
        Size = UDim2.new(0, 100, 1, 0),
        BackgroundTransparency = 1,
        Text = "Aimbot",
        TextColor3 = CFG.Text,
        Font = UI.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    }, header)
    if GlobalThemeElements then
        table.insert(GlobalThemeElements, { obj = titleLabel, prop = "TextColor3", base = "Text" })
    end

    -- ===== TOGGLE =====
    local toggle = new("TextButton", {
        Size = UDim2.fromOffset(44, 22),
        Position = UDim2.new(1, -100, 0, 7),
        BackgroundColor3 = CFG.PanelHover,
        BackgroundTransparency = 0,
        Text = "OFF",
        TextColor3 = CFG.Text,
        Font = UI.FontBold,
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 5,
    }, header)
    corner(toggle, 4)
    local toggleStroke = stroke(toggle, CFG.TextDim, 1, 0.5)

    local function updateToggleVisual()
        toggle.Text = AimbotSettings.Enabled and "ON" or "OFF"
        toggle.TextColor3 = AimbotSettings.Enabled and CFG.Accent or CFG.Text
        toggle.BackgroundTransparency = AimbotSettings.Enabled and 0.1 or 0
        toggleStroke.Color = AimbotSettings.Enabled and CFG.Accent or CFG.TextDim
        toggleStroke.Transparency = AimbotSettings.Enabled and 0 or 0.5
    end
    updateToggleVisual()

    local function setEnabled(v)
        AimbotSettings.Enabled = v
        updateToggleVisual()
        UI.SetConfig("Aimbot_Enabled", v)
        if v then startAimbot() else stopAimbot() end
    end

    toggle.MouseButton1Click:Connect(function()
        setEnabled(not AimbotSettings.Enabled)
    end)

    UI.SetConfig("Aimbot_Enabled", AimbotSettings.Enabled)
    UI.ConfigElements["Aimbot_Enabled"] = {
        Set = function(v) setEnabled(v) end,
        Get = function() return AimbotSettings.Enabled end,
    }

    -- ===== BIND =====
    local bindBtn = new("TextButton", {
        Size = UDim2.fromOffset(50, 22),
        Position = UDim2.new(1, -50, 0, 7),
        BackgroundColor3 = CFG.PanelHover,
        BackgroundTransparency = 0.2,
        Text = formatBind(AimbotSettings.BindKey),
        TextColor3 = CFG.TextDim,
        Font = UI.FontMed,
        TextSize = 10,
        AutoButtonColor = false,
        ZIndex = 5,
    }, header)
    corner(bindBtn, 4)
    stroke(bindBtn, CFG.TextDim, 1, 0.6)
    if GlobalThemeElements then
        table.insert(GlobalThemeElements, { obj = bindBtn, prop = "BackgroundColor3", base = "PanelHover" })
        table.insert(GlobalThemeElements, { obj = bindBtn, prop = "TextColor3", base = "TextDim" })
    end

    local bindingAimbot = false

    local function applyBindVisual()
        bindBtn.Text = formatBind(AimbotSettings.BindKey)
        bindBtn.TextColor3 = AimbotSettings.BindKey and CFG.Accent or CFG.TextDim
    end

    bindBtn.MouseButton1Click:Connect(function()
        if bindingAimbot then return end
        bindingAimbot = true
        bindBtn.Text = "..."
        bindBtn.TextColor3 = CFG.AccentSoft
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if not bindingAimbot or gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                AimbotSettings.BindKey = input.KeyCode
                UI.SetConfig("Aimbot_BindKey", input.KeyCode.Name)
                bindingAimbot = false
                applyBindVisual()
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            AimbotSettings.BindKey = Enum.UserInputType.MouseButton1
            UI.SetConfig("Aimbot_BindKey", "M1")
            bindingAimbot = false
            applyBindVisual()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            AimbotSettings.BindKey = Enum.UserInputType.MouseButton2
            UI.SetConfig("Aimbot_BindKey", "M2")
            bindingAimbot = false
            applyBindVisual()
        end
    end)

    UI.SetConfig("Aimbot_BindKey", AimbotSettings.BindKey and formatBind(AimbotSettings.BindKey) or nil)
    UI.ConfigElements["Aimbot_BindKey"] = {
        Set = function(v)
            if v == nil or v == "" then
                AimbotSettings.BindKey = nil
            elseif v == "M1" then
                AimbotSettings.BindKey = Enum.UserInputType.MouseButton1
            elseif v == "M2" then
                AimbotSettings.BindKey = Enum.UserInputType.MouseButton2
            else
                local ok, k = pcall(function() return Enum.KeyCode[v] end)
                if ok and k then AimbotSettings.BindKey = k end
            end
            applyBindVisual()
        end,
        Get = function()
            return AimbotSettings.BindKey and formatBind(AimbotSettings.BindKey) or nil
        end,
    }

    -- ===== CONTENT (2 столбика) =====
    local content = new("Frame", {
        Size = UDim2.new(1, -16, 1, -44),
        Position = UDim2.fromOffset(8, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 4,
    }, card)

    local leftCol = new("Frame", {
        Size = UDim2.new(0.5, -4, 1, 0),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, content)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, leftCol)

    local rightCol = new("Frame", {
        Size = UDim2.new(0.5, -4, 1, 0),
        Position = UDim2.new(0.5, 4, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, content)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, rightCol)

    -- ЛЕВЫЙ СТОЛБИК
    UI.Dropdown(leftCol, "Aim Mode", {"FluxoPvP", "Classic", "CounterBlox"}, AimbotSettings.AimMode, 1, function(v)
        AimbotSettings.AimMode = v
    end, "Aimbot_AimMode")

    UI.Dropdown(leftCol, "Aim Part", {"Head", "Body", "Torso"}, AimbotSettings.AimPart, 2, function(v)
        AimbotSettings.AimPart = v
    end, "Aimbot_AimPart")

    UI.Slider(leftCol, "FOV", 1, 90, AimbotSettings.FOV, 3, function(v)
        AimbotSettings.FOV = v; updateFovCircle()
    end, "Aimbot_FOV")

    UI.Slider(leftCol, "Smooth", 0.1, 1.0, AimbotSettings.Smoothness, 4, function(v)
        AimbotSettings.Smoothness = v
    end, "Aimbot_Smooth")

    UI.Slider(leftCol, "Distance", 50, 1000, AimbotSettings.MaxDistance, 5, function(v)
        AimbotSettings.MaxDistance = v
    end, "Aimbot_Dist")

    -- ПРАВЫЙ СТОЛБИК
    UI.Slider(rightCol, "Fire Delay", 0.01, 0.5, AimbotSettings.AutoFireDelay, 1, function(v)
        AimbotSettings.AutoFireDelay = v
    end, "Aimbot_FireDelay")

    UI.Checkbox(rightCol, "Silent Aim", AimbotSettings.SilentAim, 2, function(v)
        AimbotSettings.SilentAim = v; updateFovCircle()
    end, "Aimbot_SilentAim")

    UI.Checkbox(rightCol, "Auto Fire", AimbotSettings.AutoFire, 3, function(v)
        AimbotSettings.AutoFire = v
    end, "Aimbot_AutoFire")

    UI.Checkbox(rightCol, "Auto Stop", AimbotSettings.AutoStop, 4, function(v)
        AimbotSettings.AutoStop = v
    end, "Aimbot_AutoStop")

    -- Обновление визуала toggle извне (для BindKey-хендлера)
    _G.MissWare.UpdateAimbotToggle = updateToggleVisual
end

-- ========== PUBLIC API ==========
function _G.MissWare.CreateAimbotUI(parent)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 430),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        ZIndex = 3,
    }, parent)
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    createAimbotCard(row)
end

-- ========== BIND KEY HANDLER ==========
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = AimbotSettings.BindKey
    if not k then return end
    local pressed = false
    if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode then
        pressed = (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == k)
    elseif k == Enum.UserInputType.MouseButton1 then
        pressed = (input.UserInputType == Enum.UserInputType.MouseButton1)
    elseif k == Enum.UserInputType.MouseButton2 then
        pressed = (input.UserInputType == Enum.UserInputType.MouseButton2)
    end
    if pressed then
        AimbotSettings.Enabled = not AimbotSettings.Enabled
        UI.SetConfig("Aimbot_Enabled", AimbotSettings.Enabled)
        if AimbotSettings.Enabled then startAimbot() else stopAimbot() end
        if _G.MissWare.UpdateAimbotToggle then _G.MissWare.UpdateAimbotToggle() end
    end
end)

_G.MissWare.AimbotSettings = AimbotSettings
_G.MissWare.startAimbot = startAimbot
_G.MissWare.stopAimbot = stopAimbot
_G.MissWare.updateFovCircle = updateFovCircle
print("[MissWare] Aimbot loaded")
