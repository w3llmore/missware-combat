-- combat/aimbot.lua
-- Полный модуль Aimbot (Логика + UI + Цвета + Темы)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local Drawing = Drawing or nil

-- Получаем UI-функции из главного скрипта
local UI = _G.MissWare.UI
if not UI or not UI.CFG then return warn("UI functions or CFG not found!") end
local new = UI.New
local corner = UI.Corner
local stroke = UI.Stroke
local gradient = UI.Gradient
local checkbox = UI.Checkbox
local slider = UI.Slider
local dropdown = UI.Dropdown
local CFG = UI.CFG

-- Настройки аимбота
local Settings = {
    Enabled = false, AimPart = "Head", AimMode = "Classic", FOV = 10,
    Smoothness = 0.3, SilentAim = false, AutoFire = false, AutoStop = false,
    MaxDistance = 400, AutoFireDelay = 0.05
}
_G.MissWare.Settings.Aimbot = Settings

-- Переменные для логики
local AB = { fovCircle = nil, conn = nil, lastFire = 0, target = nil, targetPlr = nil }

-- Переменные для хранения UI элементов (чтобы перекрашивать)
local UI_Elements = {
    Card = nil,
    CardStroke = nil,
    CardTitle = nil,
    CardLine = nil,
    Dropdowns = {}
}

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
    if not Settings.Enabled then
        if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
        return
    end
    if not Camera then return end
    UpdateFovCircle()

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
    CreateFovCircle()
    AB.conn = RunService.RenderStepped:Connect(mainLoop)
end

_G.MissWare.StopAimbot = function()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
end

_G.MissWare.UpdateFovCircle = UpdateFovCircle

-- ============ ОТРИСОВКА UI КАРТОЧКИ ============
_G.MissWare.CreateAimbotUI = function(parentFrame)
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 320),
        BackgroundColor3 = CFG.PanelLight, -- Берем цвет из текущей темы
        BackgroundTransparency = 0.7,       -- Блюр
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ZIndex = 3,
    }, parentFrame)
    corner(card, 10)
    UI_Elements.Card = card
    
    UI_Elements.CardStroke = stroke(card, CFG.Accent, 1, 0.4)
    if _G.MissWare.GlobalColorElements then
        table.insert(_G.MissWare.GlobalColorElements, { obj = UI_Elements.CardStroke, prop = "Color", base = "Accent" })
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
    UI_Elements.CardTitle = title
    if _G.MissWare.GlobalColorElements then
        table.insert(_G.MissWare.GlobalColorElements, { obj = title, prop = "TextColor3", base = "AccentSoft" })
    end
    
    local line = new("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.new(0, 10, 0, 36),
        BackgroundColor3 = CFG.Accent,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, card)
    
    UI_Elements.CardLine = gradient(line, CFG.Accent, CFG.AccentDark, 0) 
    if _G.MissWare.GlobalColorElements then
        table.insert(_G.MissWare.GlobalColorElements, { obj = line, prop = "BackgroundColor3", base = "Accent" })
        table.insert(_G.MissWare.GlobalColorElements, { obj = UI_Elements.CardLine, prop = "Color", base = "Gradient" })
    end
    
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
    
    local dd1 = dropdown(left, "Aim Part", {"Head", "HumanoidRootPart", "Torso"}, "Head", 4, function(val)
        Settings.AimPart = val
    end, "Combat_AimPart")
    table.insert(UI_Elements.Dropdowns, dd1)
    
    -- ВОЗВРАЩАЕМ РЕЖИМ FLUXOPVP
    local dd2 = dropdown(right, "Aim Mode", {"Classic", "CounterBlox", "FluxoPvP"}, "Classic", 3, function(val)
        Settings.AimMode = val
    end, "Combat_AimMode")
    table.insert(UI_Elements.Dropdowns, dd2)
end

-- Функция обновления при смене АКЦЕНТА (Цвета)
_G.MissWare.UpdateAimbotAccent = function()
    if UI_Elements.CardStroke then UI_Elements.CardStroke.Color = CFG.Accent end
    if UI_Elements.CardTitle then UI_Elements.CardTitle.TextColor3 = CFG.AccentSoft end
    if UI_Elements.CardLine then UI_Elements.CardLine.Color = ColorSequence.new(CFG.Accent, CFG.AccentDark) end
    
    for _, dd in ipairs(UI_Elements.Dropdowns) do
        if dd and dd.UpdateColor then dd.UpdateColor() end
    end
end

-- Функция обновления при смене ТЕМЫ (Dark/Light)
_G.MissWare.UpdateAimbotTheme = function()
    if UI_Elements.Card then 
        UI_Elements.Card.BackgroundColor3 = CFG.PanelLight 
    end
    if UI_Elements.CardTitle then 
        UI_Elements.CardTitle.TextColor3 = CFG.AccentSoft 
    end
end
