-- render/esp.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local Drawing = Drawing or nil

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() Camera = Workspace.CurrentCamera end)

local MissWare = _G.MissWare or {}
local ACCENT_COLORS = MissWare.ACCENT_COLORS or {Default = Color3.new(1,1,1)}
local currentAccentColor = MissWare.currentAccentColor or "Default"
local createSlider = MissWare.createSlider or function() end
local createCheckbox = MissWare.createCheckbox or function() end
local createDropdown = MissWare.createDropdown or function() end

local ESPSettings = {
    Enabled = false, Mode = "Classic",
    ChamsVisibleColor = Color3.fromRGB(0, 255, 0), ChamsHiddenColor = Color3.fromRGB(255, 0, 0),
    HealthBar = false, NameESP = false, NameColor = Color3.fromRGB(255, 255, 255),
    TeamCheck = false, MaxDistance = 2000
}

local ESP = {
    conn = nil, activeDrawings = {},
    visibilityCache = {}, frameCounter = 0, toggle = nil,
}

-- ====== КОЛОРПИКЕР ======
local ColorPickerGui = nil
local function createColorPicker(btn, currentColor, callback)
    local isOpen = false
    btn.MouseButton1Click:Connect(function()
        if isOpen then return end
        isOpen = true
        if not ColorPickerGui then
            ColorPickerGui = Instance.new("ScreenGui")
            ColorPickerGui.Name = "MissWare_ESP_ColorPicker"
            ColorPickerGui.ResetOnSpawn = false
            ColorPickerGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
            ColorPickerGui.Parent = CoreGui
        end
        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.5
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 999
        overlay.Parent = ColorPickerGui
        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, 240, 0, 0)
        popup.Position = UDim2.new(0.5, -120, 0.5, -120)
        popup.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        popup.BackgroundTransparency = 1
        popup.ClipsDescendants = true
        popup.ZIndex = 1000
        popup.Parent = overlay
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 12)
        local stroke = Instance.new("UIStroke", popup)
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(60, 60, 75)
        stroke.Transparency = 1
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.new(0, 10, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = "Select Color"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 16
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = popup
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -30, 0, 8)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.Parent = popup
        local function closePopup()
            isOpen = false
            TweenService:Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, -120), BackgroundTransparency = 1
            }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 1}):Play()
            task.wait(0.15)
            overlay:Destroy()
        end
        closeBtn.MouseButton1Click:Connect(closePopup)
        local colorContainer = Instance.new("Frame")
        colorContainer.Size = UDim2.new(1, -20, 0, 0)
        colorContainer.Position = UDim2.new(0, 10, 0, 45)
        colorContainer.BackgroundTransparency = 1
        colorContainer.Parent = popup
        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.new(0, 38, 0, 38)
        grid.CellPadding = UDim2.new(0, 6, 0, 6)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = colorContainer
        local colorData = {
            Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 150, 255),
            Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 150, 0),
            Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 100, 100),
            Color3.fromRGB(100, 200, 255), Color3.fromRGB(200, 255, 100), Color3.fromRGB(180, 130, 255),
            Color3.fromRGB(0, 0, 0), Color3.fromRGB(128, 128, 128), Color3.fromRGB(255, 200, 200)
        }
        for i, color in ipairs(colorData) do
            local cBtn = Instance.new("TextButton")
            cBtn.BackgroundColor3 = color
            cBtn.Text = ""
            cBtn.AutoButtonColor = false
            cBtn.ZIndex = 1000
            cBtn.LayoutOrder = i
            cBtn.Parent = colorContainer
            Instance.new("UICorner", cBtn).CornerRadius = UDim.new(1, 0)
            if color == currentColor then
                local b = Instance.new("UIStroke", cBtn)
                b.Thickness = 2
                b.Color = Color3.fromRGB(255, 255, 255)
            end
            cBtn.MouseButton1Click:Connect(function()
                callback(color)
                btn.BackgroundColor3 = color
                closePopup()
            end)
        end
        local rows = math.ceil(#colorData / 5)
        local height = 45 + rows * 44 + 15
        popup.Size = UDim2.new(0, 240, 0, height)
        colorContainer.Size = UDim2.new(1, -20, 0, rows * 44)
        popup.BackgroundTransparency = 1
        popup.Size = UDim2.new(0, 0, 0, 0)
        stroke.Transparency = 1
        TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 240, 0, height), BackgroundTransparency = 0
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
        local function checkClickOutside(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mp = UserInputService:GetMouseLocation()
                local ap = popup.AbsolutePosition
                local as = popup.AbsoluteSize
                if not (mp.X >= ap.X and mp.X <= ap.X + as.X and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y) then
                    closePopup()
                end
            end
        end
        overlay.InputBegan:Connect(checkClickOutside)
    end)
end

-- ====== БАЗА ======
local function isRealPlayer(plr)
    if not plr or typeof(plr) ~= "Instance" or not plr:IsA("Player") or not plr.Parent then return false end
    if plr == Player then return false end
    return true
end

local function isPlayerAlive(plr)
    if not isRealPlayer(plr) or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isSameTeam(plr)
    if plr == Player then return true end
    if plr.Team and Player.Team and plr.Team == Player.Team then return true end
    if plr.TeamColor and Player.TeamColor and plr.TeamColor == Player.TeamColor then return true end
    return false
end

local function espIsTeammate(plr)
    local forceTeamCheck = (ESPSettings.Mode == "CounterBlox")
    if not ESPSettings.TeamCheck and not forceTeamCheck then return false end
    return isSameTeam(plr)
end

-- ====== ВИДИМОСТЬ (КЭШ) ======
local function isTargetVisible(char, now)
    if not char or not char.Parent then return true end
    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not head and not root then return true end
    local cached = ESP.visibilityCache[char]
    if cached and now - cached.time < 0.15 then return cached.visible end
    
    local camera = Camera; if not camera then return true end
    local origin = camera.CFrame.Position
    local ignoreList = {char}
    if Player.Character then table.insert(ignoreList, Player.Character) end
    
    local checkPoints = {}
    if head then table.insert(checkPoints, head.Position) end
    if root then table.insert(checkPoints, root.Position) end
    
    local visible = false
    for _, point in ipairs(checkPoints) do
        local dir = point - origin
        local dist = dir.Magnitude
        if dist > 0.01 then
            local ray = Ray.new(origin, dir.Unit * dist)
            local ok, hit = pcall(function() return Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList) end)
            if ok and (not hit or hit == head or hit == root or (hit and hit:IsDescendantOf(char))) then
                visible = true
                break
            end
        end
    end
    ESP.visibilityCache[char] = {visible = visible, time = now}
    return visible
end

-- ====== РИСОВАНИЕ (2D) ======
local function createDrawing(plr)
    if not Drawing then return end
    ESP.activeDrawings[plr] = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        health = Drawing.new("Text"),
        heart = Drawing.new("Text"),
    }
    local d = ESP.activeDrawings[plr]
    d.box.Thickness = 1; d.box.Filled = false; d.box.Visible = false
    d.name.Size = 13; d.name.Center = true; d.name.Outline = true; d.name.Font = 2; d.name.Visible = false
    d.health.Size = 16; d.health.Center = true; d.health.Outline = true; d.health.Font = 3; d.health.Visible = false
    d.heart.Size = 14; d.heart.Center = true; d.heart.Outline = true; d.heart.Font = 3; d.heart.Text = "♥"; d.heart.Visible = false
end

local function removeDrawing(plr)
    local d = ESP.activeDrawings[plr]
    if d then
        if d.box then d.box:Remove() end
        if d.name then d.name:Remove() end
        if d.health then d.health:Remove() end
        if d.heart then d.heart:Remove() end
        ESP.activeDrawings[plr] = nil
    end
end

local function updateDrawingESP()
    if not Drawing then return end
    local now = tick()
    local camera = Camera
    if not camera then return end
    local vs = camera.ViewportSize
    local camPos = camera.CFrame.Position
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if not isRealPlayer(plr) then continue end
        
        if not ESP.activeDrawings[plr] then createDrawing(plr) end
        local d = ESP.activeDrawings[plr]
        
        if not isPlayerAlive(plr) or espIsTeammate(plr) then
            d.box.Visible = false; d.name.Visible = false; d.health.Visible = false; d.heart.Visible = false
            continue
        end
        
        local char = plr.Character
        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not head or not root then continue end
        
        local dist = (camPos - head.Position).Magnitude
        if dist > ESPSettings.MaxDistance then
            d.box.Visible = false; d.name.Visible = false; d.health.Visible = false; d.heart.Visible = false
            continue
        end
        
        -- 2D бокс (по голове и root)
        local headScreen, headOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local rootScreen, rootOn = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))
        
        if headOn and rootOn and headScreen.Z > 0 and rootScreen.Z > 0 then
            local h = math.abs(rootScreen.Y - headScreen.Y)
            local w = h * 0.6
            d.box.Size = Vector2.new(w, h)
            d.box.Position = Vector2.new(headScreen.X - w/2, headScreen.Y)
            
            local isVis = isTargetVisible(char, now)
            d.box.Color = isVis and ESPSettings.ChamsVisibleColor or ESPSettings.ChamsHiddenColor
            d.box.Visible = true
            
            -- Имя
            if ESPSettings.NameESP then
                d.name.Text = plr.Name .. " [" .. math.floor(dist) .. "m]"
                d.name.Position = Vector2.new(headScreen.X, headScreen.Y - 16)
                d.name.Color = ESPSettings.NameColor
                d.name.Visible = true
            else
                d.name.Visible = false
            end
            
            -- Health
            if ESPSettings.HealthBar then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    d.health.Text = tostring(math.floor(hum.Health))
                    d.health.Position = Vector2.new(headScreen.X + 20, headScreen.Y + h/2)
                    d.health.Color = hp > 0.5 and Color3.fromRGB(0,255,120) or (hp > 0.3 and Color3.fromRGB(255,220,0) or Color3.fromRGB(255,60,60))
                    d.health.Visible = true
                    d.heart.Position = Vector2.new(headScreen.X - 20, headScreen.Y + h/2)
                    d.heart.Visible = true
                end
            else
                d.health.Visible = false; d.heart.Visible = false
            end
        else
            d.box.Visible = false; d.name.Visible = false; d.health.Visible = false; d.heart.Visible = false
        end
    end
end

local function clearAllESP()
    for plr, _ in pairs(ESP.activeDrawings) do removeDrawing(plr) end
    ESP.activeDrawings = {}
    ESP.visibilityCache = {}
end

local function updateESP()
    if not ESPSettings.Enabled then
        if next(ESP.activeDrawings) then clearAllESP() end
        return
    end
    ESP.frameCounter = ESP.frameCounter + 1
    
    -- Оптимизация: 30 FPS (каждый 2-й кадр)
    if ESP.frameCounter % 2 == 0 then
        updateDrawingESP()
    end
end

function _G.startESP()
    if ESP.conn then ESP.conn:Disconnect() end
    ESP.conn = RunService.Heartbeat:Connect(updateESP)
end

function _G.stopESP()
    if ESP.conn then ESP.conn:Disconnect(); ESP.conn = nil end
    clearAllESP()
end

Players.PlayerRemoving:Connect(function(plr) removeDrawing(plr) end)

-- ====== CARD ======
_G.createESPCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20,20,20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 370)
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cs = Instance.new("UIStroke", card)
    cs.Thickness = 1
    cs.Color = Color3.fromRGB(45,45,55)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -16, 0, 36)
    header.Position = UDim2.new(0, 8, 0, 4)
    header.BackgroundTransparency = 1
    header.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 100, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "ESP"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -100, 0, 7)
    toggle.BackgroundColor3 = Color3.fromRGB(70,70,80)
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(255,255,255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.AutoButtonColor = false
    toggle.Parent = header
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    ESP.toggle = toggle
    toggle.MouseButton1Click:Connect(function()
        ESPSettings.Enabled = not ESPSettings.Enabled
        toggle.Text = ESPSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = ESPSettings.Enabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(70,70,80)
        if ESPSettings.Enabled then _G.startESP() else _G.stopESP() end
    end)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 3
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.Parent = card

    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 4)
    cl.Parent = content
    cl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() content.CanvasSize = UDim2.new(0, 0, 0, cl.AbsoluteContentSize.Y + 20) end)

    createDropdown(content, "Mode", {"Classic", "Operation 1", "CounterBlox"}, ESPSettings.Mode, function(v) ESPSettings.Mode = v; if ESPSettings.Enabled then _G.stopESP(); _G.startESP() end end)

    local function colorRowCreate(labelText, colorVal, onPick)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.Parent = content
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 110, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(180,180,190)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = row
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 25, 0, 22)
        btn.Position = UDim2.new(1, -30, 0, 2)
        btn.BackgroundColor3 = colorVal
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        createColorPicker(btn, colorVal, onPick)
    end

    colorRowCreate("Visible Color", ESPSettings.ChamsVisibleColor, function(c) ESPSettings.ChamsVisibleColor = c end)
    colorRowCreate("Hidden Color", ESPSettings.ChamsHiddenColor, function(c) ESPSettings.ChamsHiddenColor = c end)
    colorRowCreate("Name Color", ESPSettings.NameColor, function(c) ESPSettings.NameColor = c end)

    createCheckbox(content, "Health Bar", ESPSettings.HealthBar, function(v) ESPSettings.HealthBar = v end)
    createCheckbox(content, "Name ESP", ESPSettings.NameESP, function(v) ESPSettings.NameESP = v end)
    createCheckbox(content, "Team Check", ESPSettings.TeamCheck, function(v) ESPSettings.TeamCheck = v end)
    createSlider(content, "Max Distance", 100, 2000, ESPSettings.MaxDistance, "m", function(v) ESPSettings.MaxDistance = v end)
end

_G.ESPSettings = ESPSettings
