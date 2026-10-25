-- combat/aimbot.lua
-- Модуль Aimbot (сам рисует карточку и запускает логику)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local Drawing = Drawing or nil

-- Забираем UI-функции из главного скрипта
local UI = _G.MissWare.UI
if not UI then return warn("UI functions not found!") end
local new = UI.New
local corner = UI.Corner
local stroke = UI.Stroke
local gradient = UI.Gradient
local checkbox = UI.Checkbox
local slider = UI.Slider
local dropdown = UI.Dropdown
local CFG = UI.CFG

-- Настройки
local Settings = {
    Enabled = false, AimPart = "Head", AimMode = "Classic", FOV = 10,
    Smoothness = 0.3, SilentAim = false, AutoFire = false, AutoStop = false,
    MaxDistance = 400, AutoFireDelay = 0.05
}
_G.MissWare.Settings.Aimbot = Settings

local AB = { fovCircle = nil, conn = nil, lastFire = 0, target = nil, targetPlr = nil }

-- [ВСТАВЬ СЮДА СВОИ ЛОКАЛЬНЫЕ ФУНКЦИИ: isPlayerAlive, isTeammate, isVisible, getTargetPart, getClosestEnemy, applyAutoStop]
-- ...

-- Функции FOV круга
local function CreateFovCircle()
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

local function UpdateFovCircle()
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
    -- [ВСТАВЬ СЮДА ЛОГИКУ mainLoop ИЗ ТВОЕГО СТАРОГО КОДА]
end

-- Функция запуска (вызывается из UI)
_G.MissWare.StartAimbot = function()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
    CreateFovCircle()
    AB.conn = RunService.RenderStepped:Connect(mainLoop)
end

_G.MissWare.StopAimbot = function()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
end

-- ============ ОТРИСОВКА UI КАРТОЧКИ ============
_G.MissWare.CreateAimbotUI = function(parentFrame)
    -- Сама карточка
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
    table.insert(_G.MissWare.GlobalColorElements, { obj = cardStroke, prop = "Color", base = "Accent" })
    
    -- Заголовок
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
    
    -- Линия
    local line = new("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.new(0, 10, 0, 36),
        BackgroundColor3 = CFG.Accent,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, card)
    gradient(line, CFG.Accent, Color3.fromRGB(0,0,0), 0)
    
    -- Две колонки
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
    
    -- Создаем элементы
    checkbox(left, "Enable Aimbot", false, 1, function(state)
        Settings.Enabled = state
        if state then _G.MissWare.StartAimbot() else _G.MissWare.StopAimbot() end
    end, "Combat_Aimbot")
    
    checkbox(left, "Silent Aim", false, 2, function(state)
        Settings.SilentAim = state
        UpdateFovCircle()
    end, "Combat_SilentAim")
    
    checkbox(left, "Auto Fire", false, 3, function(state)
        Settings.AutoFire = state
    end, "Combat_AutoFire")
    
    slider(right, "FOV", 1, 360, 10, 1, function(val)
        Settings.FOV = val
        UpdateFovCircle()
    end, "Combat_FOV")
    
    slider(right, "Smoothness", 1, 100, 30, 2, function(val)
        Settings.Smoothness = val / 100
    end, "Combat_Smooth")
    
    dropdown(left, "Aim Part", {"Head", "HumanoidRootPart", "Torso"}, "Head", 4, function(val)
        Settings.AimPart = val
    end, "Combat_AimPart")
    
    dropdown(right, "Aim Mode", {"Classic", "CounterBlox"}, "Classic", 3, function(val)
        Settings.AimMode = val
    end, "Combat_AimMode")
end
