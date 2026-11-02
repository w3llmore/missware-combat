--[[
    MissWare Combat — Aimbot (v28 - FINAL)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Drawing = Drawing or nil

local UI = _G.MissWare and _G.MissWare.UI
if not UI then warn("[MissWare Aimbot] UI API not found") return end
local new, corner, stroke, gradient = UI.New, UI.Corner, UI.Stroke, UI.Gradient
local CFG = UI.CFG
local SetConfig = UI.SetConfig
local ConfigElements = UI.ConfigElements

local tween = UI.Tween or function(obj, info, props)
    if not obj or not obj.Parent then return end
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local GlobalColorElements = _G.MissWare.GlobalColorElements or {}
local GlobalThemeElements = _G.MissWare.GlobalThemeElements or {}

-- ========== SETTINGS ==========
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

-- ========== AIMBOT LOGIC (без изменений, кроме мелочей) ==========
local fovCircle, aimbotConnection, lastFireTime = nil, nil, 0
local currentTarget, currentTargetPlayer, drawingBroken = nil, nil, false

local function isPlayerAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function isTeammate(plr)
    return plr and Player and plr.Team and Player.Team and plr.Team == Player.Team
end

local function isVisible(targetPart)
    if not targetPart or not Camera then return true end
    local origin = Camera.CFrame.Position
    local dir = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Player.Character, targetPart, targetPart.Parent}
    local result = Workspace:Raycast(origin, dir, params)
    return not result or result.Instance == targetPart or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getTargetPart(char)
    if not char then return nil end
    local ap = AimbotSettings.AimPart or "Head"
    if ap == "Head" then
        local h = char:FindFirstChild("Head")
        if h and h:IsA("BasePart") then return h end
    elseif ap == "Torso" or ap == "Body" then
        local t = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if t and t:IsA("BasePart") then return t end
    end
    local r = char:FindFirstChild("HumanoidRootPart")
    return (r and r:IsA("BasePart")) and r or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
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
                    if (pos - cp).Magnitude <= AimbotSettings.MaxDistance then
                        local sp = Camera:WorldToViewportPoint(pos)
                        if sp then
                            local dx, dy = sp.X - cx, sp.Y - cy
                            local fd = math.sqrt(dx*dx + dy*dy)
                            if fd <= maxFov and fd < bestScore then
                                bestScore, best, bestPlayer = fd, part, plr
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
    if not root then return end
    local hum = char:FindFirstChild("Humanoid")
    root.Velocity = Vector3.new(0, root.Velocity.Y, 0)
    if hum then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Sprinting or st == Enum.HumanoidStateType.Walking then
            hum:MoveTo(root.Position)
        end
    end
end

function createFovCircle()
    if drawingBroken then return end
    if not Drawing then drawingBroken = true; return end
    if fovCircle then pcall(function() fovCircle:Remove() end); fovCircle = nil end
    local ok, circle = pcall(function() return Drawing.new("Circle") end)
    if not ok or not circle then
        drawingBroken = true; Drawing = nil
        warn("[MissWare Aimbot] Drawing broken, FOV circle disabled")
        return
    end
    fovCircle = circle
    pcall(function()
        fovCircle.Visible, fovCircle.Radius, fovCircle.Thickness = false, 100, 2
        fovCircle.Color, fovCircle.Filled, fovCircle.NumSides = CFG.Accent, false, 60
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)
end

function updateFovCircle()
    AimbotSettings.FOV = math.clamp(AimbotSettings.FOV, 1, 70)
    if not Drawing or drawingBroken or not fovCircle or not Camera then return end
    pcall(function()
        local vs = Camera.ViewportSize
        local cx, cy = vs.X / 2, vs.Y / 2
        fovCircle.Position = Vector2.new(cx, cy)
        if AimbotSettings.SilentAim then fovCircle.Visible = false; return end
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
            local tp, cp = target.Position, Camera.CFrame.Position
            if AimbotSettings.SilentAim then
                Camera.CFrame = CFrame.lookAt(cp, tp)
            else
                local s = AimbotSettings.Smoothness or 0.5
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(cp, tp), s + 0.2)
            end
        end)
    end

    if not AimbotSettings.AutoFire or not target or not currentTargetPlayer then return end
    if currentTargetPlayer == Player or not isPlayerAlive(currentTargetPlayer) then
        currentTarget, currentTargetPlayer = nil, nil; return
    end
    if AimbotSettings.AimMode == "CounterBlox" and isTeammate(currentTargetPlayer) then
        currentTarget, currentTargetPlayer = nil, nil; return
    end
    if not isVisible(target) then return end

    local sp = Camera:WorldToViewportPoint(target.Position)
    if not sp then return end
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    if math.abs(sp.X - cx) > 30 or math.abs(sp.Y - cy) > 30 then return end
    if os.clock() - lastFireTime < AimbotSettings.AutoFireDelay then return end

    if mouse1press then pcall(mouse1press) end
    task.wait(0.01)
    if mouse1release then pcall(mouse1release) end
    lastFireTime = os.clock()
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

local function bindKeyToConfig(k)
    if not k then return nil end
    if typeof(k) == "EnumItem" then
        if k.EnumType == Enum.KeyCode then return {type="KeyCode", name=k.Name} end
        if k == Enum.UserInputType.MouseButton1 then return {type="Mouse", name="M1"} end
        if k == Enum.UserInputType.MouseButton2 then return {type="Mouse", name="M2"} end
    end
    return nil
end

local function configToBindKey(cfg)
    if not cfg or not cfg.type then return nil end
    if cfg.type == "KeyCode" then
        local ok, kc = pcall(function() return Enum.KeyCode[cfg.name] end)
        return ok and kc or nil
    elseif cfg.type == "Mouse" then
        if cfg.name == "M1" then return Enum.UserInputType.MouseButton1 end
        if cfg.name == "M2" then return Enum.UserInputType.MouseButton2 end
    end
    return nil
end

-- ========== DROPDOWN (без изменений, но с сохранением в конфиг) ==========
local activeDropdown = nil

local function createFixedDropdown(parent, text, options, default, order, callback, configKey)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = CFG.PanelLight, BackgroundTransparency = 0.5,
        BorderSizePixel = 0, LayoutOrder = order or 1, ZIndex = 3,
    }, parent)
    corner(holder, 8)
    local hStroke = stroke(holder, CFG.TextDim, 1, 0.8)
    hStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    hStroke.LineJoinMode = Enum.LineJoinMode.Round
    table.insert(GlobalThemeElements, { obj = holder, prop = "BackgroundColor3", base = "PanelLight" })
    table.insert(GlobalColorElements, { obj = hStroke, prop = "Color", base = "Accent" })

    local txt = new("TextLabel", {
        Size = UDim2.new(0.5, -14, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = text, TextColor3 = CFG.Text,
        Font = UI.FontMed, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, holder)
    table.insert(GlobalThemeElements, { obj = txt, prop = "TextColor3", base = "Text" })

    local btn = new("TextButton", {
        Size = UDim2.new(0.5, -14, 0, 26), Position = UDim2.new(0.5, 0, 0.5, -13),
        BackgroundColor3 = CFG.Bg, BackgroundTransparency = 0.1,
        Text = "  " .. tostring(default) .. "  ▼", TextColor3 = CFG.Accent,
        Font = UI.FontBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, ZIndex = 1001,
    }, holder)
    corner(btn, 6)
    local btnStroke = stroke(btn, CFG.TextDim, 1, 0.6)
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.LineJoinMode = Enum.LineJoinMode.Round
    table.insert(GlobalThemeElements, { obj = btn, prop = "BackgroundColor3", base = "Bg" })
    table.insert(GlobalColorElements, { obj = btn, prop = "TextColor3", base = "Accent" })
    table.insert(GlobalColorElements, { obj = btnStroke, prop = "Color", base = "Accent" })

    local state = default
    if configKey then SetConfig(configKey, state) end

    local isOpen, isAnimating = false, false
    local rootGui = _G.MissWare.Gui or parent

    local listFrame = new("Frame", {
        Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = CFG.Bg, BackgroundTransparency = 0,
        BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 999,
    }, rootGui)
    corner(listFrame, 6)
    local listStroke = stroke(listFrame, CFG.Accent, 1, 0.8)
    listStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    listStroke.LineJoinMode = Enum.LineJoinMode.Round
    table.insert(GlobalThemeElements, { obj = listFrame, prop = "BackgroundColor3", base = "Bg" })
    table.insert(GlobalColorElements, { obj = listStroke, prop = "Color", base = "Accent" })

    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, listFrame)

    local blockInputFrame = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Visible = false, ZIndex = 997,
    }, rootGui)

    local dropdownRef

    local function openDropdown()
        if isAnimating or isOpen then return end
        isAnimating, isOpen = true, true
        local btnAbs = btn.AbsolutePosition
        local guiAbs = rootGui.AbsolutePosition or Vector2.new(0, 0)
        local relX = btnAbs.X - guiAbs.X
        local relY = btnAbs.Y - guiAbs.Y + btn.AbsoluteSize.Y + 2
        local itemH, gap, pad = 24, 2, 8
        local targetH = #options * itemH + math.max(0, #options - 1) * gap + pad
        listFrame.Position = UDim2.fromOffset(relX, relY)
        listFrame.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 0)
        listFrame.Visible = true
        blockInputFrame.Visible = true
        local t = tween(listFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(btn.AbsoluteSize.X, targetH)
        })
        if t then t.Completed:Connect(function() isAnimating = false end)
        else isAnimating = false end
    end

    local function closeDropdown()
        if not isOpen or isAnimating then return end
        isAnimating, isOpen = true, false
        blockInputFrame.Visible = false
        local t = tween(listFrame, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(btn.AbsoluteSize.X, 0)
        })
        local function done()
            listFrame.Visible = false
            isAnimating = false
            if activeDropdown == dropdownRef then activeDropdown = nil end
        end
        if t then t.Completed:Connect(done) else done() end
    end

    for i, opt in ipairs(options) do
        local ob = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = CFG.Accent, BackgroundTransparency = 1,
            Text = "  " .. tostring(opt), TextColor3 = CFG.Text,
            Font = UI.FontMed, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false, LayoutOrder = i, ZIndex = 1000,
        }, listFrame)
        corner(ob, 4)
        table.insert(GlobalThemeElements, { obj = ob, prop = "TextColor3", base = "Text" })
        ob.MouseEnter:Connect(function()
            tween(ob, CFG.EaseFast, { BackgroundTransparency = 0.6, BackgroundColor3 = CFG.Accent, TextColor3 = CFG.AccentSoft })
        end)
        ob.MouseLeave:Connect(function()
            tween(ob, CFG.EaseFast, { BackgroundTransparency = 1, TextColor3 = CFG.Text })
        end)
        ob.MouseButton1Click:Connect(function()
            state = opt
            btn.Text = "  " .. tostring(opt) .. "  ▼"
            if configKey then SetConfig(configKey, state) end
            if callback then callback(state) end
            closeDropdown()
        end)
    end

    btn.MouseButton1Click:Connect(function()
        if activeDropdown == dropdownRef then closeDropdown(); return end
        if activeDropdown then activeDropdown:Fire() end
        openDropdown()
        activeDropdown = dropdownRef
    end)
    blockInputFrame.MouseButton1Click:Connect(closeDropdown)

    dropdownRef = {
        Fire = closeDropdown,
        Set = function(v) state = v; btn.Text = "  " .. tostring(v) .. "  ▼"; if configKey then SetConfig(configKey, v) end end,
        Get = function() return state end,
    }
    if configKey then ConfigElements[configKey] = dropdownRef end
    return dropdownRef
end

-- ========== UI CARD ==========
function _G.MissWare.CreateAimbotUI(parent)
    local card = new("Frame", {
        Size = UDim2.new(1, -8, 0, 300), BackgroundColor3 = CFG.Bg, BackgroundTransparency = 0.05,
        BorderSizePixel = 0, LayoutOrder = 1, ZIndex = 10, ClipsDescendants = true,
    }, parent)
    corner(card, 10)
    local cardStroke = stroke(card, CFG.Accent, 1.5, 0.3)
    cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cardStroke.LineJoinMode = Enum.LineJoinMode.Round
    table.insert(GlobalThemeElements, { obj = card, prop = "BackgroundColor3", base = "Bg" })
    table.insert(GlobalColorElements, { obj = cardStroke, prop = "Color", base = "Accent" })

    local header = new("Frame", {
        Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 4),
        BackgroundTransparency = 1, ZIndex = 11,
    }, card)

    local titleLabel = new("TextLabel", {
        Size = UDim2.new(0, 100, 1, 0), BackgroundTransparency = 1,
        Text = "Aimbot", TextColor3 = CFG.Text, Font = UI.FontBold,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12,
    }, header)
    table.insert(GlobalThemeElements, { obj = titleLabel, prop = "TextColor3", base = "Text" })

    -- ===== TOGGLE =====
    local toggle = new("TextButton", {
        Name = "MW_AimbotToggle",
        Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -100, 0, 7),
        BackgroundColor3 = CFG.PanelLight, BackgroundTransparency = 0.2,
        Text = "OFF", TextColor3 = CFG.Text, Font = UI.FontBold, TextSize = 11,
        AutoButtonColor = false, ZIndex = 12,
    }, header)
    corner(toggle, 4)
    local toggleStroke = stroke(toggle, CFG.TextDim, 1, 0.5)
    toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    toggleStroke.LineJoinMode = Enum.LineJoinMode.Round

    -- ===== BIND BUTTON =====
    local bindBtn = new("TextButton", {
        Name = "MW_AimbotBind",
        Size = UDim2.fromOffset(50, 22), Position = UDim2.new(1, -50, 0, 7),
        BackgroundColor3 = CFG.PanelLight, BackgroundTransparency = 0.3,
        Text = formatBind(AimbotSettings.BindKey), TextColor3 = CFG.TextDim,
        Font = UI.FontMed, TextSize = 10, AutoButtonColor = false, ZIndex = 12,
    }, header)
    corner(bindBtn, 4)
    local bindStroke = stroke(bindBtn, CFG.TextDim, 1, 0.6)
    bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bindStroke.LineJoinMode = Enum.LineJoinMode.Round

    -- ===== APPLY VISUALS (с task.defer, чтобы не сбивалось UI-циклом) =====
    local function updateToggleVisual()
        local on = AimbotSettings.Enabled
        task.defer(function()
            if not toggle.Parent then return end
            toggle.Text = on and "ON" or "OFF"
            toggle.TextColor3 = on and CFG.Accent or CFG.Text
            toggle.BackgroundColor3 = CFG.PanelLight
            toggle.BackgroundTransparency = on and 0.1 or 0.2
            toggleStroke.Color = on and CFG.Accent or CFG.TextDim
            toggleStroke.Transparency = on and 0 or 0.5
            toggleStroke.Thickness = 1
        end)
    end

    local function applyBindVisual()
        local hasBind = AimbotSettings.BindKey ~= nil
        task.defer(function()
            if not bindBtn.Parent then return end
            bindBtn.Text = formatBind(AimbotSettings.BindKey)
            bindBtn.TextColor3 = hasBind and CFG.Accent or CFG.TextDim
            bindBtn.BackgroundColor3 = CFG.PanelLight
            bindStroke.Color = hasBind and CFG.Accent or CFG.TextDim
            bindStroke.Transparency = hasBind and 0.2 or 0.6
            bindStroke.Thickness = 1
        end)
    end

    updateToggleVisual()
    applyBindVisual()

    local function setEnabled(v)
        AimbotSettings.Enabled = v
        SetConfig("Aimbot_Enabled", v)
        updateToggleVisual()
        if v then startAimbot() else stopAimbot() end
    end

    toggle.MouseButton1Click:Connect(function() setEnabled(not AimbotSettings.Enabled) end)

    local bindingAimbot = false
    bindBtn.MouseButton1Click:Connect(function()
        if bindingAimbot then return end
        bindingAimbot = true
        bindBtn.Text = "..."
        task.defer(function() bindBtn.TextColor3 = CFG.AccentSoft end)
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if not bindingAimbot or gp then return end
        local chosen = nil
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
            chosen = input.KeyCode
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            chosen = Enum.UserInputType.MouseButton1
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            chosen = Enum.UserInputType.MouseButton2
        end
        if chosen then
            AimbotSettings.BindKey = chosen
            bindingAimbot = false
            applyBindVisual()
            SetConfig("Aimbot_Bind", bindKeyToConfig(chosen))
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not AimbotSettings.BindKey then return end
        local key = AimbotSettings.BindKey
        local pressed = false
        if typeof(key) == "EnumItem" then
            if key.EnumType == Enum.KeyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key then
                pressed = true
            elseif key == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1 then
                pressed = true
            elseif key == Enum.UserInputType.MouseButton2 and input.UserInputType == Enum.UserInputType.MouseButton2 then
                pressed = true
            end
        end
        if pressed then setEnabled(not AimbotSettings.Enabled) end
    end)

    local content = new("Frame", {
        Size = UDim2.new(1, -16, 1, -44), Position = UDim2.fromOffset(8, 40),
        BackgroundTransparency = 1, ClipsDescendants = false, ZIndex = 11,
    }, card)

    local leftCol = new("Frame", { Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 1, ZIndex = 11 }, content)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, leftCol)
    local rightCol = new("Frame", { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), BackgroundTransparency = 1, ZIndex = 11 }, content)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, rightCol)

    createFixedDropdown(leftCol, "Aim Mode", {"FluxoPvP", "Classic", "CounterBlox"}, AimbotSettings.AimMode, 1,
        function(v) AimbotSettings.AimMode = v end, "Aimbot_AimMode")
    createFixedDropdown(leftCol, "Aim Part", {"Head", "Body", "Torso"}, AimbotSettings.AimPart, 2,
        function(v) AimbotSettings.AimPart = v end, "Aimbot_AimPart")

    UI.Slider(leftCol, "Smooth", 1, 10, math.floor(AimbotSettings.Smoothness * 10), 3,
        function(v) AimbotSettings.Smoothness = v / 10 end, "Aimbot_Smooth")
    UI.Slider(leftCol, "FOV", 1, 70, math.clamp(AimbotSettings.FOV, 1, 70), 4,
        function(v) AimbotSettings.FOV = math.clamp(v, 1, 70); updateFovCircle() end, "Aimbot_FOV")
    UI.Slider(leftCol, "Distance", 50, 1000, AimbotSettings.MaxDistance, 5,
        function(v) AimbotSettings.MaxDistance = v end, "Aimbot_Distance")

    UI.Slider(rightCol, "Fire Delay", 1, 50, math.floor(AimbotSettings.AutoFireDelay * 100), 1,
        function(v) AimbotSettings.AutoFireDelay = v / 100 end, "Aimbot_FireDelay")
    UI.Checkbox(rightCol, "Silent Aim", AimbotSettings.SilentAim, 2,
        function(v) AimbotSettings.SilentAim = v; updateFovCircle() end, "Aimbot_Silent")
    UI.Checkbox(rightCol, "Auto Fire", AimbotSettings.AutoFire, 3,
        function(v) AimbotSettings.AutoFire = v end, "Aimbot_AutoFire")
    UI.Checkbox(rightCol, "Auto Stop", AimbotSettings.AutoStop, 4,
        function(v) AimbotSettings.AutoStop = v end, "Aimbot_AutoStop")

    -- Экспорт для UI (вызывается из updateAccent/setTheme, если добавишь)
    _G.MissWare.UpdateAimbotToggle = updateToggleVisual
    _G.MissWare.UpdateAimbotBind   = applyBindVisual

    -- Загрузка сохранённых значений из ConfigElements (после регистрации всех элементов)
    task.defer(function()
        local function applyIf(key, setter)
            if ConfigData and ConfigData[key] ~= nil and setter then
                pcall(setter, ConfigData[key])
            end
        end
        -- ConfigData доступен через UI? Нет — UI хранит локально. Используем ConfigElements.
        local function fromCE(key)
            local ce = ConfigElements[key]
            if ce and ce.Get then return ce:Get() end
            return nil
        end

        -- Aimbot_Enabled
        local en = fromCE("Aimbot_Enabled")
        if en ~= nil then setEnabled(en) end
        -- Aim Mode / Part
        local am = fromCE("Aimbot_AimMode"); if am then AimbotSettings.AimMode = am end
        local ap = fromCE("Aimbot_AimPart"); if ap then AimbotSettings.AimPart = ap end
        -- Smooth / FOV / Distance / FireDelay
        local sm = fromCE("Aimbot_Smooth"); if sm then AimbotSettings.Smoothness = sm / 10 end
        local fv = fromCE("Aimbot_FOV"); if fv then AimbotSettings.FOV = fv; updateFovCircle() end
        local ds = fromCE("Aimbot_Distance"); if ds then AimbotSettings.MaxDistance = ds end
        local fd = fromCE("Aimbot_FireDelay"); if fd then AimbotSettings.AutoFireDelay = fd / 100 end
        -- Checkboxes
        local sa = fromCE("Aimbot_Silent"); if sa ~= nil then AimbotSettings.SilentAim = sa; updateFovCircle() end
        local af = fromCE("Aimbot_AutoFire"); if af ~= nil then AimbotSettings.AutoFire = af end
        local as = fromCE("Aimbot_AutoStop"); if as ~= nil then AimbotSettings.AutoStop = as end
        -- Bind
        local bd = fromCE("Aimbot_Bind")
        if bd then
            local k = configToBindKey(bd)
            if k then AimbotSettings.BindKey = k; applyBindVisual() end
        end
    end)
end

_G.MissWare.AimbotSettings = AimbotSettings
_G.MissWare.startAimbot = startAimbot
_G.MissWare.stopAimbot = stopAimbot
_G.MissWare.updateFovCircle = updateFovCircle
print("[MissWare] Aimbot loaded (v28)")
