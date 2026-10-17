-- combat/antiaim.lua
-- MissWare AntiAim Module

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local Drawing = Drawing or nil

local MissWare = _G.MissWare or {}
local ACCENT_COLORS = MissWare.ACCENT_COLORS or {Default = Color3.new(1,1,1)}
local currentAccentColor = MissWare.currentAccentColor or "Default"
local createSlider = MissWare.createSlider
local createCheckbox = MissWare.createCheckbox
local captureKeybind = MissWare.captureKeybind

local AntiAimSettings = {
    Enabled = false,
    SpinBotEnabled = false,
    SpinSpeed = 50,
    HeadSettingsEnabled = false,
    HeadYaw = 0,
    HeadPitch = 0,
    JitterEnabled = false,
    JitterRange = 30,
    TurnLeftKey = nil,
    TurnRightKey = nil
}

local AA = {
    conn = nil,
    arrows = {},
    tick = 0,
}

local function createTurnArrows()
    if not Drawing or not Camera then return end
    for _, a in pairs(AA.arrows) do if a then a:Remove() end end
    AA.arrows = {}
    local vs = Camera.ViewportSize
    local cx, cy = vs.X / 2, vs.Y / 2
    local la = Drawing.new("Text")
    la.Text = "<"
    la.Size = 40
    la.Color = Color3.fromRGB(255, 255, 255)
    la.Position = Vector2.new(cx - 80, cy)
    la.Visible = false
    la.Center = true
    AA.arrows["left"] = la
    local ra = Drawing.new("Text")
    ra.Text = ">"
    ra.Size = 40
    ra.Color = Color3.fromRGB(255, 255, 255)
    ra.Position = Vector2.new(cx + 80, cy)
    ra.Visible = false
    ra.Center = true
    AA.arrows["right"] = ra
end

local function updateTurnArrows()
    if not Drawing or not Camera then return end
    local visible = AntiAimSettings.Enabled and AntiAimSettings.HeadSettingsEnabled
    if AA.arrows["left"] then AA.arrows["left"].Visible = visible end
    if AA.arrows["right"] then AA.arrows["right"].Visible = visible end
    if visible then
        local vs = Camera.ViewportSize
        local cx, cy = vs.X / 2, vs.Y / 2
        AA.arrows["left"].Position = Vector2.new(cx - 80, cy)
        AA.arrows["right"].Position = Vector2.new(cx + 80, cy)
    end
end

local function highlightArrow(d)
    if not Drawing or not AA.arrows[d] then return end
    local arrow = AA.arrows[d]
    arrow.Color = ACCENT_COLORS[currentAccentColor] or Color3.new(1,1,1)
    task.delay(0.3, function() if arrow then arrow.Color = Color3.fromRGB(255, 255, 255) end end)
end

local function applySpinBot(s)
    local c = Player.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); if not h then return end
    h.AutoRotate = false
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(s / 100 * 30), 0) end
end

local function applyHeadSettings()
    local c = Player.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); if not h then return end
    h.AutoRotate = false
    local neck = c:FindFirstChild("Neck")
    if neck and neck:IsA("Motor6D") then
        neck.C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(AntiAimSettings.HeadPitch), math.rad(AntiAimSettings.HeadYaw), 0)
        return
    end
    local torso = c:FindFirstChild("Torso")
    if torso then
        local r6neck = torso:FindFirstChild("Neck")
        if r6neck and r6neck:IsA("Motor6D") then
            r6neck.C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(AntiAimSettings.HeadPitch), math.rad(AntiAimSettings.HeadYaw), 0)
        end
    end
end

local function applyJitter()
    local c = Player.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); if not h then return end
    h.AutoRotate = false
    local range = AntiAimSettings.JitterRange
    local randomYaw = math.random(-range * 100, range * 100) / 100
    local neck = c:FindFirstChild("Neck")
    if neck and neck:IsA("Motor6D") then
        neck.C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(randomYaw), 0)
        return
    end
    local torso = c:FindFirstChild("Torso")
    if torso then
        local r6neck = torso:FindFirstChild("Neck")
        if r6neck and r6neck:IsA("Motor6D") then
            r6neck.C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(randomYaw), 0)
        end
    end
end

local function turnBody(d)
    local c = Player.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local pos = hrp.Position
    local angle = d == "left" and math.rad(90) or math.rad(-90)
    hrp.CFrame = CFrame.new(pos) * hrp.CFrame.Rotation * CFrame.Angles(0, angle, 0)
    highlightArrow(d)
end

local function resetCharacter()
    local c = Player.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); if h then h.AutoRotate = true end
    local neck = c:FindFirstChild("Neck")
    if neck and neck:IsA("Motor6D") then neck.C0 = CFrame.new(0, 1, 0) end
    local torso = c:FindFirstChild("Torso")
    if torso then
        local r6neck = torso:FindFirstChild("Neck")
        if r6neck and r6neck:IsA("Motor6D") then r6neck.C0 = CFrame.new(0, 1, 0) end
    end
end

function _G.stopAntiAim()
    if AA.conn then AA.conn:Disconnect(); AA.conn = nil end
    if AA.arrows["left"] then AA.arrows["left"].Visible = false end
    if AA.arrows["right"] then AA.arrows["right"].Visible = false end
    resetCharacter()
end

function _G.startAntiAim()
    if AA.conn then AA.conn:Disconnect() end
    updateTurnArrows()
    AA.tick = 0
    AA.conn = RunService.Heartbeat:Connect(function(dt)
        if not AntiAimSettings.Enabled then return end
        AA.tick = AA.tick + dt
        if AA.tick > 0.05 then
            AA.tick = 0
            updateTurnArrows()
            if AntiAimSettings.SpinBotEnabled then applySpinBot(AntiAimSettings.SpinSpeed) end
            if AntiAimSettings.HeadSettingsEnabled then applyHeadSettings() end
            if AntiAimSettings.JitterEnabled then applyJitter() end
        end
    end)
end

-- Бинды для поворота
UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not AntiAimSettings.Enabled then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if AntiAimSettings.TurnLeftKey and input.KeyCode == AntiAimSettings.TurnLeftKey then
        turnBody("left")
    elseif AntiAimSettings.TurnRightKey and input.KeyCode == AntiAimSettings.TurnRightKey then
        turnBody("right")
    end
end)

_G.createAntiAimCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 350)
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
    titleLabel.Text = "Anti-Aim"
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
    
    toggle.MouseButton1Click:Connect(function()
        AntiAimSettings.Enabled = not AntiAimSettings.Enabled
        toggle.Text = AntiAimSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = AntiAimSettings.Enabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 80)
        if AntiAimSettings.Enabled then _G.startAntiAim() else _G.stopAntiAim() end
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = card
    local contentList = Instance.new("UIListLayout")
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.Padding = UDim.new(0, 4)
    contentList.Parent = content

    createCheckbox(content, "SpinBot", AntiAimSettings.SpinBotEnabled, function(val) AntiAimSettings.SpinBotEnabled = val end)
    createSlider(content, "Spin Speed", 1, 100, AntiAimSettings.SpinSpeed, "", function(val) AntiAimSettings.SpinSpeed = val end)
    createCheckbox(content, "HeadSettings", AntiAimSettings.HeadSettingsEnabled, function(val) AntiAimSettings.HeadSettingsEnabled = val; updateTurnArrows() end)
    createSlider(content, "Head Yaw", -180, 180, AntiAimSettings.HeadYaw, "°", function(val) AntiAimSettings.HeadYaw = val end)
    createSlider(content, "Head Pitch", -90, 90, AntiAimSettings.HeadPitch, "°", function(val) AntiAimSettings.HeadPitch = val end)

    local r1 = Instance.new("Frame")
    r1.Size = UDim2.new(1, 0, 0, 26)
    r1.BackgroundTransparency = 1
    r1.Parent = content
    local l1 = Instance.new("TextLabel")
    l1.Size = UDim2.new(0, 110, 1, 0)
    l1.BackgroundTransparency = 1
    l1.Text = "Turn Left"
    l1.TextColor3 = Color3.fromRGB(180, 180, 190)
    l1.TextSize = 11
    l1.Font = Enum.Font.Gotham
    l1.Parent = r1
    local b1 = Instance.new("TextButton")
    b1.Size = UDim2.new(1, -120, 0, 20)
    b1.Position = UDim2.new(0, 115, 0, 3)
    b1.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    b1.BackgroundTransparency = 0
    b1.Text = AntiAimSettings.TurnLeftKey and AntiAimSettings.TurnLeftKey.Name or "Bind"
    b1.TextColor3 = Color3.fromRGB(200, 200, 200)
    b1.Font = Enum.Font.Gotham
    b1.TextSize = 10
    b1.AutoButtonColor = false
    b1.Parent = r1
    Instance.new("UICorner", b1).CornerRadius = UDim.new(0, 4)
    b1.MouseButton1Click:Connect(function()
        captureKeybind(function(k)
            AntiAimSettings.TurnLeftKey = k
            b1.Text = k.Name
        end, function()
            AntiAimSettings.TurnLeftKey = nil
            b1.Text = "Bind"
        end)
    end)

    local r2 = Instance.new("Frame")
    r2.Size = UDim2.new(1, 0, 0, 26)
    r2.BackgroundTransparency = 1
    r2.Parent = content
    local l2 = Instance.new("TextLabel")
    l2.Size = UDim2.new(0, 110, 1, 0)
    l2.BackgroundTransparency = 1
    l2.Text = "Turn Right"
    l2.TextColor3 = Color3.fromRGB(180, 180, 190)
    l2.TextSize = 11
    l2.Font = Enum.Font.Gotham
    l2.Parent = r2
    local b2 = Instance.new("TextButton")
    b2.Size = UDim2.new(1, -120, 0, 20)
    b2.Position = UDim2.new(0, 115, 0, 3)
    b2.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    b2.BackgroundTransparency = 0
    b2.Text = AntiAimSettings.TurnRightKey and AntiAimSettings.TurnRightKey.Name or "Bind"
    b2.TextColor3 = Color3.fromRGB(200, 200, 200)
    b2.Font = Enum.Font.Gotham
    b2.TextSize = 10
    b2.AutoButtonColor = false
    b2.Parent = r2
    Instance.new("UICorner", b2).CornerRadius = UDim.new(0, 4)
    b2.MouseButton1Click:Connect(function()
        captureKeybind(function(k)
            AntiAimSettings.TurnRightKey = k
            b2.Text = k.Name
        end, function()
            AntiAimSettings.TurnRightKey = nil
            b2.Text = "Bind"
        end)
    end)

    createCheckbox(content, "Jitter", AntiAimSettings.JitterEnabled, function(val) AntiAimSettings.JitterEnabled = val end)
    createSlider(content, "Jitter Range", 10, 180, AntiAimSettings.JitterRange, "°", function(val) AntiAimSettings.JitterRange = val end)
end

_G.AntiAimSettings = AntiAimSettings
_G.createTurnArrows = createTurnArrows
