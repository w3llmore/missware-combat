-- combat/aimbot.lua
-- MissWare Aimbot Module

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local Drawing = Drawing or nil

-- Получаем доступ к UI и данным из главного файла
local MissWare = _G.MissWare or {}
local ACCENT_COLORS = MissWare.ACCENT_COLORS or {Default = Color3.new(1,1,1)}
local currentAccentColor = MissWare.currentAccentColor or "Default"
local createSlider = MissWare.createSlider
local createCheckbox = MissWare.createCheckbox
local createDropdown = MissWare.createDropdown
local captureKeybind = MissWare.captureKeybind
local createFovCircleFn = MissWare.createFovCircle

local AimbotSettings = {
    Enabled = false,
    AimPart = "Head",
    AimMode = "Classic",
    FOV = 10,
    Smoothness = 0.3,
    SilentAim = false,
    AutoFire = false,
    AutoStop = false,
    MaxDistance = 400,
    AutoFireDelay = 0.05,
    BindKey = nil,
}

local AB = {
    fovCircle = nil,
    conn = nil,
    lastFire = 0,
    target = nil,
    targetPlr = nil,
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
    if best then AB.targetPlr = bestPlayer end
    return best
end

local function applyAutoStop()
    if not AimbotSettings.AutoStop or not AimbotSettings.Enabled or not AB.target then return end
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

function _G.createFovCircle()
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

function _G.updateFovCircle()
    if not Drawing or not AB.fovCircle or not Camera then return end
    pcall(function()
        local vs = Camera.ViewportSize
        local cx, cy = vs.X/2, vs.Y/2
        AB.fovCircle.Position = Vector2.new(cx, cy)
        if AimbotSettings.SilentAim then AB.fovCircle.Visible = false; return end
        local aimRad = math.rad(AimbotSettings.FOV)/2
        local camRad = math.rad(Camera.FieldOfView)/2
        local r = (math.tan(aimRad)/math.tan(camRad)) * cx
        AB.fovCircle.Radius = math.clamp(r, 5, cx-10)
        AB.fovCircle.Visible = AimbotSettings.Enabled
    end)
end

local function mainLoop()
    if not AimbotSettings.Enabled then
        if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
        return
    end
    if not Camera then return end
    _G.updateFovCircle()

    local target = getClosestEnemy()
    if target then AB.target = target else AB.target = nil; AB.targetPlr = nil end
    applyAutoStop()

    if AB.target then
        pcall(function()
            local targetPos = AB.target.Position
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

    if not AimbotSettings.AutoFire or not AB.target or not AB.targetPlr then return end
    local plr = AB.targetPlr
    if plr == Player or not isPlayerAlive(plr) then AB.target = nil; AB.targetPlr = nil; return end
    if AimbotSettings.AimMode == "CounterBlox" and isTeammate(plr) then AB.target = nil; AB.targetPlr = nil; return end
    if not isVisible(AB.target) then return end

    local screenPos = Camera:WorldToViewportPoint(AB.target.Position)
    if not screenPos then return end
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    if math.abs(screenPos.X - cx) > 30 or math.abs(screenPos.Y - cy) > 30 then return end
    if tick() - AB.lastFire < AimbotSettings.AutoFireDelay then return end

    if mouse1press then pcall(mouse1press) end
    task.wait(0.01)
    if mouse1release then pcall(mouse1release) end
    AB.lastFire = tick()
end

function _G.startAimbot()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
    _G.createFovCircle()
    AB.conn = RunService.RenderStepped:Connect(mainLoop)
end

function _G.stopAimbot()
    if AB.conn then AB.conn:Disconnect(); AB.conn = nil end
    if AB.fovCircle then pcall(function() AB.fovCircle.Visible = false end) end
    AB.target = nil; AB.targetPlr = nil; AB.lastFire = 0
end

_G.createAimbotCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 375)
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cs = Instance.new("UIStroke", card)
    cs.Thickness = 1
    cs.Color = Color3.fromRGB(45, 45, 55)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -16, 0, 36)
    header.Position = UDim2.new(0, 8, 0, 4)
    header.BackgroundTransparency = 1
    header.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 100, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Aimbot"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -100, 0, 7)
    toggle.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    toggle.BackgroundTransparency = 0
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.AutoButtonColor = false
    toggle.Parent = header
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    _G.AimbotToggle = toggle
    toggle.MouseButton1Click:Connect(function()
        AimbotSettings.Enabled = not AimbotSettings.Enabled
        toggle.Text = AimbotSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = AimbotSettings.Enabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 80)
        _G.updateFovCircle()
    end)

    local bindBtn = Instance.new("TextButton")
    bindBtn.Size = UDim2.new(0, 50, 0, 22)
    bindBtn.Position = UDim2.new(1, -50, 0, 7)
    bindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bindBtn.BackgroundTransparency = 0
    bindBtn.Text = AimbotSettings.BindKey and AimbotSettings.BindKey.Name or "Bind"
    bindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    bindBtn.Font = Enum.Font.Gotham
    bindBtn.TextSize = 10
    bindBtn.AutoButtonColor = false
    bindBtn.Parent = header
    Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0, 4)
    bindBtn.MouseButton1Click:Connect(function()
        captureKeybind(function(k)
            AimbotSettings.BindKey = k
            bindBtn.Text = k.Name
        end, function()
            AimbotSettings.BindKey = nil
            bindBtn.Text = "Bind"
        end)
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = card
    local contentList = Instance.new("UIListLayout")
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.Padding = UDim.new(0, 6)
    contentList.Parent = content

    createDropdown(content, "Aim Mode", {"FluxoPvP", "Classic", "CounterBlox"}, AimbotSettings.AimMode, function(val) AimbotSettings.AimMode = val end)
    createDropdown(content, "Aim Part", {"Head", "Body", "Torso"}, AimbotSettings.AimPart, function(val) AimbotSettings.AimPart = val end)
    createSlider(content, "FOV", 1, 90, AimbotSettings.FOV, "°", function(val) AimbotSettings.FOV = val; _G.updateFovCircle() end)
    createSlider(content, "Smooth", 0.1, 1.0, AimbotSettings.Smoothness, "", function(val) AimbotSettings.Smoothness = val end)
    createSlider(content, "Distance", 50, 1000, AimbotSettings.MaxDistance, "m", function(val) AimbotSettings.MaxDistance = val end)
    createSlider(content, "Fire Delay", 0.01, 0.5, AimbotSettings.AutoFireDelay, "s", function(val) AimbotSettings.AutoFireDelay = val end)
    createCheckbox(content, "Silent Aim", AimbotSettings.SilentAim, function(val) AimbotSettings.SilentAim = val; _G.updateFovCircle() end)
    createCheckbox(content, "Auto Fire", AimbotSettings.AutoFire, function(val) AimbotSettings.AutoFire = val end)
    createCheckbox(content, "Auto Stop", AimbotSettings.AutoStop, function(val) AimbotSettings.AutoStop = val end)
end

-- Экспорт для главного файла
_G.AimbotSettings = AimbotSettings
