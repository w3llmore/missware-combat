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
    TeamCheck = false, MaxDistance = 500
}

local ESP = {
    conn = nil, activeHighlights = {}, activeNames = {}, activeHealthBars = {},
    visibilityCache = {}, frameCounter = 0, newEspEnabled = false, espData = {}, toggle = nil,
}

-- ====== ОБЩИЙ КОЛОРПИКЕР (ОТДЕЛЬНЫЙ ScreenGui) ======
local ColorPickerGui = nil
local function createColorPicker(btn, currentColor, callback)
    local colorPickerVisible = false
    btn.MouseButton1Click:Connect(function()
        if colorPickerVisible then return end
        colorPickerVisible = true

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
            colorPickerVisible = false
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

-- (Дальше идет остальная логика ESP - она без изменений)
local function isRealPlayer(plr) ... end
local function isPlayerAlive(plr) ... end
local function isPlayerAlive2(plr) ... end
local function isSameTeam(plr) ... end
local function espIsTeammate(plr) ... end
local function getPlayerParts(plr) ... end
local function isPlayerVisible(plr) ... end
local function createNewESP(plr) ... end
local function removeNewESP(plr) ... end
local function setNewESPVisible(v) ... end
local function updateNewESP() ... end
local function isTargetVisible(char, now) ... end
local function updateClassicESP() ... end
local function clearAllESP() ... end
local function updateESP() ... end

function _G.startESP() ... end
function _G.stopESP() ... end

-- (Карточка ESP с вызовом createColorPicker)
_G.createESPCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20,20,20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 420)
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
    createSlider(content, "Max Distance", 100, 1000, ESPSettings.MaxDistance, "m", function(v) ESPSettings.MaxDistance = v end)
end

_G.ESPSettings = ESPSettings
