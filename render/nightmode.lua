-- render/nightmode.lua
-- MissWare NightMode Module

local RunService = game:GetService("RunService")
local MissWare = _G.MissWare or {}
local createSlider = MissWare.createSlider or function() end
local createCheckbox = MissWare.createCheckbox or function() end
local createDropdown = MissWare.createDropdown or function() end

local NightModeSettings = {
    Enabled = false, Brightness = 0.5, Ambient = 0.3,
    TimeOfDay = "Night", CustomTime = 14, ColorFilter = "None",
    Bloom = false, BloomIntensity = 0.3,
}

local NM = {
    origBrightness = nil, origAmbient = nil, origTime = nil,
    cce = nil, bloom = nil, isDirty = false, heartbeatConn = nil,
    toggle = nil,
}

local function saveOriginalSettings()
    local lighting = game:GetService("Lighting")
    NM.origBrightness = lighting.Brightness
    NM.origAmbient = lighting.Ambient
    NM.origTime = lighting.ClockTime
end

local function applyNightMode()
    local lighting = game:GetService("Lighting")
    if not lighting then return end
    if not NightModeSettings.Enabled then
        lighting.Brightness = NM.origBrightness or 1
        lighting.Ambient = NM.origAmbient or Color3.fromRGB(0,0,0)
        lighting.ClockTime = NM.origTime or 14
        if NM.cce then NM.cce.Enabled = false end
        if NM.bloom then NM.bloom.Enabled = false end
        return
    end
    lighting.Brightness = NightModeSettings.Brightness * 2
    lighting.Ambient = Color3.new(NightModeSettings.Ambient, NightModeSettings.Ambient, NightModeSettings.Ambient)

    local timeMap = { Day = 14, Night = 0, Sunset = 18 }
    if NightModeSettings.TimeOfDay == "Custom" then lighting.ClockTime = NightModeSettings.CustomTime
    else lighting.ClockTime = timeMap[NightModeSettings.TimeOfDay] or 14 end

    if NightModeSettings.ColorFilter ~= "None" then
        if not NM.cce then NM.cce = Instance.new("ColorCorrectionEffect"); NM.cce.Parent = lighting end
        NM.cce.Enabled = true
        local filterMap = {
            Sepia = {Saturation = 0.3, Brightness = 0.1, Contrast = 0.1, TintColor = Color3.fromRGB(180,150,100)},
            Cold = {Saturation = 0.7, Brightness = -0.1, Contrast = 0.2, TintColor = Color3.fromRGB(100,150,255)},
            Warm = {Saturation = 0.8, Brightness = 0.1, Contrast = 0.1, TintColor = Color3.fromRGB(255,200,150)},
            Neon = {Saturation = 1.5, Brightness = 0.3, Contrast = 0.5, TintColor = Color3.fromRGB(255,100,255)},
        }
        local f = filterMap[NightModeSettings.ColorFilter]
        if f then
            NM.cce.Saturation = f.Saturation
            NM.cce.Brightness = f.Brightness
            NM.cce.Contrast = f.Contrast
            NM.cce.TintColor = f.TintColor
        end
    else
        if NM.cce then NM.cce.Enabled = false end
    end

    if NightModeSettings.Bloom then
        if not NM.bloom then
            NM.bloom = Instance.new("BloomEffect")
            NM.bloom.Size = 20
            NM.bloom.Threshold = 0.5
            NM.bloom.Parent = lighting
        end
        NM.bloom.Enabled = true
        NM.bloom.Intensity = NightModeSettings.BloomIntensity
    else
        if NM.bloom then NM.bloom.Enabled = false end
    end
end

local function markDirty() NM.isDirty = true end

function _G.startNightMode()
    saveOriginalSettings()
    NM.isDirty = true
    applyNightMode()
    NM.isDirty = false
    if NM.heartbeatConn then NM.heartbeatConn:Disconnect() end
    NM.heartbeatConn = RunService.Heartbeat:Connect(function()
        if NM.isDirty then
            NM.isDirty = false
            pcall(applyNightMode)
        end
    end)
end

function _G.stopNightMode()
    NightModeSettings.Enabled = false
    applyNightMode()
    if NM.heartbeatConn then NM.heartbeatConn:Disconnect(); NM.heartbeatConn = nil end
end

_G.createNightModeCard = function(parent)
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
    title.Text = "Night Mode"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -100, 0, 7)
    toggle.BackgroundColor3 = Color3.fromRGB(70,70,80)
    toggle.BackgroundTransparency = 0
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(255,255,255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.AutoButtonColor = false
    toggle.Parent = header
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    NM.toggle = toggle

    toggle.MouseButton1Click:Connect(function()
        NightModeSettings.Enabled = not NightModeSettings.Enabled
        toggle.Text = NightModeSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = NightModeSettings.Enabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(70,70,80)
        if NightModeSettings.Enabled then _G.startNightMode() else _G.stopNightMode() end
    end)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Color3.fromRGB(50,50,50)
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.Parent = card

    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 4)
    cl.Parent = content
    cl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, cl.AbsoluteContentSize.Y + 20)
    end)

    createSlider(content, "Brightness", 0.0, 1.0, NightModeSettings.Brightness, "", function(v) NightModeSettings.Brightness = v; markDirty() end)
    createSlider(content, "Ambient Light", 0.0, 1.0, NightModeSettings.Ambient, "", function(v) NightModeSettings.Ambient = v; markDirty() end)
    createDropdown(content, "Time Of Day", {"Day", "Night", "Sunset", "Custom"}, NightModeSettings.TimeOfDay, function(v) NightModeSettings.TimeOfDay = v; markDirty() end)
    createSlider(content, "Custom Hour", 0, 24, NightModeSettings.CustomTime, "h", function(v) NightModeSettings.CustomTime = v; if NightModeSettings.TimeOfDay == "Custom" then markDirty() end end)
    createDropdown(content, "Color Filter", {"None", "Sepia", "Cold", "Warm", "Neon"}, NightModeSettings.ColorFilter, function(v) NightModeSettings.ColorFilter = v; markDirty() end)
    createCheckbox(content, "Bloom", NightModeSettings.Bloom, function(v) NightModeSettings.Bloom = v; markDirty() end)
    createSlider(content, "Bloom Intensity", 0.1, 1.0, NightModeSettings.BloomIntensity, "", function(v) NightModeSettings.BloomIntensity = v; if NightModeSettings.Bloom then markDirty() end end)
end

_G.NightModeSettings = NightModeSettings
