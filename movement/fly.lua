-- movement/fly.lua
-- MissWare Fly Module (static model, no physics)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

local MissWare = _G.MissWare or {}
local createSlider = MissWare.createSlider or function() end
local captureKeybind = MissWare.captureKeybind or function() end

local FlySettings = {
    Enabled = false,
    Speed = 100,
    MaxSpeed = 300,
    BindKey = nil
}

local FLY = {
    conn = nil,
    toggle = nil,
    origAnchored = {},
    origCanCollide = {},
    origPlatformStand = nil,
}

local function saveOriginalState(char)
    if not char then return end
    FLY.origAnchored = {}
    FLY.origCanCollide = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            FLY.origAnchored[part] = part.Anchored
            FLY.origCanCollide[part] = part.CanCollide
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        FLY.origPlatformStand = hum.PlatformStand
    end
end

local function restoreOriginalState(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored = FLY.origAnchored[part] or false
                part.CanCollide = FLY.origCanCollide[part] == nil and true or FLY.origCanCollide[part]
            end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.PlatformStand = FLY.origPlatformStand or false
        end)
    end
    FLY.origAnchored = {}
    FLY.origCanCollide = {}
    FLY.origPlatformStand = nil
end

local function applyFly()
    local char = Player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or not Camera then return end

    humanoid.PlatformStand = true

    -- Анкорим все части, чтобы физика не двигала модель
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored = true
                part.CanCollide = false
                part.Velocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    -- Считаем направление движения
    local moveDir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

    local speedMult = 1.0
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then speedMult = 1.8 end

    -- Двигаем модель через CFrame напрямую (анкоренная не двигается физикой)
    if moveDir.Magnitude > 0 then
        local delta = moveDir.Unit * FlySettings.Speed * speedMult * (1 / 60) -- примерно на кадр
        pcall(function()
            hrp.CFrame = hrp.CFrame + delta
        end)
    end
end

function _G.startFly()
    if FLY.conn then FLY.conn:Disconnect() end
    local char = Player.Character
    saveOriginalState(char)
    applyFly() -- сразу заанкорить
    FLY.conn = RunService.Heartbeat:Connect(function()
        if not FlySettings.Enabled then return end
        pcall(applyFly)
    end)
end

function _G.stopFly()
    if FLY.conn then FLY.conn:Disconnect(); FLY.conn = nil end
    local char = Player.Character
    restoreOriginalState(char)
end

-- На респавне — сохраняем заново
Player.CharacterAdded:Connect(function()
    if FlySettings.Enabled then
        task.wait(0.3)
        local char = Player.Character
        saveOriginalState(char)
        applyFly()
    end
end)

_G.createFlyCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 90)
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

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 100, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Fly"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

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
    FLY.toggle = toggle
    toggle.MouseButton1Click:Connect(function()
        FlySettings.Enabled = not FlySettings.Enabled
        toggle.Text = FlySettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = FlySettings.Enabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 80)
        if FlySettings.Enabled then _G.startFly() else _G.stopFly() end
    end)

    local bind = Instance.new("TextButton")
    bind.Size = UDim2.new(0, 50, 0, 22)
    bind.Position = UDim2.new(1, -50, 0, 7)
    bind.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bind.BackgroundTransparency = 0
    bind.Text = "Bind"
    bind.TextColor3 = Color3.fromRGB(200, 200, 200)
    bind.Font = Enum.Font.Gotham
    bind.TextSize = 10
    bind.AutoButtonColor = false
    bind.Parent = header
    Instance.new("UICorner", bind).CornerRadius = UDim.new(0, 4)
    bind.MouseButton1Click:Connect(function()
        captureKeybind(function(k)
            FlySettings.BindKey = k
            bind.Text = k.Name
        end, function()
            FlySettings.BindKey = nil
            bind.Text = "Bind"
        end)
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = card
    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 4)
    cl.Parent = content

    createSlider(content, "Speed", 10, 500, FlySettings.Speed, "", function(v) FlySettings.Speed = v end)
end

_G.FlySettings = FlySettings
_G.FlyToggle = FLY.toggle
