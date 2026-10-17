-- movement/noclip.lua
-- MissWare Noclip Module (hard noclip with CFrame movement)

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
local captureKeybind = MissWare.captureKeybind or function() end
local createSlider = MissWare.createSlider or function() end

local NoclipSettings = {
    Enabled = false,
    Speed = 60,
    BindKey = nil
}

local NC = {
    conn = nil,
    toggle = nil,
    origAnchored = {},
    origCanCollide = {},
    origState = nil,
}

local function saveState(char)
    if not char then return end
    NC.origAnchored = {}
    NC.origCanCollide = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            NC.origAnchored[part] = part.Anchored
            NC.origCanCollide[part] = part.CanCollide
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() NC.origState = hum:GetState() end)
    end
end

local function restoreState(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored = NC.origAnchored[part] or false
                local origCollide = NC.origCanCollide[part]
                part.CanCollide = origCollide == nil and true or origCollide
            end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if NC.origState then
                hum:ChangeState(NC.origState)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end
    NC.origAnchored = {}
    NC.origCanCollide = {}
    NC.origState = nil
end

local function applyNoclip()
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or not Camera then return end

    -- Отключаем Humanoid-контроллер
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)

    -- Анкорим все части + CanCollide = false
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

    -- Движение через CFrame (анкоренная модель не двигается физикой)
    local moveDir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

    if moveDir.Magnitude > 0 then
        local delta = moveDir.Unit * NoclipSettings.Speed * (1 / 60)
        pcall(function()
            hrp.CFrame = hrp.CFrame + delta
        end)
    end
end

function _G.startNoclip()
    if NC.conn then NC.conn:Disconnect() end
    local char = Player.Character
    saveState(char)
    applyNoclip()
    NC.conn = RunService.Heartbeat:Connect(function()
        if not NoclipSettings.Enabled then return end
        pcall(applyNoclip)
    end)
end

function _G.stopNoclip()
    if NC.conn then NC.conn:Disconnect(); NC.conn = nil end
    local char = Player.Character
    restoreState(char)
end

Player.CharacterAdded:Connect(function()
    if NoclipSettings.Enabled then
        task.wait(0.3)
        local char = Player.Character
        saveState(char)
        applyNoclip()
    end
end)

_G.createNoclipCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 100)
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
    title.Text = "Noclip"
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
    NC.toggle = toggle
    toggle.MouseButton1Click:Connect(function()
        NoclipSettings.Enabled = not NoclipSettings.Enabled
        toggle.Text = NoclipSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = NoclipSettings.Enabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 80)
        if NoclipSettings.Enabled then _G.startNoclip() else _G.stopNoclip() end
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
            NoclipSettings.BindKey = k
            bind.Text = k.Name
        end, function()
            NoclipSettings.BindKey = nil
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

    createSlider(content, "Speed", 20, 200, NoclipSettings.Speed, "", function(v) NoclipSettings.Speed = v end)
end

_G.NoclipSettings = NoclipSettings
_G.NoclipToggle = NC.toggle
